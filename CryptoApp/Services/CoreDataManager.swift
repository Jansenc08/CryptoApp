import Foundation
import CoreData

final class CoreDataManager: CoreDataManagerProtocol {
    
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
                AppLogger.database("Core Data failed to load persistent stores: \(error), \(error.userInfo)", level: .error)
                
                // For production, we should handle this gracefully rather than crashing
                // This could be due to first launch, disk space, permissions, etc.
                print("⚠️ Core Data initialization failed, but app will continue. Error: \(error.localizedDescription)")
            } else {
                AppLogger.database("Core Data persistent stores loaded successfully", level: .info)
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        // ✅ FIXED: Ensure save happens on correct context queue
        context.perform { [weak self] in
            guard let self = self else { return }
            
            if self.context.hasChanges {
                do {
                    try self.context.save()
                    AppLogger.database("Core Data save successful", level: .debug)
                } catch {
                    AppLogger.database("Core Data save error: \(error.localizedDescription)", level: .error)
                    print("⚠️ Core Data save failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func delete<T: NSManagedObject>(_ object: T) {
        // ✅ FIXED: Ensure delete happens on correct context queue
        context.perform { [weak self] in
            guard let self = self else { return }
            
            self.context.delete(object)
            
            if self.context.hasChanges {
                do {
                    try self.context.save()
                    AppLogger.database("Core Data delete successful", level: .debug)
                } catch {
                    AppLogger.database("Core Data delete error: \(error.localizedDescription)", level: .error)
                    print("⚠️ Core Data delete failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type) -> [T] {
        let entityName = String(describing: objectType)
        let request = NSFetchRequest<T>(entityName: entityName)
        
        do {
            let results = try context.fetch(request)
            AppLogger.database("Core Data fetch successful for \(entityName): \(results.count) items", level: .debug)
            return results
        } catch {
            AppLogger.database("Core Data fetch error for \(entityName): \(error.localizedDescription)", level: .error)
            print("⚠️ Core Data fetch failed for \(entityName): \(error.localizedDescription)")
            return []
        }
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type, where predicate: NSPredicate) -> [T] {
        let entityName = String(describing: objectType)
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        
        do {
            let results = try context.fetch(request)
            AppLogger.database("Core Data fetch with predicate successful for \(entityName): \(results.count) items", level: .debug)
            return results
        } catch {
            AppLogger.database("Core Data fetch with predicate error for \(entityName): \(error.localizedDescription)", level: .error)
            print("⚠️ Core Data fetch with predicate failed for \(entityName): \(error.localizedDescription)")
            return []
        }
    }
    
    // Specific methods for WatchlistItem to avoid ambiguity
    func fetchWatchlistItems() -> [WatchlistItem] {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            AppLogger.database("Core Data fetch watchlist items successful: \(results.count) items", level: .debug)
            return results
        } catch {
            AppLogger.database("Core Data fetch watchlist items error: \(error.localizedDescription)", level: .error)
            print("⚠️ Core Data fetch watchlist items failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem] {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = predicate
        
        do {
            let results = try context.fetch(request)
            AppLogger.database("Core Data fetch watchlist items with predicate successful: \(results.count) items", level: .debug)
            return results
        } catch {
            AppLogger.database("Core Data fetch watchlist items with predicate error: \(error.localizedDescription)", level: .error)
            print("⚠️ Core Data fetch watchlist items with predicate failed: \(error.localizedDescription)")
            return []
        }
    }
} 
