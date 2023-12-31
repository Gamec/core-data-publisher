import Combine
import CoreData

public extension NSManagedObjectContext {
    func publisher<Entity: NSManagedObject>(for fetchRequest: NSFetchRequest<Entity>) -> AnyPublisher<[Entity], Never> {
        FetchedResultsPublisher(request: fetchRequest, context: self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
}
