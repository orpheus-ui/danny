import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView { WindowConfiguratorView() }
    func updateNSView(_: NSView, context _: Context) {}
}

extension View {
    func windowTranslucency() -> some View {
        background(WindowConfigurator())
    }
}

private final class WindowConfiguratorView: NSView {
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.hasShadow = true

        // AppKit lays the titlebar out again on these, which puts the buttons back.
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
            NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
            NSWindow.didExitFullScreenNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.alignWindowButtons() }
            }
        }
        DispatchQueue.main.async { [weak self] in self?.alignWindowButtons() }
    }

    /// Centers the traffic lights on the title bar's line (`D.Size.titleLine` from the
    /// top), level with the title and toolbar icons, instead of AppKit's spot above it.
    /// The titlebar container grows to fit, so the buttons stay clickable.
    private func alignWindowButtons() {
        guard let window, !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let titlebar = close.superview, let container = titlebar.superview,
              let frameView = container.superview
        else { return }

        let height = D.Size.titleLine * 2
        container.frame = NSRect(
            x: 0, y: frameView.bounds.height - height,
            width: frameView.bounds.width, height: height,
        )
        titlebar.frame = container.bounds

        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type) else { continue }
            button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: (height - button.frame.height) / 2))
        }
    }
}

/// Figma's window: 75% ink over a backdrop blur. The blur is kept in its active look,
/// so the window keeps its color when it isn't focused; glass goes grey instead.
struct WindowBackground: View {
    var body: some View {
        BackdropBlur()
            .overlay(D.windowTint)
    }
}

private struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}

extension View {
    func dannyGlass(
        tint: Color = D.windowTint,
        in shape: some Shape,
        interactive: Bool = false,
    ) -> some View {
        let glass = Glass.regular.tint(tint)
        return glassEffect(interactive ? glass.interactive() : glass, in: shape)
    }
}
