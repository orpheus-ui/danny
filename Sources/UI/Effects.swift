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
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.hasShadow = true
    }
}

struct LiquidWindowBackground: View {
    var body: some View {
        Color.clear
            .glassEffect(.regular.tint(D.glassTint), in: .rect)
    }
}

extension View {
    func dannyGlass(
        tint: Color = D.glassTint,
        in shape: some Shape,
        interactive: Bool = false,
    ) -> some View {
        let glass = Glass.regular.tint(tint)
        return glassEffect(interactive ? glass.interactive() : glass, in: shape)
    }
}
