import Foundation
import CoreData

final class CoreDataManager: CoreDataManagerProtocol {
    static let shared = CoreDataManager()
    
    /**
     * DEPENDENCY INJECTION INITIALIZER
     * 
     * Internal access allows for:
     * - Testing with fresh instances (in-memory store)
     * - Dependency injection in tests
     * - Production singleton pattern
     */
    init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WatchlistModel")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Core Data save error: \(error)")
            }
        }
    }
    
    func delete<T: NSManagedObject>(_ object: T) {
        context.delete(object)
        save()
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type) -> [T] {
        let entityName = String(describing: objectType)
        let request = NSFetchRequest<T>(entityName: entityName)
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Core Data fetch error: \(error)")
            return []
        }
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type, where predicate: NSPredicate) -> [T] {
        let entityName = String(describing: objectType)
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Core Data fetch with predicate error: \(error)")
            return []
        }
    }
    
    // Specific methods for WatchlistItem to avoid ambiguity
    func fetchWatchlistItems() -> [WatchlistItem] {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Core Data fetch watchlist items error: \(error)")
            return []
        }
    }
    
    func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem] {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = predicate
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Core Data fetch watchlist items with predicate error: \(error)")
            return []
        }
    }
} 
