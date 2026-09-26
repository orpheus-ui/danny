import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowConfiguratorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
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

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct LiquidWindowBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(D.glassTint), in: .rect)
        } else {
            VisualEffectBackground()
                .overlay(D.panelTint)
        }
    }
}

private struct DannyGlassModifier<S: Shape>: ViewModifier {
    let tint: Color
    let shape: S
    let interactive: Bool
    let fallback: Material

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = {
                let base = Glass.regular.tint(tint)
                return interactive ? base.interactive() : base
            }()
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(shape.fill(fallback))
                .background(shape.fill(tint))
                .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

extension View {
    @ViewBuilder
    func dannyGlass<S: Shape>(
        tint: Color = D.glassTint,
        in shape: S,
        interactive: Bool = false,
        fallback: Material = .ultraThinMaterial
    ) -> some View {
        modifier(DannyGlassModifier(tint: tint, shape: shape, interactive: interactive, fallback: fallback))
    }
}
