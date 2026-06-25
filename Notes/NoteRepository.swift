import CoreData

final class NoteRepository {
    let persistentContainer: NSPersistentContainer
    let viewContext: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.viewContext = persistentContainer.viewContext
    }
    
    func makeFetchedResultsController(
        delegate: NSFetchedResultsControllerDelegate
    ) -> NSFetchedResultsController<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Note.sectionIdentifier), ascending: true),
            NSSortDescriptor(key: #keyPath(Note.isPinned), ascending: false),
            NSSortDescriptor(key: #keyPath(Note.updatedAt), ascending: false)
        ]
        
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: self.viewContext,
            sectionNameKeyPath: #keyPath(Note.sectionIdentifier),
            cacheName: nil
        )
        frc.delegate = delegate
        
        return frc
    }
    
    func makeSearchPredicate(text: String) -> NSPredicate? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            return nil
        }
        return NSPredicate(
            format: "%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@",
            #keyPath(Note.title),
            text,
            #keyPath(Note.body),
            text
        )
    }
    
    func delete(_ note: Note) {
        self.viewContext.delete(note)
        
        do {
            try self.viewContext.save()
        } catch {
            print("Delete error:", error.localizedDescription)
        }
    }
    
    func togglePin(_ note: Note) {
        note.isPinned.toggle()
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
        do {
            try self.viewContext.save()
        } catch {
            print("Pin error:", error.localizedDescription)
        }
    }
    
    /// Обновляет, если нужно, имена секций. Чтобы при
    /// перезапуске сразу видели актуальные данные
    func refreshDynamicSections() {
        // TODO: сделать оптимизацию чтобы не fetch-ить все заметки
        let request: NSFetchRequest<Note> = Note.fetchRequest()

        do {
            let notes = try self.viewContext.fetch(request)

            for note in notes {
                let newSectionIdentifier = Note.makeSectionIdentifier(for: note)

                if note.sectionIdentifier != newSectionIdentifier {
                    note.sectionIdentifier = newSectionIdentifier
                }
            }

            if self.viewContext.hasChanges {
                try self.viewContext.save()
            }
        } catch {
            print("Refresh sections error:", error.localizedDescription)
        }
    }
    
    func generateNotesInBackground(count: Int) {
        let backgroundContext = self.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform { [weak self] in
            guard let self else { return }
            
            for i in 1...count {
                let date = self.randomDate()
                let note = Note(context: backgroundContext)
                note.title = "Generated note \(i)"
                note.body = "Created in background context"
                
                note.id = UUID()
                note.updatedAt = date
                note.createdAt = date
                note.isPinned = Bool.random()
                note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                print("Background insert error: \(error.localizedDescription)")
            }
        }
    }
    private func randomDate() -> Date {
        let yearsAgo = Int.random(in: 0...12)
        return Calendar.current.date(
            byAdding: .year,
            value: -yearsAgo,
            to: Date()
        ) ?? Date()
    }
    func unpinAllNotes(completion: @escaping () -> Void) {
        let backgroundContext = self.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform { [weak self] in
            guard let self else { return }
            
            let request = NSBatchUpdateRequest(entityName: "Note")
            request.predicate = NSPredicate(
                format: "%K == %@",
                #keyPath(Note.isPinned),
                NSNumber(value: true)
            )
            request.propertiesToUpdate = [
                #keyPath(Note.isPinned): NSNumber(value: false)
            ]
            
            request.resultType = .updatedObjectIDsResultType
            
            do {
                let result = try backgroundContext.execute(request) as? NSBatchUpdateResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                
                let changes: [AnyHashable: Any] = [
                    NSUpdatedObjectsKey: objectIDs
                ]
                DispatchQueue.main.async {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [self.viewContext]
                    )
                    completion()
                }
            } catch {
                print("Batch update error: \(error.localizedDescription)")
            }
            
        }
    }
    
    func deleteAllNotes() {
        let backgroundContext = self.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform { [weak self] in
            guard let self else { return }
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            // Без resultTypeObjectIDs Core Data просто удалит записи из store,
            // но viewContext и FRC могут не понять, какие именно объекты исчезли.
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: objectIDs
                ]
                
                // для viewContext: “эти объекты были удалены вне тебя, обнови своё состояние”.
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [self.viewContext]
                )
            } catch {
                print("Batch delete error:", error.localizedDescription)
            }
        }
        // обычное удаление:
        //
        // context.delete(note)
        // try context.save()
        
        // удаление батчами:
        //
        // context.execute(NSBatchDeleteRequest(...))
        
        // Обычное удаление идёт через context и нормально трекается.
        // Batch delete идёт напрямую в store, поэтому требует ручного merge.
    }

}
