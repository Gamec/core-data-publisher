import Combine
import CoreData
@testable import CoreDataPublisher
import XCTest

final class CoreDataPublisherTests: XCTestCase {
    private var container: NSPersistentContainer!

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

    private func itemsRequest() -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return request
    }

    func testDroppedDuplicateDoesNotReEmitForever() throws {
        let context = container.viewContext
        let item = NSManagedObject(entity: container.managedObjectModel.entitiesByName["Item"]!, insertInto: context)
        item.setValue("A", forKey: "name")
        try context.save()

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
        let context = container.viewContext
        var counts: [Int] = []
        let cancellable = context.publisher(for: itemsRequest())
            .receive(on: DispatchQueue.main)
            .map(\.count)
            .removeDuplicates()
            .sink { counts.append($0) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        _ = NSManagedObject(entity: container.managedObjectModel.entitiesByName["Item"]!, insertInto: context)
        try context.save()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        cancellable.cancel()

        XCTAssertEqual(counts, [0, 1])
    }
}
