import CoreData
/// Класс-подмена настоящего persistentStore.
/// Не делает записей на диск, потому что создает новое пустое временное хранилище в RAM.
/// Нам доступны проверки базы, но не делаем в нее записи, только в RAM,
/// что не отражается на настоящей базе
final class TestCoreDataStack {
    let persistentContainer: NSPersistentContainer
    
    init() {
        self.persistentContainer = NSPersistentContainer(name: "Notes")
        let description = NSPersistentStoreDescription()
        // NSInMemoryStoreType означает: Core Data создаёт новое пустое временное хранилище только в RAM.
        description.type = NSInMemoryStoreType
        
        self.persistentContainer.persistentStoreDescriptions = [description]
        
        self.persistentContainer.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load in-memory store: \(error.localizedDescription)")
            }
        }
        
        self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
}
