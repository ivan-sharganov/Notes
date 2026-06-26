import CoreData

/// Класс-подмена настоящего persistentStore приложения.
/// По умолчанию создает новое пустое временное хранилище в RAM.
final class TestCoreDataStack {
    enum StoreType {
        case inMemory
        case temporarySQLite
    }
    
    let persistentContainer: NSPersistentContainer
    private let storeURL: URL?
    
    init(storeType: StoreType = .inMemory) {
        self.persistentContainer = NSPersistentContainer(name: "Notes")
        
        let description: NSPersistentStoreDescription
        
        switch storeType {
        case .inMemory:
            // NSInMemoryStoreType быстрый, но не поддерживает batch update/delete.
            self.storeURL = nil
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            
        case .temporarySQLite:
            // Batch operations работают на SQLite store, поэтому для таких тестов нужен временный файл.
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotesTests-\(UUID().uuidString).sqlite")
            
            self.storeURL = url
            description = NSPersistentStoreDescription(url: url)
            description.type = NSSQLiteStoreType
        }
        
        self.persistentContainer.persistentStoreDescriptions = [description]
        
        self.persistentContainer.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load in-memory store: \(error.localizedDescription)")
            }
        }
        
        self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    deinit {
        guard let storeURL else { return }
        
        try? persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
            at: storeURL,
            ofType: NSSQLiteStoreType
        )
        
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(atPath: storeURL.path + "-shm")
        try? FileManager.default.removeItem(atPath: storeURL.path + "-wal")
    }
}
