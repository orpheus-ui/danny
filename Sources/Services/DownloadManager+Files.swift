import AppKit

/// Opening and revealing an item's file and page: the views call these, never NSWorkspace.
extension DownloadManager {
    func revealInFinder(id: UUID) {
        guard let path = items.first(where: { $0.id == id })?.filePath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }

    /// Opens a finished item's file in its default app.
    func open(id: UUID) {
        guard let url = items.first(where: { $0.id == id })?.fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the page the item was downloaded from in the browser.
    func openOriginalPage(id: UUID) {
        guard let url = items.first(where: { $0.id == id })?.sourceURL else { return }
        NSWorkspace.shared.open(url)
    }
}
