import UIKit
import CoreData

final class NoteEditorViewController: UIViewController {
    
    private let context: NSManagedObjectContext
    private let note: Note?  // (nil = create,  !nil = edit)
    
    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Title"
        tf.text = "Title"
        // обводка
        tf.layer.borderColor = UIColor.systemGray4.cgColor
        tf.layer.borderWidth = 2
        tf.translatesAutoresizingMaskIntoConstraints = false
        // радиус в viewDidLayoutSubviews
        
        // отступ слева
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.leftView = leftPadding
        tf.leftViewMode = .always
        
        let rightPadding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.rightView = rightPadding
        tf.rightViewMode = .always
        
        return tf
    }()
    
    private lazy var bodyTextView: UITextView = {
        let tv = UITextView()
        tv.text = "Title"
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.textContainerInset = UIEdgeInsets(top: 7, left: 7, bottom: 0, right: 7)
        tv.layer.borderWidth = 2
        tv.layer.borderColor = UIColor.systemGray4.cgColor
        tv.layer.cornerRadius = 15

        return tv
    }()
    
    init(context: NSManagedObjectContext, note: Note?) {
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
    override func viewDidLayoutSubviews() {
        self.titleTextField.layer.cornerRadius = self.titleTextField.frame.height / 2
    }
    
    private func updateData() {
        if let note {
            self.title = "Edit"
            self.titleTextField.text = note.title
            self.bodyTextView.text = note.body
        } else {
            self.title = "New note"
        }
    }
    private func setupUI() {
        self.view.backgroundColor = .systemBackground
        [self.bodyTextView, self.titleTextField].forEach {
            self.view.addSubview($0)
        }
        let constraints = [
            self.titleTextField.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.titleTextField.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.leftPadding),
            self.titleTextField.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.leftPadding),
            self.titleTextField.bottomAnchor.constraint(equalTo: self.bodyTextView.topAnchor, constant: -15),
            self.titleTextField.heightAnchor.constraint(equalToConstant: 40),
            
            self.bodyTextView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.leftPadding),
            self.bodyTextView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.leftPadding),
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
        let title = self.titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            self.showAlert(title: "Empty title", message: "Enter title for note")
            return
        }
        
        if let exNote = self.note {
            // edit
            exNote.title = title
            exNote.body = self.bodyTextView.text ?? ""
            exNote.updatedAt = Date()
        } else {
            let note = Note(context: self.context)
            note.id = UUID()
            note.isPinned = false
            note.createdAt = Date()
            note.title = title
            note.body = self.bodyTextView.text ?? ""
            note.updatedAt = Date()
        }
        do {
            try context.save()
            self.navigationController?.popViewController(animated: true)
        } catch {
            self.showAlert(title: "Save failed", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    private enum Constants {
        static let leftPadding = 5.0
    }
    
}
