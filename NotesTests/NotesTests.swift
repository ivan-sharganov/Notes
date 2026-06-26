import XCTest
import CoreData
@testable import Notes

final class NotesRepositoryTests: XCTestCase {
    private var stack: TestCoreDataStack!
    private var sut: NoteRepository!
    
    override func setUp() {
        super.setUp()
        
        // Arrange зависимостей
        self.stack = TestCoreDataStack()
        self.sut = NoteRepository(persistentContainer: stack.persistentContainer)
    }
    
    override func tearDown() {
        self.sut = nil
        self.stack = nil
        
        super.tearDown()
    }
    
    func testManagedObjectSavesRequiredFields() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext
        
        let note = Note(context: context)
        note.id = UUID()
        note.body = "Body"
        note.title = "Test"
        note.updatedAt = Date()
        note.createdAt = Date()
        note.isPinned = false
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
        
        // Act
        try context.save()
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        // Assert
        let firstNote = try XCTUnwrap(notes.first)
        
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(firstNote.title, "Test")
        XCTAssertEqual(firstNote.body, "Body")
        XCTAssertFalse(firstNote.isPinned)
    }
    
    /// Проверка: pinned note попадает в секцию Pinned
    func testPinnedNoteHasPinnedSection() {
        // Arrange
        let context = self.stack.persistentContainer.viewContext
        
        let note = Note(context: context)
        note.id = UUID()
        note.title = "Pinned"
        note.body = nil
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isPinned = true
        
        // Act
        let sectionIdentifier = Note.makeSectionIdentifier(for: note)
        
        // Assert
        XCTAssertEqual(sectionIdentifier, "0|Pinned")
    }
    
    /// Проверка: predicate из repository находит заметку по title.
    func testSearchPredicateFindsTitle() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext
        let title = "Shopping list"
        let note = Note(context: context)
        note.id = UUID()
        note.title = title
        note.body = ""
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isPinned = false
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
        
        try context.save()
        
        // Act
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = self.sut.makeSearchPredicate(text: "shop")
        
        let result = try context.fetch(request)
        
        // Assert
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, title)
    }
    
    /// Проверка: predicate из repository находит заметку по body.
    func testSearchPredicateFindsBody() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext
        let body = "Buy milk tomorrow"
        let note = makeNote(
            in: context,
            title: "Random title",
            body: body
        )
        
        try context.save()
        
        // Act
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = self.sut.makeSearchPredicate(text: "milk")
        
        let result = try context.fetch(request)
        
        // Assert
        XCTAssertEqual(result.count, 1)
        
        let firstNote = try XCTUnwrap(result.first)
        XCTAssertEqual(firstNote.body, body)
        XCTAssertEqual(firstNote.objectID, note.objectID)
    }
    
    /// Проверка: NoteRepository.togglePin меняет isPinned и секцию.
    func testTogglePinChangesSection() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext

        let note = Note(context: context)
        note.id = UUID()
        note.title = "Note"
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isPinned = false
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)

        try context.save()
        let noteID = note.objectID

        // Act
        sut.togglePin(note)

        // Assert: читаем из store через новый context
        let verificationContext = stack.persistentContainer.newBackgroundContext()

        var storedIsPinned: Bool?
        var storedSectionIdentifier: String?
        var fetchError: Error?

        verificationContext.performAndWait {
            do {
                let storedNote = try verificationContext.existingObject(with: noteID) as! Note
                storedIsPinned = storedNote.isPinned
                storedSectionIdentifier = storedNote.sectionIdentifier
            } catch {
                fetchError = error
            }
        }

        XCTAssertNil(fetchError)
        XCTAssertEqual(storedIsPinned, true)
        XCTAssertEqual(storedSectionIdentifier, "0|Pinned")
    }
    
    
    func testEmptySearchTextReturnsNilPredicate() {
        // Act
        let predicate = self.sut.makeSearchPredicate(text: "     ")
        
        // Assert
        XCTAssertNil(predicate)
    }
    
    
    /// Проверка: NoteRepository.delete удаляет заметку из store.
    func testDeleteRemovesNoteFromStore() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext
        let note = makeNote(in: context, title: "Delete me", body: "Body")
        
        try context.save()
        
        // Act
        sut.delete(note)
        
        // Assert
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        XCTAssertEqual(notes.count, 0)
    }
    
    /// Проверка: refreshDynamicSections чинит неправильный sectionIdentifier и сохраняет изменение.
    func testRefreshDynamicSectionsPersistsUpdatedSectionIdentifier() throws {
        // Arrange
        let context = stack.persistentContainer.viewContext
        let note = makeNote(in: context, title: "Wrong section", body: nil)
        note.sectionIdentifier = "wrong"
        
        try context.save()
        let noteID = note.objectID
        
        // Act
        sut.refreshDynamicSections()
        
        // Assert: читаем из store через новый context
        let verificationContext = stack.persistentContainer.newBackgroundContext()
        
        var storedSectionIdentifier: String?
        var fetchError: Error?
        
        verificationContext.performAndWait {
            do {
                let storedNote = try verificationContext.existingObject(with: noteID) as! Note
                storedSectionIdentifier = storedNote.sectionIdentifier
            } catch {
                fetchError = error
            }
        }
        
        XCTAssertNil(fetchError)
        XCTAssertEqual(storedSectionIdentifier, Note.makeSectionIdentifier(for: note))
    }
    
    private func makeNote(
        in context: NSManagedObjectContext,
        title: String,
        body: String?,
        isPinned: Bool = false,
        updatedAt: Date = Date()
    ) -> Note {
        let note = Note(context: context)
        note.id = UUID()
        note.title = title
        note.body = body
        note.createdAt = updatedAt
        note.updatedAt = updatedAt
        note.isPinned = isPinned
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
        
        return note
    }
}
