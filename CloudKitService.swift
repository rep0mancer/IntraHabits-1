import Foundation
import CloudKit
import CoreData
import Combine

class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    
    // CloudKit Record Types
    private let activityRecordType = "Activity"
    private let sessionRecordType = "ActivitySession"
    
    // Sync configuration
    private let syncInterval: TimeInterval = 30 // 30 seconds
    private var syncTimer: Timer?
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.intrahabits.app")
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        setupNotifications()
        startPeriodicSync()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    func startSync() {
        guard syncStatus != .syncing else { return }
        
        Task {
            await performFullSync()
        }
    }
    
    func enableAutomaticSync() {
        startPeriodicSync()
    }
    
    func disableAutomaticSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            AppLogger.error("Error checking CloudKit account status: \(error)")
            return .couldNotDetermine
        }
    }
    
    func isCloudKitAvailable() async -> Bool {
        let status = await checkAccountStatus()
        return status == .available
    }
    
    // MARK: - Sync Operations
    
    @MainActor
    private func performFullSync() async {
        guard await isCloudKitAvailable() else {
            syncError = CloudKitError.accountNotAvailable
            return
        }
        
        syncStatus = .syncing
        syncError = nil
        
        do {
            // Upload local changes first
            try await uploadLocalChanges()
            
            // Then download remote changes
            try await downloadRemoteChanges()
            
            lastSyncDate = Date()
            syncStatus = .completed
            
            // Save sync timestamp
            UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudKitSync")
            
        } catch {
            syncError = error
            syncStatus = .failed
            AppLogger.error("Sync failed: \(error)")
        }
    }
    
    private func uploadLocalChanges() async throws {
        let context = PersistenceController.shared.container.viewContext
        
        // Upload activities
        try await uploadActivities(context: context)
        
        // Upload sessions
        try await uploadSessions(context: context)
    }
    
    private func uploadActivities(context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "needsCloudKitUpload == %@", NSNumber(value: true))
        
        let activities = try context.fetch(request)
        
        for activity in activities {
            let record = try createActivityRecord(from: activity)
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                
                // Update local record with CloudKit metadata
                await context.perform {
                    activity.cloudKitRecordID = savedRecord.recordID.recordName
                    activity.needsCloudKitUpload = false
                    activity.lastModifiedAt = Date()
                    
                    try? context.save()
                }
                
            } catch let error as CKError {
                if error.code == .serverRecordChanged {
                    // Handle conflict
                    try await handleActivityConflict(activity: activity, error: error)
                } else {
                    throw error
                }
            }
        }
    }
    
    private func uploadSessions(context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "needsCloudKitUpload == %@", NSNumber(value: true))
        
        let sessions = try context.fetch(request)
        
        for session in sessions {
            let record = try createSessionRecord(from: session)
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                
                // Update local record with CloudKit metadata
                await context.perform {
                    session.cloudKitRecordID = savedRecord.recordID.recordName
                    session.needsCloudKitUpload = false
                    session.lastModifiedAt = Date()
                    
                    try? context.save()
                }
                
            } catch let error as CKError {
                if error.code == .serverRecordChanged {
                    // Handle conflict
                    try await handleSessionConflict(session: session, error: error)
                } else {
                    throw error
                }
            }
        }
    }
    
    private func downloadRemoteChanges() async throws {
        // Download activities
        try await downloadActivities()
        
        // Download sessions
        try await downloadSessions()
    }
    
    private func downloadActivities() async throws {
        let query = CKQuery(recordType: activityRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processActivityRecord(record)
            case .failure(let error):
                AppLogger.error("Error downloading activity record: \(error)")
            }
        }
    }
    
    private func downloadSessions() async throws {
        let query = CKQuery(recordType: sessionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processSessionRecord(record)
            case .failure(let error):
                AppLogger.error("Error downloading session record: \(error)")
            }
        }
    }
    
    // MARK: - Record Creation
    
    private func createActivityRecord(from activity: Activity) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: activity.cloudKitRecordID ?? UUID().uuidString)
        let record = CKRecord(recordType: activityRecordType, recordID: recordID)
        
        record["id"] = activity.id?.uuidString
        record["name"] = activity.name
        record["type"] = activity.type
        record["color"] = activity.color
        record["isActive"] = activity.isActive ? 1 : 0
        record["createdAt"] = activity.createdAt
        record["lastModifiedAt"] = Date()
        
        return record
    }
    
    private func createSessionRecord(from session: ActivitySession) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.cloudKitRecordID ?? UUID().uuidString)
        let record = CKRecord(recordType: sessionRecordType, recordID: recordID)
        
        record["id"] = session.id?.uuidString
        record["sessionDate"] = session.sessionDate
        record["duration"] = session.duration ?? 0
        record["numericValue"] = session.numericValue ?? 0
        record["isCompleted"] = session.isCompleted ? 1 : 0
        record["createdAt"] = session.createdAt
        record["lastModifiedAt"] = Date()
        
        // Reference to activity
        if let activityRecordID = session.activity?.cloudKitRecordID {
            let activityReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: activityRecordID),
                action: .deleteSelf
            )
            record["activity"] = activityReference
        }
        
        return record
    }
    
    // MARK: - Record Processing
    
    private func processActivityRecord(_ record: CKRecord) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        await context.perform {
            do {
                guard let idString = record["id"] as? String,
                      let activityID = UUID(uuidString: idString) else {
                    AppLogger.error("Invalid activity record ID: \(record.recordID.recordName)")
                    return
                }

                // Check if activity already exists
                let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", activityID as CVarArg)
                
                let existingActivities = try context.fetch(request)
                let activity = existingActivities.first ?? Activity(context: context)
                
                // Update activity with record data
                activity.id = activityID
                activity.name = record["name"] as? String
                activity.type = record["type"] as? String
                activity.color = record["color"] as? String
                activity.isActive = (record["isActive"] as? Int) == 1
                activity.createdAt = record["createdAt"] as? Date
                activity.lastModifiedAt = record["lastModifiedAt"] as? Date
                activity.cloudKitRecordID = record.recordID.recordName
                activity.needsCloudKitUpload = false
                
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
                guard let idString = record["id"] as? String,
                      let sessionID = UUID(uuidString: idString) else {
                    AppLogger.error("Invalid session record ID: \(record.recordID.recordName)")
                    return
                }

                // Check if session already exists
                let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sessionID as CVarArg)
                
                let existingSessions = try context.fetch(request)
                let session = existingSessions.first ?? ActivitySession(context: context)
                
                // Update session with record data
                session.id = sessionID
                session.sessionDate = record["sessionDate"] as? Date
                session.duration = record["duration"] as? Double
                session.numericValue = record["numericValue"] as? Double
                session.isCompleted = (record["isCompleted"] as? Int) == 1
                session.createdAt = record["createdAt"] as? Date
                session.lastModifiedAt = record["lastModifiedAt"] as? Date
                session.cloudKitRecordID = record.recordID.recordName
                session.needsCloudKitUpload = false
                
                // Link to activity if reference exists
                if let activityReference = record["activity"] as? CKRecord.Reference {
                    let activityRecordID = activityReference.recordID.recordName
                    
                    let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    activityRequest.predicate = NSPredicate(format: "cloudKitRecordID == %@", activityRecordID)
                    
                    if let activity = try context.fetch(activityRequest).first {
                        session.activity = activity
                    }
                }
                
                try context.save()
                
            } catch {
                AppLogger.error("Error processing session record: \(error)")
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func handleActivityConflict(activity: Activity, error: CKError) async throws {
        guard let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            throw error
        }
        
        // Simple conflict resolution: server wins
        // In a production app, you might want more sophisticated conflict resolution
        try await processActivityRecord(serverRecord)
    }
    
    private func handleSessionConflict(session: ActivitySession, error: CKError) async throws {
        guard let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            throw error
        }
        
        // Simple conflict resolution: server wins
        try await processSessionRecord(serverRecord)
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        // Listen for remote notifications
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAccountChange()
                }
            }
            .store(in: &cancellables)
        
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.handleCoreDataChange(notification)
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func handleAccountChange() async {
        let isAvailable = await isCloudKitAvailable()
        if isAvailable {
            startSync()
        } else {
            syncStatus = .failed
            syncError = CloudKitError.accountNotAvailable
        }
    }
    
    private func handleCoreDataChange(_ notification: Notification) {
        // Mark objects as needing upload when they change locally
        guard let userInfo = notification.userInfo else { return }
        
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            markObjectsForUpload(insertedObjects)
        }
        
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            markObjectsForUpload(updatedObjects)
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
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        syncTimer?.invalidate()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performFullSync()
            }
        }
    }
}

// MARK: - Sync Status
enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed
    
    var displayText: String {
        switch self {
        case .idle:
            return NSLocalizedString("sync.status.idle", comment: "")
        case .syncing:
            return NSLocalizedString("sync.status.syncing", comment: "")
        case .completed:
            return NSLocalizedString("sync.status.completed", comment: "")
        case .failed:
            return NSLocalizedString("sync.status.failed", comment: "")
        }
    }
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

