import Combine
import CoreData

/// All mutable state is confined to the context's queue.
final class FetchedResultsSubscription<SubscriberType: Subscriber, Entity: NSManagedObject>: NSObject, Subscription, NSFetchedResultsControllerDelegate where SubscriberType.Input == [Entity] {
    private let managedObjectContext: NSManagedObjectContext
    private var subscriber: SubscriberType?
    private var fetchedResultsController: NSFetchedResultsController<Entity>?
    private var demand = Subscribers.Demand.none
    private var hasUnsentObjects = true

    init(subscriber: SubscriberType, fetchRequest: NSFetchRequest<Entity>, managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.subscriber = subscriber

        super.init()

        managedObjectContext.performAndWait {
            let fetchedResultsController = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            fetchedResultsController.delegate = self
            self.fetchedResultsController = fetchedResultsController
            do {
                try fetchedResultsController.performFetch()
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }
    }

    func request(_ demand: Subscribers.Demand) {
        managedObjectContext.performAndWait {
            self.demand += demand
            sendIfNeeded()
        }
    }

    func cancel() {
        managedObjectContext.performAndWait {
            fetchedResultsController?.delegate = nil
            fetchedResultsController = nil
            subscriber = nil
        }
    }

    // MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        hasUnsentObjects = true
        sendIfNeeded()
    }

    /// Sends only against outstanding demand: `ReplaceError` traps on an unrequested value, and re-sending
    /// on every request loops forever behind `receive(on:)` + `removeDuplicates`.
    private func sendIfNeeded() {
        guard hasUnsentObjects, demand > 0, let subscriber, let objects = fetchedResultsController?.fetchedObjects else { return }
        hasUnsentObjects = false
        demand -= 1
        demand += subscriber.receive(objects)
    }
}
