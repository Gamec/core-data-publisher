import Combine
import CoreData

final class FetchedResultsSubscription<SubscriberType: Subscriber, Entity: NSManagedObject>: NSObject, Subscription, NSFetchedResultsControllerDelegate where SubscriberType.Input == [Entity] {
    /// Fetch request to observe
    private let fetchRequest: NSFetchRequest<Entity>

    private var subscriber: SubscriberType?
    private var managedObjectContext: NSManagedObjectContext?
    private var fetchedResultsController: NSFetchedResultsController<Entity>?
    private var didSendOnRequest = false

    init(subscriber: SubscriberType, fetchRequest: NSFetchRequest<Entity>, managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.fetchRequest = fetchRequest
        self.subscriber = subscriber

        super.init()

        createFetchedResultsController()
    }

    /// Sends the current objects on the first request only: `receive(on:)` forwards demand returned by
    /// operators that drop a value (`removeDuplicates`, `filter`), so re-sending here would loop forever.
    func request(_: Subscribers.Demand) {
        managedObjectContext?.performAndWait {
            guard !didSendOnRequest else { return }
            didSendOnRequest = true
            if let entities = fetchedResultsController?.fetchedObjects {
                _ = subscriber?.receive(entities)
            }
        }
    }

    func cancel() {
        // Clean up everything
        fetchedResultsController = nil
        managedObjectContext = nil
        subscriber = nil
    }

    private func createFetchedResultsController() {
        guard let managedObjectContext else {
            preconditionFailure("Managed object context should only be nil after cancelling subscription")
        }

        let fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        fetchedResultsController.delegate = self
        self.fetchedResultsController = fetchedResultsController

        managedObjectContext.performAndWait {
            do {
                try fetchedResultsController.performFetch()
                if let entities = fetchedResultsController.fetchedObjects {
                    _ = subscriber?.receive(entities)
                }
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }
    }

    // MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let entities = controller.fetchedObjects as? [Entity] {
            _ = subscriber?.receive(entities)
        }
    }
}
