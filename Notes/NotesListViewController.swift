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
            NSSortDescriptor(key: #keyPath(Note.isPinned), ascending: false),
            NSSortDescriptor(key: #keyPath(Note.updatedAt), ascending: false)
        ]
        
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: self.context,
            sectionNameKeyPath: nil,
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
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            print("Fetch failed")
            let alertVC = UIAlertController(title: "Fetch failed", message: "Check connection", preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertVC, animated: true)
        }
        self.setupUI()
        
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
            format: "%K CONTAINS[cd] %@",
            #keyPath(Note.title),
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
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        
        let note = fetchedResultsController.object(at: indexPath)
        self.context.delete(note)

        do {
            try self.context.save()
        } catch {
            print("Deleting error")
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
            if let newIndexPath {
                self.tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            if let indexPath {
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        case .update:
            if let indexPath {
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        @unknown default:
            self.tableView.reloadData()
        }
    }
}
