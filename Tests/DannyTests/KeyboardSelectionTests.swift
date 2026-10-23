@testable import Danny
import Foundation
import Testing

/// The arrow keys move the selection through the list in display order; ⌫ hands it to a neighbour.
struct KeyboardSelectionTests {
    private let items = (1 ... 3).map { item(path: "\($0)") }
    private var ids: [UUID] { items.map(\.id) }

    @Test func `down and up move one card`() {
        #expect(items.selection(movingFrom: ids[0], by: 1) == ids[1])
        #expect(items.selection(movingFrom: ids[2], by: -1) == ids[1])
    }

    @Test func `the selection stops at either end`() {
        #expect(items.selection(movingFrom: ids[2], by: 1) == ids[2])
        #expect(items.selection(movingFrom: ids[0], by: -1) == ids[0])
    }

    @Test func `with nothing selected, down starts at the top and up at the bottom`() {
        #expect(items.selection(movingFrom: nil, by: 1) == ids[0])
        #expect(items.selection(movingFrom: nil, by: -1) == ids[2])
    }

    @Test func `a selection no longer listed starts over`() {
        #expect(items.selection(movingFrom: UUID(), by: 1) == ids[0])
        #expect(items.selection(movingFrom: UUID(), by: -1) == ids[2])
    }

    @Test func `an empty list selects nothing`() {
        #expect([DownloadItem]().selection(movingFrom: nil, by: 1) == nil)
    }

    @Test func `moves follow display order, active first`() {
        var active = item(.downloading)
        active.addedAt = .distantPast
        let finished = item(.finished)
        let shown = DownloadManager.grouped([finished, active]).flatMap(\.items)
        #expect(shown.selection(movingFrom: nil, by: 1) == active.id)
        #expect(shown.selection(movingFrom: active.id, by: 1) == finished.id)
    }

    @Test func `removing hands the selection to the card below, or above at the end`() {
        #expect(items.selection(afterRemoving: ids[0]) == ids[1])
        #expect(items.selection(afterRemoving: ids[2]) == ids[1])
        #expect(Array(items.prefix(1)).selection(afterRemoving: ids[0]) == nil)
        #expect(items.selection(afterRemoving: UUID()) == nil)
    }
}

private func item(_ status: ItemStatus = .finished, path: String = "1") -> DownloadItem {
    var item = DownloadItem(url: URL(string: "https://vimeo.com/\(path)")!)
    item.status = status
    return item
}
