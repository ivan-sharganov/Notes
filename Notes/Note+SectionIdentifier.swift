import Foundation

extension Note {
    static func makeSectionIdentifier(for note: Note) -> String {
        if note.isPinned {
            return "0|Pinned"
        }

        let calendar = Calendar.current
        let date = note.updatedAt

        if calendar.isDateInToday(date) {
            return "1|Сегодня"
        }

        if calendar.isDateInYesterday(date) {
            return "2|Вчера"
        }

        if let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date()),
           calendar.isDate(date, inSameDayAs: dayBeforeYesterday) {
            return "3|Позавчера"
        }

        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
           date >= weekAgo {
            return "4|На этой неделе"
        }

        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            let keyFormatter = DateFormatter()
            keyFormatter.dateFormat = "yyyy-MM"

            let titleFormatter = DateFormatter()
            titleFormatter.dateFormat = "LLLL"

            let sortKey = keyFormatter.string(from: date)
            let title = titleFormatter.string(from: date).capitalized

            return "5|\(sortKey)|\(title)"
            // заметки, которые не сегодня, не вчера, не позавчера, не на этой неделе, но всё ещё в текущем году.
            // без sortKey было бы 5|Июнь 5|Май и сортировало бы по алфавиту, а не порядку. теперь:
            // 5|2026-06|Июнь      5|2026-05|Май
        }

        let year = calendar.component(.year, from: date)
        let sortKey = 9999 - year // инвертируем год для правильной сортировки
        return "6|\(sortKey)|\(year)"
    }

    static func displaySectionTitle(from sectionIdentifier: String) -> String {
        sectionIdentifier.components(separatedBy: "|").last ?? sectionIdentifier
    }
}
