import Foundation
import CloudKit
import CoreData
import Combine

/// A CloudKit service responsible for syncing Activity and ActivitySession records.
///
/// This implementation creates a dedicated private zone (`IntraHabitsZone`) and
/// performs delta syncs using change tokens. When no change token is
/// available, a full fetch is performed; otherwise only changed records are
/// fetched. The change token is persisted in `UserDefaults`.
final class CloudKitService: ObservableObject {
    // MARK: - Published Properties
    @Published var isSignedIn = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // MARK: - Private Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()

    // Record types
    private let activityRecordType = "Activity"
    private let sessionRecordType = "ActivitySession"

    // MARK: - Custom Zone & Token
    private let customZoneName = "IntraHabitsZone"
    private lazy var customZoneID = CKRecordZone.ID(zoneName: customZoneName, ownerName: CKCurrentUserDefaultName)

    /// The last server change token for our custom zone. Persisted across launches.
    private var serverChangeToken: CKServerChangeToken? {
        get {
            let key = "\(customZoneName)ChangeToken"
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            let key = "\(customZoneName)ChangeToken"
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Initialiser
    init(container: CKContainer = CKContainer(identifier: "iCloud.com.intrahabits.app")) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        setupNotifications()
        Task { await checkAccountStatus() }
        createCustomZoneIfNeeded()
    }

    // MARK: - Zone Creation
    /// Creates the custom zone if it does not exist. Errors are logged but not
    /// surfaced to the user; CloudKit automatically ignores duplicate zone
    /// creation attempts.
    private func createCustomZoneIfNeeded() {
        let zone = CKRecordZone(zoneID: customZoneID)
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: [])
        op.modifyRecordZonesCompletionBlock = { _, _, error in
            if let ckError = error as? CKError, ckError.code != .zoneAlreadyExists {
                AppLogger.error("Failed to create custom zone: \(ckError.localizedDescription)")
            }
        }
        privateDatabase.add(op)
    }

    // MARK: - Account Status
    @MainActor
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            isSignedIn = status == .available
        } catch {
            isSignedIn = false
        }
    }

    func isCloudKitAvailable() async -> Bool {
        await checkAccountStatus()
        return isSignedIn
    }

    // MARK: - Sync Entry Point
    /// Starts a sync. If a change token exists, delta sync is attempted; otherwise
    /// a full sync is performed.
    func startSync() {
        guard syncStatus != .syncing else { return }
        Task { await performSync() }
    }

    private func performSync() async {
        guard await isCloudKitAvailable() else {
            await MainActor.run {
                syncError = CloudKitError.accountNotAvailable
                syncStatus = .failed
            }
            return
        }

        await MainActor.run {
            syncStatus = .syncing
            syncError = nil
        }

        do {
            if serverChangeToken == nil {
                // No token → full fetch
                try await Task.detached(priority: .background) {
                    let context = PersistenceController.shared.container.newBackgroundContext()
                    try await self.uploadActivities(context: context)
                    try await self.uploadSessions(context: context)
                    try await self.downloadActivities()
                    try await self.downloadSessions()
                }.value
            } else {
                // Delta sync
                try await Task.detached(priority: .background) {
                    let context = PersistenceController.shared.container.newBackgroundContext()
                    try await self.uploadActivities(context: context)
                    try await self.uploadSessions(context: context)
                    try await self.fetchZoneChanges()
                }.value
            }
            let syncDate = Date()
            await MainActor.run {
                lastSyncDate = syncDate
                syncStatus = .completed
            }
            UserDefaults.standard.set(syncDate, forKey: "lastCloudKitSync")
        } catch let ckError as CKError {
            await MainActor.run {
                syncError = ckError
                syncStatus = .failed
                AppLogger.error("Sync failed with CKError: \(ckError.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                syncError = error
                syncStatus = .failed
                AppLogger.error("Sync failed with error: \(error)")
            }
        }
    }

    // MARK: - Delta Sync
    /// Fetches changes from the custom zone using `CKFetchRecordZoneChangesOperation`.
    /// Newly changed records are processed and deletions are handled. The new
    /// change token is persisted on success. If the token has expired, it is
    /// cleared and a full fetch should be performed by the caller.
    private func fetchZoneChanges() async throws {
        try await withCheckedThrowingContinuation { continuation in
            var updatedToken: CKServerChangeToken?
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: serverChangeToken)
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZoneID], configurationsByRecordZoneID: [customZoneID: config])
            // Called for each changed record
            operation.recordChangedBlock = { record in
                Task.detached {
                    do {
                        if record.recordType == self.activityRecordType {
                            try await self.processActivityRecord(record)
                        } else if record.recordType == self.sessionRecordType {
                            try await self.processSessionRecord(record)
                        }
                    } catch {
                        AppLogger.error("Error processing changed record: \(error)")
                    }
                }
            }
            // Called for deletions
            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                Task.detached {
                    do {
                        if recordType == self.activityRecordType {
                            try await self.handleDeletion(of: recordID, for: Activity.self)
                        } else if recordType == self.sessionRecordType {
                            try await self.handleDeletion(of: recordID, for: ActivitySession.self)
                        }
                    } catch {
                        AppLogger.error("Error processing deletion: \(error)")
                    }
                }
            }
            // Called when the fetch for a zone finishes
            operation.recordZoneFetchCompletionBlock = { _, token, _, error in
                if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                    // Token expired → discard and signal full fetch required
                    self.serverChangeToken = nil
                } else {
                    updatedToken = token
                }
            }
            // Called when the entire operation finishes
            operation.fetchRecordZoneChangesCompletionBlock = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    // Persist new token if we have one
                    self.serverChangeToken = updatedToken ?? self.serverChangeToken
                    continuation.resume()
                }
            }
            self.privateDatabase.add(operation)
        }
    }

    // MARK: - Upload & Download Operations
    private func uploadActivities(context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "needsCloudKitUpload == %@", NSNumber(value: true))
        let activities = try context.fetch(request)
        for activity in activities {
            let record = try createActivityRecord(from: activity)
            let savedRecord = try await saveRecordWithRetry(record)
            await context.perform {
                activity.cloudKitRecordID = savedRecord.recordID.recordName
                activity.needsCloudKitUpload = false
                activity.lastModifiedAt = Date()
                try? context.save()
            }
        }
    }

    private func uploadSessions(context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "needsCloudKitUpload == %@", NSNumber(value: true))
        let sessions = try context.fetch(request)
        for session in sessions {
            let record = try createSessionRecord(from: session)
            let savedRecord = try await saveRecordWithRetry(record)
            await context.perform {
                session.cloudKitRecordID = savedRecord.recordID.recordName
                session.needsCloudKitUpload = false
                session.lastModifiedAt = Date()
                try? context.save()
            }
        }
    }

    /// Full download of activities in the custom zone.
    private func downloadActivities() async throws {
        let query = CKQuery(recordType: activityRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWithID: customZoneID)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processActivityRecord(record)
            case .failure(let error):
                AppLogger.error("Error downloading activity record: \(error)")
            }
        }
    }

    /// Full download of sessions in the custom zone.
    private func downloadSessions() async throws {
        let query = CKQuery(recordType: sessionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWithID: customZoneID)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processSessionRecord(record)
            case .failure(let error):
                AppLogger.error("Error downloading session record: \(error)")
            }
        }
    }

    // MARK: - Record Creation & Processing
    private func createActivityRecord(from activity: Activity) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: activity.cloudKitRecordID ?? UUID().uuidString, zoneID: customZoneID)
        let record = CKRecord(recordType: activityRecordType, recordID: recordID)
        record["id"] = activity.id?.uuidString
        record["name"] = activity.name
        record["type"] = activity.type
        record["color"] = activity.color
        record["isActive"] = activity.isActive
        record["createdAt"] = activity.createdAt
        record["lastModifiedAt"] = Date()
        return record
    }

    private func createSessionRecord(from session: ActivitySession) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.cloudKitRecordID ?? UUID().uuidString, zoneID: customZoneID)
        let record = CKRecord(recordType: sessionRecordType, recordID: recordID)
        record["id"] = session.id?.uuidString
        record["sessionDate"] = session.sessionDate
        record["duration"] = session.duration ?? 0
        record["numericValue"] = session.numericValue ?? 0
        record["isCompleted"] = session.isCompleted
        record["createdAt"] = session.createdAt
        record["lastModifiedAt"] = Date()
        if let activityRecordID = session.activity?.cloudKitRecordID {
            let activityReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: activityRecordID, zoneID: customZoneID), action: .deleteSelf)
            record["activity"] = activityReference
        }
        return record
    }

    private func processActivityRecord(_ record: CKRecord) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            do {
                guard let idString = record["id"] as? String, let activityID = UUID(uuidString: idString) else { return }
                let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", activityID as CVarArg)
                let existing = try context.fetch(request).first ?? Activity(context: context)
                existing.id = activityID
                existing.name = record["name"] as? String
                existing.type = record["type"] as? String
                existing.color = record["color"] as? String
                existing.isActive = record["isActive"] as? Bool ?? false
                existing.createdAt = record["createdAt"] as? Date
                existing.lastModifiedAt = record["lastModifiedAt"] as? Date
                existing.cloudKitRecordID = record.recordID.recordName
                existing.needsCloudKitUpload = false
                try context.save()
            } catch {
                AppLogger.error("Error processing activity record: \(error)")
            }
        }
    }

    private func processSessionRecord(_ record: CKRecord) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            do {
                guard let idString = record["id"] as? String, let sessionID = UUID(uuidString: idString) else { return }
                let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sessionID as CVarArg)
                let existing = try context.fetch(request).first ?? ActivitySession(context: context)
                existing.id = sessionID
                existing.sessionDate = record["sessionDate"] as? Date
                existing.duration = record["duration"] as? Double
                existing.numericValue = record["numericValue"] as? Double
                existing.isCompleted = record["isCompleted"] as? Bool ?? false
                existing.createdAt = record["createdAt"] as? Date
                existing.lastModifiedAt = record["lastModifiedAt"] as? Date
                existing.cloudKitRecordID = record.recordID.recordName
                existing.needsCloudKitUpload = false
                // Link to activity
                if let activityReference = record["activity"] as? CKRecord.Reference {
                    let activityID = activityReference.recordID.recordName
                    let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    activityRequest.predicate = NSPredicate(format: "cloudKitRecordID == %@", activityID)
                    if let activity = try context.fetch(activityRequest).first {
                        existing.activity = activity
                    }
                }
                try context.save()
            } catch {
                AppLogger.error("Error processing session record: \(error)")
            }
        }
    }

    // MARK: - Deletion Handling
    /// Handles deletions from CloudKit by marking the corresponding Core Data object as deleted.
    private func handleDeletion<T: NSManagedObject>(of recordID: CKRecord.ID, for type: T.Type) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            do {
                if type == Activity.self {
                    let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                    request.predicate = NSPredicate(format: "cloudKitRecordID == %@", recordID.recordName)
                    if let object = try context.fetch(request).first {
                        context.delete(object)
                    }
                } else if type == ActivitySession.self {
                    let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                    request.predicate = NSPredicate(format: "cloudKitRecordID == %@", recordID.recordName)
                    if let object = try context.fetch(request).first {
                        context.delete(object)
                    }
                }
                try context.save()
            } catch {
                AppLogger.error("Error handling deletion: \(error)")
            }
        }
    }

    // MARK: - Save with Retry
    private func saveRecordWithRetry(_ record: CKRecord, maxRetries: Int = 3) async throws -> CKRecord {
        var attempt = 0
        var delay: TimeInterval = 1.0
        while attempt < maxRetries {
            do {
                let saved = try await privateDatabase.save(record)
                return saved
            } catch let error as CKError {
                if error.code == .networkUnavailable || error.code == .serviceUnavailable || error.code == .zoneBusy {
                    attempt += 1
                    if attempt >= maxRetries { throw error }
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                } else {
                    throw error
                }
            }
        }
        return record
    }

    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { await self?.handleAccountChange() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.handleCoreDataChange(notification)
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func handleAccountChange() async {
        let available = await isCloudKitAvailable()
        if available {
            startSync()
        } else {
            syncStatus = .failed
            syncError = CloudKitError.accountNotAvailable
        }
    }

    private func handleCoreDataChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            markObjectsForUpload(inserted)
        }
        if let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            markObjectsForUpload(updated)
        }
    }

    private func markObjectsForUpload(_ objects: Set<NSManagedObject>) {
        for object in objects {
            if let activity = object as? Activity {
                activity.needsCloudKitUpload = true
                activity.lastModifiedAt = Date()
            } else if let session = object as? ActivitySession {
                session.needsCloudKitUpload = true
                session.lastModifiedAt = Date()
            }
        }
    }
}

// MARK: - Sync Status
/// Represents the state of a sync operation. Presentation concerns (e.g., mapping
/// to user-facing strings) are handled in the ViewModel or View.
enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case networkUnavailable
    case quotaExceeded
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return NSLocalizedString("cloudkit.error.account_not_available", comment: "")
        case .networkUnavailable:
            return NSLocalizedString("cloudkit.error.network_unavailable", comment: "")
        case .quotaExceeded:
            return NSLocalizedString("cloudkit.error.quota_exceeded", comment: "")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}