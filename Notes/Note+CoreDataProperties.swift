public import Foundation
public import CoreData


public typealias NoteCoreDataPropertiesSet = NSSet

extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var body: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var isPinned: Bool
    @NSManaged public var title: String
    @NSManaged public var updatedAt: Date

}

extension Note : Identifiable {

}
