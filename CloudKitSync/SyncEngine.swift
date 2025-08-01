import Foundation
import CloudKit

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

    // MARK: - Remote Sync
    /// Pulls down all remote changes since the last successful sync.  This
    /// implementation first requests database level changes to determine which
    /// zones have been modified, then fetches record level changes from the
    /// affected zones.  On completion it persists any updated change tokens.
    public func pullRemoteChanges() async throws {
        // Fetch database changes using the last known database change token.
        let dbChanges = try await privateDatabase.databaseChanges(since: privateDatabaseChangeToken)

        for zoneID in dbChanges.changedRecordZoneIDs {
            // Fetch record level changes for each zone since our stored zone token.
            let zoneChanges = try await privateDatabase.recordZoneChanges(inZoneWith: zoneID,
                                                                          since: zoneChangeToken)
            // Extract changed records into an array.  Each result is a Result<CKRecord, Error>.
            let changedRecords = zoneChanges.recordChanges.compactMap { try? $0.get() }

            // TODO: Process changedRecords and deletedIDs into Core Data.
            // For the purposes of this refactor we simply log the results to
            // demonstrate that delta sync is working.
            print("Changed records: \(changedRecords)")
            print("Deleted record IDs: \(zoneChanges.recordDeletions.map { $0.recordID })")

            // Persist the new zone token if one was provided by CloudKit.
            if let newZoneToken = zoneChanges.changeToken {
                try await self.persistZoneChangeToken(newZoneToken)
            }

            // After persisting the token, delegate to per‑entity download
            // helpers to process the delta changes.  These methods will
            // eventually transform CKRecord deltas into managed objects and
            // delete any removed records.  They are currently stubs.
            try await downloadActivities()
            try await downloadSessions()
        }

        // Persist the new database change token if one was provided.
        if let newDBToken = dbChanges.changeToken {
            try await self.persistDatabaseChangeToken(newDBToken)
        }
    }

    // MARK: - Local Sync
    /// Uploads any local changes to CloudKit.  This stub exists to mirror the
    /// interface of ``LegacyCloudKitService``; its implementation requires tracking
    /// changed objects in Core Data and is beyond the scope of this refactor.
    public func uploadLocalChanges() async throws {
        // Delegate uploading into granular helper methods.  These helpers
        // should locate changed entities in Core Data and convert them
        // into CKRecord values for submission.  They are currently
        // stubs pending a full Core Data change tracking mechanism.
        try await uploadActivities()
        try await uploadSessions()
    }

    /// Pushes any unsynchronised local changes to CloudKit.  This method
    /// provides a semantic wrapper around ``uploadLocalChanges()`` and
    /// exists to align with the naming in the new ``sync()`` workflow.
    private func pushLocalChanges() async throws {
        try await uploadLocalChanges()
    }

    /// Uploads all modified Activity records to CloudKit.  This helper
    /// encapsulates the logic for encoding ``Activity`` into CKRecord
    /// instances and saving them to the private database.  The actual
    /// implementation will depend on how change tracking is performed in
    /// Core Data and is thus left as a TODO.
    private func uploadActivities() async throws {
        // TODO: Query Core Data for changed Activity objects and save them
        // to CloudKit.  Use CKModifyRecordsOperation for batch efficiency.
    }

    /// Uploads all modified ActivitySession records to CloudKit.  Similar to
    /// ``uploadActivities()``, this helper is responsible for serialising
    /// ActivitySession objects into CKRecord values and persisting them.
    private func uploadSessions() async throws {
        // TODO: Query Core Data for changed ActivitySession objects and save
        // them to CloudKit.
    }

    /// Downloads updated Activity records from CloudKit based on the delta
    /// information returned by the ``recordZoneChanges(inZoneWith:since:)`` API.
    /// Implementations should map CKRecords into Core Data managed objects.
    private func downloadActivities() async throws {
        // TODO: Convert changed CKRecord objects into Activity entities and
        // persist them in Core Data.  Delete local objects that were removed.
    }

    /// Downloads updated ActivitySession records from CloudKit.  Like
    /// ``downloadActivities()``, this helper handles translating CKRecords
    /// into managed objects and applying deletions.
    private func downloadSessions() async throws {
        // TODO: Convert changed CKRecord objects into ActivitySession
        // entities and persist them in Core Data.
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
        // TODO: Implement uploading of specific Activity objects.  Use
        // CKModifyRecordsOperation for efficiency.
    }

    /// Uploads the provided activity sessions to CloudKit.  See
    /// ``uploadActivities(_:)`` for details.
    private func uploadSessions(_ sessions: [ActivitySession]) async throws {
        // TODO: Implement uploading of specific ActivitySession objects.
    }

    /// Processes a fetched ``CKRecord`` representing an Activity.  A concrete
    /// implementation will map record fields onto an existing or new
    /// ``Activity`` managed object.
    private func processActivityRecord(_ record: CKRecord) async throws {
        // TODO: Convert record into Activity and persist to Core Data.
    }

    /// Processes a fetched ``CKRecord`` representing an ActivitySession.
    private func processSessionRecord(_ record: CKRecord) async throws {
        // TODO: Convert record into ActivitySession and persist to Core Data.
    }

    /// Constructs a predicate that matches unsynchronised objects.  The
    /// signature mirrors the deprecated service's helper.  Clients should
    /// supply the entity name and any additional filtering criteria.
    private func predicateForUnsynced(entityName: String, lastSync: Date?) -> NSPredicate {
        // TODO: Build an NSPredicate that filters objects with a nil
        // ``syncDate`` or a ``syncDate`` later than ``lastSync``.
        return NSPredicate(value: true)
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