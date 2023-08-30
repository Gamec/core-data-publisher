import Combine
import CoreData

final class FetchedResultsSubscription<SubscriberType: Subscriber, Entity: NSManagedObject>: NSObject, Subscription, NSFetchedResultsControllerDelegate where SubscriberType.Input == [Entity] {
    /// Fetch request to observe
    private let fetchRequest: NSFetchRequest<Entity>

    private var subscriber: SubscriberType?
    private var managedObjectContext: NSManagedObjectContext?
    private var fetchedResultsController: NSFetchedResultsController<Entity>?

    private var entities = [Entity]() {
        didSet {
            _ = subscriber?.receive(entities)
        }
    }

    init(subscriber: SubscriberType, fetchRequest: NSFetchRequest<Entity>, managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.fetchRequest = fetchRequest
        self.subscriber = subscriber

        super.init()

        createFetchedResultsController()
    }

    func request(_: Subscribers.Demand) {
        _ = subscriber?.receive(entities)
    }

    func cancel() {
        // Clean up everything
        fetchedResultsController = nil
        managedObjectContext = nil
        subscriber = nil
        entities = []
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

        do {
            try fetchedResultsController.performFetch()
            if let objects = fetchedResultsController.fetchedObjects {
                entities = objects
            }
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    // MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let objects = controller.fetchedObjects as? [Entity] {
            entities = objects
        }
    }
}
