import UIKit

final internal class NotesListViewController: UITableViewController {
    
    let data = ["1", "2", "3"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
    }
    
    private func setupUI() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )
        
        self.title = Constants.notesTitle
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellIdentifier)
        self.tableView.dataSource = self
    }
    
    @objc private func didTapAdd() {
        
    }
}

extension NotesListViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier, for: indexPath)
        cell.textLabel?.text = self.data[indexPath.row]
        
        return cell
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.data.count
    }
}


private enum Constants {
    static let notesTitle = "Notes"
    static let cellIdentifier = "cell"
}
