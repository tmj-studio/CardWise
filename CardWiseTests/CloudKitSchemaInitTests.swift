import XCTest
import CoreData
import SwiftData
@testable import CardWise

/// One-shot utility, not part of the normal suite: pushes the SwiftData model's
/// CloudKit schema to the container's **Development** environment so it can then be
/// deployed to Production in the CloudKit Console (needed whenever the @Model set
/// changes). Requires a signed test run (do NOT pass CODE_SIGNING_ALLOWED=NO) and
/// network; an iCloud account is NOT required.
///
///   TEST_RUNNER_CLOUDKIT_SCHEMA_INIT=1 xcodebuild test \
///     -project CardWise.xcodeproj -scheme CardWise \
///     -destination 'platform=iOS Simulator,name=iPhone 17' \
///     -only-testing:CardWiseTests/CloudKitSchemaInitTests
final class CloudKitSchemaInitTests: XCTestCase {

    func testInitializeCloudKitSchema() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLOUDKIT_SCHEMA_INIT"] == "1",
            "Schema init is a manual, network-touching operation — set TEST_RUNNER_CLOUDKIT_SCHEMA_INIT=1 to run"
        )

        let model = try XCTUnwrap(
            NSManagedObjectModel.makeManagedObjectModel(
                for: [UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self]
            ),
            "SwiftData models could not be bridged to a Core Data model"
        )

        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cloudkit-schema-init-\(UUID().uuidString).sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.cardwise.app")
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        let container = NSPersistentCloudKitContainer(name: "CardWise", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        let loaded = expectation(description: "store loaded")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 30)
        XCTAssertNil(loadError, "Store failed to load: \(String(describing: loadError))")

        // Uploads the record-type definitions to the CloudKit Development environment.
        try container.initializeCloudKitSchema()
    }
}
