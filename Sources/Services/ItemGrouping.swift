import Foundation

extension DownloadManager {
    /// `size` is what Size sorts by: a running card's live total, when known.
    static func sorted(
        _ items: [DownloadItem], by order: SortOrder, size: (DownloadItem) -> Int64? = \.totalBytes,
    ) -> [DownloadItem] {
        var result = items
        switch order {
        case .newest: result.sort { $0.addedAt > $1.addedAt }
        case .oldest: result.sort { $0.addedAt < $1.addedAt }
        case .name: result.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .size:
            result.sort { (size($0) ?? -1) > (size($1) ?? -1) }
        case .status: result.sort { $0.status < $1.status }
        }
        return result
    }

    /// Splits items, already sorted, into sections by status and day added, keeping their
    /// order inside each section. Empty sections are left out.
    static func grouped(
        _ items: [DownloadItem], now: Date = .now, calendar: Calendar = .current,
    ) -> [ItemGroup] {
        let sections = items.reduce(into: [ItemSection: [DownloadItem]]()) { result, item in
            let section: ItemSection = if item.status.isActive {
                .active
            } else if calendar.isDate(item.addedAt, inSameDayAs: now) {
                .today
            } else {
                .earlier
            }
            result[section, default: []].append(item)
        }
        return ItemSection.allCases.compactMap { section in
            sections[section].map { ItemGroup(section: section, items: $0) }
        }
    }
}

/// The list's sections, in display order.
enum ItemSection: CaseIterable {
    case active, today, earlier

    var title: String {
        switch self {
        case .active: "Active"
        case .today: "Today"
        case .earlier: "Earlier"
        }
    }
}

struct ItemGroup: Identifiable {
    let section: ItemSection
    let items: [DownloadItem]

    var id: ItemSection { section }
}
