import AppKit
import Observation
import SwiftUI

/// The menu-bar item: the mark with the percentage beside it, and the panel of
/// downloads and quick settings, on glass and without a popover's arrow. It is an
/// `NSStatusItem` rather than a `MenuBarExtra` so it can follow the bar's appearance and
/// highlight itself. It redraws on a whole-percent change, an appearance change, and the
/// panel opening or closing; it never polls.
@MainActor
final class MenuBarItem: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let state: MenuBarState
    private let manager: DownloadManager
    private let actions: MenuBarActions
    private var item: NSStatusItem?
    private var panel: NSPanel?
    private var content: NSHostingController<MenuBarContent>?
    private var anchor = NSRect.zero
    private var sizeObservation: NSKeyValueObservation?
    private var observations: [NSKeyValueObservation] = []

    init(settings: AppSettings, manager: DownloadManager, state: MenuBarState, actions: MenuBarActions) {
        self.settings = settings
        self.state = state
        self.manager = manager
        self.actions = actions
        super.init()
        observeVisibility()
        observeIcon()
    }

    /// Observation fires once per registration, so each change registers again.
    private func observeVisibility() {
        let shown = withObservationTracking {
            MenuBarVisibility.isShown(setting: settings.menuBarItem)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeVisibility() }
        }
        setShown(shown)
    }

    private func observeIcon() {
        _ = withObservationTracking { state.icon } onChange: { [weak self] in
            Task { @MainActor in self?.observeIcon() }
        }
        refresh()
    }

    private func setShown(_ shown: Bool) {
        guard shown != (item != nil) else { return }
        if shown {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(toggle)
            self.item = item
            observations = [
                item.button!.observe(\.effectiveAppearance) { [weak self] _, _ in
                    Task { @MainActor in self?.refresh() }
                },
                // Dragging the item out of the menu bar turns the setting off.
                item.observe(\.isVisible) { [weak self] item, _ in
                    let hidden = !item.isVisible
                    Task { @MainActor in
                        if hidden, !MenuBarVisibility.isShown(setting: false) { self?.settings.menuBarItem = false }
                    }
                },
            ]
            refresh()
        } else {
            panel?.close()
            observations = []
            NSStatusBar.system.removeStatusItem(item!)
            item = nil
        }
    }

    private func refresh() {
        guard let button = item?.button else { return }
        let icon = state.icon
        let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let style = MenuBarStyle(isDark: isDark, menuOpen: panel?.isVisible == true)
        button.image = MenuBarMark.image(icon, style: style, label: isDark ? .white : .black)
        let percent = icon?.percent
        button.title = percent.map { "\($0)%" } ?? ""
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.imagePosition = percent == nil ? .imageOnly : .imageLeft
    }

    @objc private func toggle() {
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        guard let button = item?.button, let window = button.window else { return }
        let content = NSHostingController(rootView: MenuBarContent(
            model: MenuBarPopoverModel(manager: manager), manager: manager, settings: settings, actions: actions,
        ))
        content.sizingOptions = .preferredContentSize
        let glass = NSGlassEffectView()
        glass.cornerRadius = 18
        glass.contentView = content.view
        let panel = MenuBarPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        panel.contentView = glass
        panel.delegate = self
        self.panel = panel
        self.content = content
        // The item's right edge, just under the menu bar; the panel grows downward with its content.
        anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        resize(to: NSSize(width: 340, height: max(content.view.fittingSize.height, 160)))
        sizeObservation = content.observe(\.preferredContentSize, options: .new) { [weak self] controller, _ in
            Task { @MainActor in self?.resize(to: controller.preferredContentSize) }
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        item?.button?.highlight(true)
        refresh()
    }

    private func resize(to size: NSSize) {
        guard let panel, size.width > 0, let screen = item?.button?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = min(max(anchor.maxX - size.width, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrame(
            NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height),
            display: true,
        )
    }

    /// Clicking elsewhere closes it, as a menu does.
    func windowDidResignKey(_: Notification) {
        panel?.close()
    }

    func windowWillClose(_: Notification) {
        item?.button?.highlight(false)
        sizeObservation = nil
        content = nil
        panel = nil
        refresh()
    }
}

/// A borderless panel that can take the keyboard, so the link field works; Escape closes it.
private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool,
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        isReleasedWhenClosed = false
    }

    override func cancelOperation(_: Any?) { close() }
}
