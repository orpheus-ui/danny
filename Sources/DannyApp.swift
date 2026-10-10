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

        Settings {
            SettingsView()
                .environment(model.settings)
                .environment(model.manager)
                .frame(width: 440, height: 300)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let manager: DownloadManager
    let watcher: ClipboardWatcher
    var snifferStartURL: URL?

    init() {
        let settings = AppSettings()
        self.settings = settings
        manager = DownloadManager(settings: settings)
        watcher = ClipboardWatcher(settings: settings, manager: manager)
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
                if let string = NSPasteboard.general.string(forType: .string),
                   let url = ClipboardWatcher.firstURL(in: string)
                {
                    _ = model.manager.add(url: url)
                }
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
        }
    }
}
