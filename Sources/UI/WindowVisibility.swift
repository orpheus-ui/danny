import AppKit
import SwiftUI

extension EnvironmentValues {
    /// False while the window is hidden, minimized or fully covered. Anything that
    /// animates stops then (ADR-008).
    @Entry var windowIsVisible = true
}

extension View {
    /// Publishes `windowIsVisible` for this view's window to everything below it.
    func trackingWindowVisibility() -> some View {
        modifier(WindowVisibilityModifier())
    }
}

private struct WindowVisibilityModifier: ViewModifier {
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .background(WindowVisibilityReader { isVisible = $0 })
            .environment(\.windowIsVisible, isVisible)
    }
}

private struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context _: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ReaderView, context _: Context) {
        view.onChange = onChange
    }

    final class ReaderView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            // A window isn't on screen yet when this view joins it, so start from
            // "visible" and follow what changes: occlusion, hiding, minimizing.
            let names: [(Notification.Name, AnyObject?)] = [
                (NSWindow.didChangeOcclusionStateNotification, window),
                (NSWindow.didMiniaturizeNotification, window),
                (NSWindow.didDeminiaturizeNotification, window),
                (NSApplication.didHideNotification, NSApp),
                (NSApplication.didUnhideNotification, NSApp),
            ]
            observers = names.map { name, object in
                NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            onChange?(true)
        }

        private func report() {
            guard let window else { return }
            let visible = !NSApp.isHidden && !window.isMiniaturized && window.occlusionState.contains(.visible)
            onChange?(visible)
        }
    }
}
