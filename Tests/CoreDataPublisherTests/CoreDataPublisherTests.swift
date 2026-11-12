import Combine
import CoreData
@testable import CoreDataPublisher
import XCTest

final class CoreDataPublisherTests: XCTestCase {
    private var container: NSPersistentContainer!

    private var context: NSManagedObjectContext {
        container.viewContext
    }

    override func setUpWithError() throws {
        let entity = NSEntityDescription()
        entity.name = "Item"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = true
        entity.properties = [name]
        let model = NSManagedObjectModel()
        model.entities = [entity]

        container = NSPersistentContainer(name: "Test", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    func testDroppedDuplicateDoesNotReEmitForever() throws {
        let item = try insertItem(named: "A")

        var emissions = 0
        let cancellable = context.publisher(for: itemsRequest())
            .receive(on: DispatchQueue.main)
            .map { items -> [NSManagedObjectID] in
                emissions += 1
                return items.map(\.objectID)
            }
            .removeDuplicates()
            .sink { _ in }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        item.setValue("A", forKey: "name")
        try context.save()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        cancellable.cancel()

        XCTAssertLessThanOrEqual(emissions, 4, "an unchanged result dropped by removeDuplicates must not trigger another emission")
    }

    func testEmitsWhenFetchedObjectsChange() throws {
        var counts: [Int] = []
        let cancellable = context.publisher(for: itemsRequest())
            .receive(on: DispatchQueue.main)
            .map(\.count)
            .removeDuplicates()
            .sink { counts.append($0) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        try insertItem(named: "A")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        cancellable.cancel()

        XCTAssertEqual(counts, [0, 1])
    }

    func testChangeWithoutDemandIsDeliveredOnNextRequest() throws {
        let subscriber = ManualDemandSubscriber()
        context.publisher(for: itemsRequest()).subscribe(subscriber)

        subscriber.request(1)
        try insertItem(named: "A")
        try insertItem(named: "B")
        XCTAssertEqual(subscriber.counts, [0], "a change with no outstanding demand must wait for the next request")

        subscriber.request(1)
        XCTAssertEqual(subscriber.counts, [0, 2], "the next request gets the latest objects once")

        subscriber.request(1)
        XCTAssertEqual(subscriber.counts, [0, 2], "a request with nothing new to send must not re-send")
    }

    @MainActor
    func testValuesSequenceSurvivesChangesBetweenIterations() async throws {
        var counts: [Int] = []
        for await items in context.publisher(for: itemsRequest()).values {
            counts.append(items.count)
            if items.count >= 4 { break }
            try insertItem(named: "\(items.count)")
            try insertItem(named: "\(items.count)-extra")
        }

        XCTAssertEqual(counts, [0, 2, 4], "both saves made during an iteration arrive together on the next one")
    }

    private func itemsRequest() -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return request
    }

    @discardableResult
    private func insertItem(named name: String) throws -> NSManagedObject {
        let item = NSManagedObject(entity: container.managedObjectModel.entitiesByName["Item"]!, insertInto: context)
        item.setValue(name, forKey: "name")
        try context.save()
        return item
    }
}

private final class ManualDemandSubscriber: Subscriber {
    typealias Input = [NSManagedObject]
    typealias Failure = Never

    private(set) var counts: [Int] = []
    private var subscription: Subscription?

    func request(_ count: Int) {
        subscription?.request(.max(count))
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
    }

    func receive(_ input: [NSManagedObject]) -> Subscribers.Demand {
        counts.append(input.count)
        return .none
    }

    func receive(completion _: Subscribers.Completion<Never>) {}
}
