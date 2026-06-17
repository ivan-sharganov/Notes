import UIKit
import CoreData

class NotesListViewController: UITableViewController {

    enum Constants {
        static let reuseID = "cell"
        static let title = "Notes"
    }
    private let context: NSManagedObjectContext
    
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText = ""
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Note> = {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Note.sectionIdentifier), ascending: true),
            NSSortDescriptor(key: #keyPath(Note.isPinned), ascending: false),
            NSSortDescriptor(key: #keyPath(Note.updatedAt), ascending: false)
        ]
        
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: self.context,
            sectionNameKeyPath: #keyPath(Note.sectionIdentifier),
            cacheName: nil
        )
        frc.delegate = self
        
        return frc
    }()
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.refreshDynamicSections()
        
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            print("Fetch failed")
            let alertVC = UIAlertController(title: "Fetch failed", message: "Check connection", preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertVC, animated: true)
        }
        
    }
    private func setupUI() {
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.reuseID)
        // datasource уже проставлен
        
        self.title = Constants.title
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        
        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.placeholder = "Search notes"
    }
    
    private func makePredicate() -> NSPredicate? {
        let text = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
    
    private func refetchNotes() {
        self.fetchedResultsController.fetchRequest.predicate = makePredicate()
        
        do {
            try fetchedResultsController.performFetch()
            self.tableView.reloadData()
        } catch {
            print("Fetch error:", error.localizedDescription)
        }
    }
    
    @objc private func didTapAdd() {
        self.navigationController?.pushViewController(
            NoteEditorViewController(context: self.context, note: nil),
            animated: true
        )
    }
    /// Обновляет, если нужно, имена секций. Чтобы при
    /// перезапуске сразу видели актуальные данные
    private func refreshDynamicSections() {
        // TODO: сделать оптимизацию чтобы не fetch-ить все заметки 
        let request: NSFetchRequest<Note> = Note.fetchRequest()

        do {
            let notes = try context.fetch(request)

            for note in notes {
                let newSectionIdentifier = Note.makeSectionIdentifier(for: note)

                if note.sectionIdentifier != newSectionIdentifier {
                    note.sectionIdentifier = newSectionIdentifier
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Refresh sections error:", error.localizedDescription)
        }
    }
}

// MARK: - UISearchResultsUpdating

extension NotesListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        self.searchText = searchController.searchBar.text ?? ""
        self.refetchNotes()
    }
}


// MARK: - UITableViewDataSource

extension NotesListViewController {

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.reuseID, for: indexPath)
        let note = self.fetchedResultsController.object(at: indexPath)
        
        var contentConfiguration = cell.defaultContentConfiguration()
        contentConfiguration.text = note.title
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        contentConfiguration.secondaryText = formatter.string(from: note.updatedAt)
        
        cell.contentConfiguration = contentConfiguration
        return cell
        
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        self.fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let name = fetchedResultsController.sections?[section].name else {
            return nil
        }
        return Note.displaySectionTitle(from: name)
    }
    // ‼️ это старое апи кнопки по свайпу, нам справа надо 2 кнопки: удаление и pin/unpin
//    override func tableView(
//        _ tableView: UITableView,
//        commit editingStyle: UITableViewCell.EditingStyle,
//        forRowAt indexPath: IndexPath
//    ) {
//        guard editingStyle == .delete else { return }
//        
//        let note = fetchedResultsController.object(at: indexPath)
//        self.context.delete(note)
//
//        do {
//            try self.context.save()
//        } catch {
//            print("Deleting error")
//        }
//    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let note = fetchedResultsController.object(at: indexPath)
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.delete(note)
            completion(true)
        }
        
        let pinTitle = note.isPinned ? "Unpin" : "Pin"
        let pinAction = UIContextualAction(style: .normal, title: pinTitle) { [weak self] _, _, completion in
            self?.togglePin(note)
            completion(true)
        }
        pinAction.backgroundColor = .systemOrange
        pinAction.image = UIImage(systemName: note.isPinned ? "pin.slash" : "pin")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, pinAction])
    }
    
    private func delete(_ note: Note) {
        context.delete(note)
        
        do {
            try context.save()
        } catch {
            print("Delete error:", error.localizedDescription)
        }
    }
    
    private func togglePin(_ note: Note) {
        note.isPinned.toggle()
        note.sectionIdentifier = Note.makeSectionIdentifier(for: note)
        do {
            try context.save()
        } catch {
            print("Pin error:", error.localizedDescription)
        }
    }
}

// MARK: - UITableViewDelegate

extension NotesListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.navigationController?.pushViewController(
            NoteEditorViewController(
                context: self.context,
                note: self.fetchedResultsController.object(at: indexPath)
            ),
            animated: true
        )
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension NotesListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            if let newIndexPath {
                self.tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
        case .delete:
            if let indexPath {
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        case .move:
            if let indexPath {
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            if let newIndexPath {
                self.tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
        case .update:
            if let indexPath {
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        @unknown default:
            self.tableView.reloadData()
        }
    }
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        default:
            break
        }
    }
}
