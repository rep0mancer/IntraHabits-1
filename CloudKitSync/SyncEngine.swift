import Foundation
import CloudKit
import CoreData

/// An actor‑based sync engine that uploads local changes and pulls remote changes
/// from CloudKit.  This implementation performs delta synchronisation by
/// maintaining database and zone change tokens and persisting them across
/// launches.  It is designed to be thread safe and safe to call from
/// concurrent contexts.
public actor SyncEngine {

    // MARK: - Zone and Database Configuration
    /// The identifier for the private record zone used by the application.
    private let customZoneID = CKRecordZone.ID(zoneName: "IntraHabitsZone",
                                               ownerName: CKCurrentUserDefaultName)

    /// The CloudKit container used for synchronisation.  Defaults to the
    /// application's default container.
    private let container: CKContainer

    /// A reference to the private CloudKit database.  All records for
    /// ``Activity`` and ``ActivitySession`` live in this database.
    private let privateDatabase: CKDatabase

    /// A handle to the user defaults used to persist change tokens.  This
    /// dependency is injected to allow for testing.
    private let defaults: UserDefaults

    /// The key used to store the database change token in ``defaults``.
    private let databaseChangeTokenKey = "SyncEngine.privateDatabaseChangeToken"

    /// The key used to store the zone change token in ``defaults``.
    private let zoneChangeTokenKey = "SyncEngine.zoneChangeToken"

    /// Last successful sync date to support simple delta detection for Core Data objects.
    private let lastSuccessfulSyncDateKey = "SyncEngine.lastSuccessfulSyncDate"

    /// The most recently received database change token.  When ``pullRemoteChanges()``
    /// runs it passes this token to CloudKit to request only changes since the
    /// last successful sync.  After a sync completes the new token is persisted
    /// via ``persistDatabaseChangeToken(_:)``.
    private var privateDatabaseChangeToken: CKServerChangeToken?

    /// The most recently received zone change token.  Each call to
    /// ``pullRemoteChanges()`` passes this token to ``recordZoneChanges(inZoneWith:since:)``.
    private var zoneChangeToken: CKServerChangeToken?

    /// Represents the overall state of a sync operation.  UI code should
    /// observe this value to update its presentation.  It starts as `.idle` and
    /// transitions through `.running`, `.completed` or `.failed` as
    /// appropriate.
    /// Represents the public state of a synchronisation.  Unlike the
    /// previous ``SyncStatus`` enum, this type can report progress via a
    /// Double parameter on the ``running`` case and can surface the
    /// underlying ``Error`` if a sync fails.
    public enum Status: Equatable {
        case idle
        case running(Double)
        case completed
        case failed(Error)
    }

    /// A published stream of status updates.  The ``@Published`` property
    /// wrapper exposes a Combine publisher that can be bridged to the
    /// main actor via the ``SyncController``.  The actor maintains
    /// exclusivity by marking this property ``private(set)``.
    @Published private(set) var status: Status = .idle

    // Preserve the legacy ``SyncStatus`` for backward compatibility.  This
    // internal enum is now deprecated and should not be observed by UI code.
    @available(*, deprecated, message: "Use status instead")
    public enum SyncStatus {
        case idle
        case running
        case completed
        case failed
    }

    /// The current sync status.  Marked ``private(set)`` so only the actor
    /// itself may mutate the value.
    // Retain the legacy ``syncStatus`` property to support older call sites.
    // Internally this value is kept in sync with ``status`` but offers no
    // progress information.  UI code should observe ``status`` instead.
    private(set) public var syncStatus: SyncStatus = .idle

    // MARK: - Constants
    private let recordTypeActivity = "Activity"
    private let recordTypeSession = "ActivitySession"

    // MARK: - Core Data
    /// Use the app's persistent container. We prefer a background context for sync work.
    private var persistentContainer: NSPersistentCloudKitContainer {
        PersistenceController.shared.container
    }

    private func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    // MARK: - Initialisation
    /// Creates a new instance of the sync engine.  Injecting the container and
    /// user defaults allows for unit testing and production usage without
    /// global state.  The constructor loads any previously persisted change
    /// tokens from the provided ``defaults``.
    public init(container: CKContainer = .default(), defaults: UserDefaults = .standard) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.defaults = defaults

        // Load the persisted database change token if available.
        if let tokenData = defaults.data(forKey: databaseChangeTokenKey) {
            self.privateDatabaseChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self,
                                                                                      from: tokenData)
        }

        // Load the persisted zone change token if available.
        if let tokenData = defaults.data(forKey: zoneChangeTokenKey) {
            self.zoneChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self,
                                                                           from: tokenData)
        }
    }

    // MARK: - Account Status
    /// Returns the user's iCloud account status.  If an error occurs during
    /// retrieval the method returns ``CKAccountStatus.couldNotDetermine``.  This
    /// helper mirrors the convenience method exposed on the old
    /// ``LegacyCloudKitService``.
    public func checkAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            return status
        } catch {
            return .couldNotDetermine
        }
    }

    // MARK: - Zone Management
    private func ensureCustomZoneExists() async throws {
        // Try to fetch the zone by ID. If it errors, attempt to create it.
        do {
            _ = try await privateDatabase.recordZone(withID: customZoneID)
        } catch {
            let zone = CKRecordZone(zoneID: customZoneID)
            _ = try await privateDatabase.modifyRecordZones(recordZonesToSave: [zone], recordZoneIDsToDelete: [])
        }
    }

    // MARK: - Remote Sync
    /// Pulls down all remote changes since the last successful sync.  This
    /// implementation first requests database level changes to determine which
    /// zones have been modified, then fetches record level changes from the
    /// affected zones.  On completion it persists any updated change tokens.
    public func pullRemoteChanges() async throws {
        try await ensureCustomZoneExists()

        // Fetch database changes using the last known database change token.
        let dbChanges = try await privateDatabase.databaseChanges(since: privateDatabaseChangeToken)

        for zoneID in dbChanges.changedRecordZoneIDs where zoneID == customZoneID {
            // Fetch record level changes for each zone since our stored zone token.
            let zoneChanges = try await privateDatabase.recordZoneChanges(inZoneWith: zoneID,
                                                                          since: zoneChangeToken)
            // Extract changed records into an array.  Each result is a Result<CKRecord, Error>.
            let changedRecords = zoneChanges.recordChanges.compactMap { try? $0.get() }

            // Map CKRecords into Core Data
            try await processChangedRecords(changedRecords)

            // Process deletions
            try await processDeletions(zoneChanges.recordDeletions.map { $0.recordID })

            // Persist the new zone token if one was provided by CloudKit.
            if let newZoneToken = zoneChanges.changeToken {
                try await self.persistZoneChangeToken(newZoneToken)
            }
        }

        // Persist the new database change token if one was provided.
        if let newDBToken = dbChanges.changeToken {
            try await self.persistDatabaseChangeToken(newDBToken)
        }
    }

    // MARK: - Local Sync
    /// Uploads any local changes to CloudKit.
    public func uploadLocalChanges() async throws {
        try await ensureCustomZoneExists()

        let context = newBackgroundContext()

        // Determine last successful sync date for delta uploads.
        let lastSync: Date? = defaults.object(forKey: lastSuccessfulSyncDateKey) as? Date

        // Upload Activities
        let activitiesRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
        activitiesRequest.predicate = predicateForUnsynced(entityName: "Activity", lastSync: lastSync)
        let activities = try context.performAndWait { () -> [Activity] in
            try context.fetch(activitiesRequest)
        }
        if !activities.isEmpty {
            try await uploadActivities(activities)
        }

        // Upload ActivitySessions
        let sessionsRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        sessionsRequest.predicate = predicateForUnsynced(entityName: "ActivitySession", lastSync: lastSync)
        let sessions = try context.performAndWait { () -> [ActivitySession] in
            try context.fetch(sessionsRequest)
        }
        if !sessions.isEmpty {
            try await uploadSessions(sessions)
        }

        // Update last sync date
        defaults.set(Date(), forKey: lastSuccessfulSyncDateKey)
    }

    /// Pushes any unsynchronised local changes to CloudKit.  This method
    /// provides a semantic wrapper around ``uploadLocalChanges()`` and
    /// exists to align with the naming in the new ``sync()`` workflow.
    private func pushLocalChanges() async throws {
        try await uploadLocalChanges()
    }

    // MARK: - Mapping and Processing
    private func processChangedRecords(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }
        let context = newBackgroundContext()
        try await context.perform {
            for record in records {
                switch record.recordType {
                case self.recordTypeActivity:
                    try? self.processActivityRecord(record, in: context)
                case self.recordTypeSession:
                    try? self.processSessionRecord(record, in: context)
                default:
                    break
                }
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func processDeletions(_ recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        let context = newBackgroundContext()
        try await context.perform {
            for rid in recordIDs {
                switch rid.recordNamePrefix {
                case self.recordTypeActivity:
                    if let uuid = rid.parseUUID() {
                        let fetch = Activity.activityByIdFetchRequest(uuid)
                        if let obj = try? context.fetch(fetch).first {
                            context.delete(obj)
                        }
                    }
                case self.recordTypeSession:
                    if let uuid = rid.parseUUID() {
                        let req: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                        req.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                        if let obj = try? context.fetch(req).first {
                            context.delete(obj)
                        }
                    }
                default:
                    break
                }
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    /// Uploads all modified Activity records to CloudKit.
    private func uploadActivities(_ activities: [Activity]) async throws {
        for activity in activities {
            guard let id = activity.id else { continue }
            let recordID = CKRecord.ID(recordName: "\(recordTypeActivity)-\(id.uuidString)", zoneID: customZoneID)
            let record = CKRecord(recordType: recordTypeActivity, recordID: recordID)
            record["id"] = id.uuidString as CKRecordValue
            record["name"] = (activity.name ?? "") as CKRecordValue
            record["type"] = (activity.type ?? ActivityType.numeric.rawValue) as CKRecordValue
            record["color"] = (activity.color ?? "#CD3A2E") as CKRecordValue
            record["createdAt"] = (activity.createdAt ?? Date()) as CKRecordValue
            record["updatedAt"] = (activity.updatedAt ?? activity.createdAt ?? Date()) as CKRecordValue
            record["isActive"] = activity.isActive as CKRecordValue
            record["sortOrder"] = NSNumber(value: activity.sortOrder)
            _ = try await privateDatabase.save(record)
        }
    }

    /// Uploads all modified ActivitySession records to CloudKit.
    private func uploadSessions(_ sessions: [ActivitySession]) async throws {
        for session in sessions {
            guard let id = session.id else { continue }
            let recordID = CKRecord.ID(recordName: "\(recordTypeSession)-\(id.uuidString)", zoneID: customZoneID)
            let record = CKRecord(recordType: recordTypeSession, recordID: recordID)
            record["id"] = id.uuidString as CKRecordValue
            record["sessionDate"] = (session.sessionDate ?? Date()) as CKRecordValue
            record["duration"] = session.duration as CKRecordValue
            record["numericValue"] = session.numericValue as CKRecordValue
            record["isCompleted"] = session.isCompleted as CKRecordValue
            record["createdAt"] = (session.createdAt ?? Date()) as CKRecordValue
            record["updatedAt"] = (session.updatedAt ?? session.createdAt ?? Date()) as CKRecordValue
            // Reference to parent activity
            if let activityId = session.activity?.id {
                let parentID = CKRecord.ID(recordName: "\(recordTypeActivity)-\(activityId.uuidString)", zoneID: customZoneID)
                record["activityRef"] = CKRecord.Reference(recordID: parentID, action: .none)
                record["activityId"] = activityId.uuidString as CKRecordValue
            }
            _ = try await privateDatabase.save(record)
        }
    }

    /// Downloads updated Activity records from CloudKit based on the delta
    /// information returned by the ``recordZoneChanges(inZoneWith:since:)`` API.
    /// Implementations should map CKRecords into Core Data managed objects.
    private func downloadActivities() async throws {
        // No-op: handled via processChangedRecords()
    }

    /// Downloads updated ActivitySession records from CloudKit.  Like
    /// ``downloadActivities()``, this helper handles translating CKRecords
    /// into managed objects and applying deletions.
    private func downloadSessions() async throws {
        // No-op: handled via processChangedRecords()
    }

    /// Updates the published status to reflect a running sync with the given
    /// progress value.  This helper also updates the deprecated ``syncStatus``
    /// enum for backwards compatibility.  It must be called on the actor.
    private func updateProgress(_ progress: Double) {
        status = .running(progress)
        syncStatus = .running
    }

    // MARK: - Legacy CloudKitService Helper Signatures
    /// Uploads the provided activities to CloudKit.  This method signature
    /// mirrors the one found in the deprecated ``LegacyCloudKitService``.  A
    /// concrete implementation will iterate over the array, convert each
    /// ``Activity`` into a ``CKRecord``, and persist it via a modify
    /// operation.
    private func uploadActivities(_ activities: [Activity]) async throws {
        // Implemented above
        try await self.uploadActivities(activities)
    }

    /// Uploads the provided activity sessions to CloudKit.  See
    /// ``uploadActivities(_:)`` for details.
    private func uploadSessions(_ sessions: [ActivitySession]) async throws {
        // Implemented above
        try await self.uploadSessions(sessions)
    }

    /// Processes a fetched ``CKRecord`` representing an Activity.  A concrete
    /// implementation will map record fields onto an existing or new
    /// ``Activity`` managed object.
    private func processActivityRecord(_ record: CKRecord, in context: NSManagedObjectContext) throws {
        guard let idString = record["id"] as? String, let uuid = UUID(uuidString: idString) else { return }
        let fetch = Activity.activityByIdFetchRequest(uuid)
        let activity = try context.fetch(fetch).first ?? Activity(context: context)
        activity.id = uuid
        activity.name = record["name"] as? String
        activity.type = record["type"] as? String
        activity.color = record["color"] as? String
        activity.createdAt = record["createdAt"] as? Date
        activity.updatedAt = record["updatedAt"] as? Date
        activity.isActive = (record["isActive"] as? NSNumber)?.boolValue ?? true
        if let sort = record["sortOrder"] as? NSNumber { activity.sortOrder = sort.int32Value }
    }

    /// Processes a fetched ``CKRecord`` representing an ActivitySession.
    private func processSessionRecord(_ record: CKRecord, in context: NSManagedObjectContext) throws {
        guard let idString = record["id"] as? String, let uuid = UUID(uuidString: idString) else { return }
        let req: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        let session = try context.fetch(req).first ?? ActivitySession(context: context)
        session.id = uuid
        session.sessionDate = record["sessionDate"] as? Date
        session.duration = (record["duration"] as? NSNumber)?.doubleValue ?? 0
        session.numericValue = (record["numericValue"] as? NSNumber)?.doubleValue ?? 0
        session.isCompleted = (record["isCompleted"] as? NSNumber)?.boolValue ?? false
        session.createdAt = record["createdAt"] as? Date
        session.updatedAt = record["updatedAt"] as? Date

        // Link to activity by reference or activityId string
        if let activityIdString = record["activityId"] as? String, let activityId = UUID(uuidString: activityIdString) {
            let activityFetch = Activity.activityByIdFetchRequest(activityId)
            if let activity = try context.fetch(activityFetch).first {
                session.activity = activity
            }
        } else if let ref = record["activityRef"] as? CKRecord.Reference {
            if let activityUUID = ref.recordID.parseUUID() {
                let activityFetch = Activity.activityByIdFetchRequest(activityUUID)
                if let activity = try context.fetch(activityFetch).first {
                    session.activity = activity
                }
            }
        }
    }

    /// Constructs a predicate that matches unsynchronised objects.  The
    /// signature mirrors the deprecated service's helper.  Clients should
    /// supply the entity name and any additional filtering criteria.
    private func predicateForUnsynced(entityName: String, lastSync: Date?) -> NSPredicate {
        if let lastSync {
            return NSPredicate(format: "updatedAt == nil OR updatedAt > %@", lastSync as NSDate)
        } else {
            return NSPredicate(value: true)
        }
    }

    // MARK: - Public Sync Entry Point
    /// Initiates a synchronisation cycle using the new ``Status`` API.  This
    /// method updates ``status`` throughout the sync to report progress.  On
    /// completion ``status`` will be `.completed` or `.failed(Error)`.
    public func sync() async {
        // If a sync is already running we ignore subsequent requests.
        if case .running = status {
            return
        }
        // Report that the sync has started.
        status = .running(0.0)
        syncStatus = .running
        do {
            // Perform local push and remote pull concurrently using a throwing task group.
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Task for uploading local changes.
                group.addTask { [self] in
                    try await pushLocalChanges()
                }
                // Task for downloading remote changes.
                group.addTask { [self] in
                    try await pullRemoteChanges()
                }

                var completedTasks = 0
                for try await _ in group {
                    completedTasks += 1
                    await updateProgress(Double(completedTasks) / 2.0)
                }
            }
            // Sync succeeded.
            status = .completed
            syncStatus = .completed
        } catch {
            // Sync failed; report error.
            status = .failed(error)
            syncStatus = .failed
        }
    }

    /// DEPRECATED: Use ``sync()`` instead.  This method maintains backward
    /// compatibility with call sites expecting the old behaviour.  It
    /// delegates to ``sync()`` and then maps ``status`` into ``syncStatus``.
    @available(*, deprecated, message: "Use sync() instead")
    public func startSync() async {
        await sync()
    }

    // MARK: - Token Persistence
    /// Persists the provided database change token to ``defaults`` and updates
    /// the in‑memory copy.  Secure coding is enforced during archiving.
    private func persistDatabaseChangeToken(_ token: CKServerChangeToken) async throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                    requiringSecureCoding: true)
        defaults.set(data, forKey: databaseChangeTokenKey)
        self.privateDatabaseChangeToken = token
    }

    /// Persists the provided zone change token to ``defaults`` and updates
    /// the in‑memory copy.  Secure coding is enforced during archiving.
    private func persistZoneChangeToken(_ token: CKServerChangeToken) async throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: token,
                                                    requiringSecureCoding: true)
        defaults.set(data, forKey: zoneChangeTokenKey)
        self.zoneChangeToken = token
    }
}

// MARK: - CK helpers
private extension CKDatabase {
    func recordZone(withID id: CKRecordZone.ID) async throws -> CKRecordZone {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKFetchRecordZonesOperation(recordZoneIDs: [id])
            op.fetchRecordZonesCompletionBlock = { zonesByID, error in
                if let error { continuation.resume(throwing: error) }
                else if let zone = zonesByID?[id] { continuation.resume(returning: zone) }
                else { continuation.resume(throwing: CKError(.zoneNotFound)) }
            }
            self.add(op)
        }
    }
}

private extension CKRecord.ID {
    /// Attempts to parse a UUID from a recordName formatted as "Type-<uuid>".
    func parseUUID() -> UUID? {
        let comps = recordName.split(separator: "-")
        guard let last = comps.last else { return nil }
        return UUID(uuidString: String(last))
    }

    var recordNamePrefix: String {
        let comps = recordName.split(separator: "-")
        return comps.first.map(String.init) ?? ""
    }
}