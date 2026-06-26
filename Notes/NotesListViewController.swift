import UIKit
import CoreData

class NotesListViewController: UITableViewController {

    enum Constants {
        static let reuseID = "cell"
        static let title = "Notes"
    }
    private var context: NSManagedObjectContext { self.repository.viewContext }
    private let repository: NoteRepository
    private lazy var fetchedResultsController = self.repository.makeFetchedResultsController(delegate: self)
    
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText = ""
    
    init(repository: NoteRepository) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.repository.refreshDynamicSections()
        
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            print("Fetch failed")
            let alertVC = UIAlertController(
                title: "Fetch failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alertVC.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertVC, animated: true)
        }
        
    }
    private func setupUI() {
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.reuseID)
        // datasource уже проставлен
        
        self.title = Constants.title
        
        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .add,
                target: self,
                action: #selector(didTapAdd)
            ),
            UIBarButtonItem(
                title: "Upn all",
                style: .plain,
                target: self,
                action: #selector(didTapUnpinAll)
            )
            
        ]
        self.navigationItem.leftBarButtonItems = [
            UIBarButtonItem(
                title: "Gen500",
                style: .plain,
                target: self,
                action: #selector(didTapGenerate)
            ),
            UIBarButtonItem(
                barButtonSystemItem: .trash,
                target: self,
                action: #selector(didTapDeleteAll)
            )
        ]
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        
        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.placeholder = "Search notes"
    }
    /// Поиск и демонстрация тех заметок, которые
    /// удовлетворяют условию поиска
    private func refetchNotes() {
        self.fetchedResultsController.fetchRequest.predicate = self.repository.makeSearchPredicate(text: self.searchText)
        
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
    
    @objc private func didTapDeleteAll() {
        self.repository.deleteAllNotes()
    }
    
    @objc private func didTapUnpinAll() {
        self.repository.unpinAllNotes { [weak self] in
            guard let self else { return }
            self.repository.refreshDynamicSections()
            self.refetchNotes()
        }
    }
    
    @objc private func didTapGenerate() {
        self.repository.generateNotesInBackground(count: 500)
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
            self?.repository.delete(note)
            completion(true)
        }
        
        let pinTitle = note.isPinned ? "Unpin" : "Pin"
        let pinAction = UIContextualAction(style: .normal, title: pinTitle) { [weak self] _, _, completion in
            self?.repository.togglePin(note)
            completion(true)
        }
        pinAction.backgroundColor = .systemOrange
        pinAction.image = UIImage(systemName: note.isPinned ? "pin.slash" : "pin")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, pinAction])
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
