import AppKit

/// The menu-bar mark. Idle it is a plain template image, tinted by the menu bar.
/// While downloading it can't be one, since the fill is purple: the mark is drawn in the
/// label colour at half strength, with the same mark filled over its bottom `percent`.
enum MenuBarMark {
    static let size = NSSize(width: 18, height: 18)
    /// Room after the mark, so the percentage doesn't touch it.
    static let gap: CGFloat = 4

    /// Nil `icon` is idle. `label` is the menu bar's text colour for its appearance.
    static func image(
        _ icon: MenuBarIcon?,
        style: MenuBarStyle = MenuBarStyle(isDark: true, menuOpen: false),
        label: NSColor = .white,
    ) -> NSImage {
        let mark = NSImage(named: "menu-bar-mark")
        guard let icon else {
            let idle = NSImage(size: size, flipped: false) { rect in
                mark?.draw(in: rect)
                return true
            }
            idle.isTemplate = true
            idle.accessibilityDescription = "Danny"
            return idle
        }
        let fill = fillColor(style.fill)
        let hasText = icon.percent != nil
        let image = NSImage(
            size: NSSize(width: size.width + (hasText ? gap : 0), height: size.height),
            flipped: false,
        ) { _ in
            let rect = NSRect(origin: .zero, size: size)
            draw(mark, in: rect, color: label.withAlphaComponent(MenuBarStyle.baseAlpha))
            let filled = MenuBarIcon.fillRect(percent: icon.percent, in: rect)
            guard !filled.isEmpty else { return true }
            NSGraphicsContext.current?.saveGraphicsState()
            filled.clip()
            draw(mark, in: rect, color: fill ?? label)
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Danny, " + (icon.percent.map { "\($0) percent" } ?? "starting")
        return image
    }

    /// Nil is the label colour.
    static func fillColor(_ fill: MenuBarStyle.Fill) -> NSColor? {
        switch fill {
        case .label: nil
        case .brandLight: NSColor(D.accent)
        case .brandDeep: NSColor(D.accentDeep)
        }
    }

    /// The mark's shape filled with `color`.
    private static func draw(_ mark: NSImage?, in rect: NSRect, color: NSColor) {
        mark?.draw(in: rect)
        color.setFill()
        rect.fill(using: .sourceAtop)
    }
}
