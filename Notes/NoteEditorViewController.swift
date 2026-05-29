import UIKit
import CoreData

final class NoteEditorViewController: UIViewController {
    
    private let context: NSManagedObjectContext
    private let note: Note?
    
    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Title"
        tf.text = "Title"
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.backgroundColor = .green
        
        return tf
    }()
    
    private lazy var bodyTextView: UITextView = {
        let tv = UITextView()
        tv.text = "Title"
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .red

        return tv
    }()
    
    init(context: NSManagedObjectContext, note: Note) {
        self.context = context
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.updateData()
    }
    
    private func updateData() {
        guard let note else { return }
        self.titleTextField.text = note.title
        self.bodyTextView.text = note.body
    }
    private func setupUI() {
        [self.bodyTextView, self.titleTextField].forEach {
            self.view.addSubview($0)
        }
        let constraints = [
            self.titleTextField.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.titleTextField.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            self.titleTextField.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            self.titleTextField.bottomAnchor.constraint(equalTo: self.bodyTextView.topAnchor),
            
            self.bodyTextView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            self.bodyTextView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            self.bodyTextView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(didTapSave)
        )
    }
    
    @objc private func didTapSave() {
        print("Did save")
        guard let exNote = self.note else { return }
        let note = Note(context: self.context)
        note.id = exNote.id
        note.isPinned = exNote.isPinned
        note.createdAt = exNote.createdAt
        note.updatedAt = Date()
        note.title = self.titleTextField.text ?? ""
        note.body = self.bodyTextView.text ?? ""
        
        do {
            try context.save()
        } catch {
            print("Errrrror!!!!!")
        }
    }
    
}
