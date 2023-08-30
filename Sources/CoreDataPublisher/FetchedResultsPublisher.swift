import Combine
import CoreData

struct FetchedResultsPublisher<Entity: NSManagedObject>: Publisher {
    public typealias Output = [Entity]
    public typealias Failure = Error

    private let request: NSFetchRequest<Entity>
    private let context: NSManagedObjectContext

    init(request: NSFetchRequest<Entity>, context: NSManagedObjectContext) {
        self.request = request
        self.context = context
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, [Entity] == S.Input {
        subscriber.receive(subscription: FetchedResultsSubscription(
            subscriber: subscriber,
            fetchRequest: request,
            managedObjectContext: context
        ))
    }
}
