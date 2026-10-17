import AppKit
import Observation
import SwiftUI

@main
struct DannyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Danny") {
            MainWindow()
                .environment(model)
                .environment(model.settings)
                .environment(model.manager)
                .environment(model.sessions)
                .frame(minWidth: 620, minHeight: 430)
                .windowTranslucency()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 640, height: 500)
        .commands {
            DannyCommands(model: model)
        }

        Window("Danny Browser", id: "sniffer") {
            SnifferBrowserScreen()
                .environment(model)
                .environment(model.settings)
                .environment(model.manager)
        }
        .defaultSize(width: 980, height: 640)

        WindowGroup("Sign In", id: SignInView.windowID, for: SignInSite.self) { $site in
            if let site {
                SignInView(site: site)
                    .environment(model.sessions)
                    .environment(model.manager)
                    .frame(minWidth: 460, minHeight: 560)
                    .windowTranslucency()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 680)
        // A sign-in is a moment, not a place: it isn't reopened on the next launch.
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(model.settings)
                .environment(model.manager)
                .environment(model.sessions)
                .frame(width: 480, height: 560)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let manager: DownloadManager
    let watcher: ClipboardWatcher
    let sessions = SiteSessions()
    let system: SystemStatus
    let menuBar = MenuBarState()
    private(set) var menuBarItem: MenuBarItem?
    /// Something the main window should do once it is in front; it clears it.
    var windowRequest: WindowRequest?

    enum WindowRequest: Equatable {
        case focus(UUID)
        case browserCapture
        case settings
    }

    var snifferStartURL: URL?

    init() {
        let settings = AppSettings()
        self.settings = settings
        manager = DownloadManager(settings: settings)
        watcher = ClipboardWatcher(settings: settings, manager: manager)
        manager.sessions = sessions
        system = SystemStatus(manager: manager, menuBar: menuBar)
        Task { [manager] in await manager.checkEngine() }
        menuBarItem = MenuBarItem(
            settings: settings, manager: manager, state: menuBar,
            actions: MenuBarActions(
                openDanny: { [weak self] in self?.showMainWindow() },
                show: { [weak self] id in self?.showMainWindow(request: .focus(id)) },
                browserCapture: { [weak self] in self?.showMainWindow(request: .browserCapture) },
                openSettings: { [weak self] in self?.showMainWindow(request: .settings) },
            ),
        )
    }

    /// Brings the main window forward, opening it when it was closed. Opening the running
    /// app again is what clicking its Dock icon does.
    func showMainWindow(request: WindowRequest? = nil) {
        windowRequest = request
        NSApp.activate()
        NSApp.windows.first { $0.title == "Danny" }?.makeKeyAndOrderFront(nil)
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Adds the link on the clipboard; false when there isn't one.
    @discardableResult
    func pasteDownload() -> Bool {
        guard let url = LinkIntake.pasteboardLink() else { return false }
        manager.add(url: url)
        return true
    }
}

struct DannyCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        SidebarCommands()

        CommandMenu("Download") {
            Button("Paste and Download") {
                model.pasteDownload()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Enter URL…") {
                model.manager.pendingManualAdd = true
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Browser Capture…") {
                openWindow(id: "sniffer")
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button(model.manager.canPauseAll || !model.manager.canResumeAll ? "Pause All" : "Resume All") {
                if model.manager.canPauseAll { model.manager.pauseAll() } else { model.manager.resumeAll() }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(!model.manager.canPauseAll && !model.manager.canResumeAll)
        }
    }
}
