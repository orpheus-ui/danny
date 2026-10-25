import CoreText
import SwiftUI

/// Design tokens. Values come from the Figma main window (node `519:189`); values
/// Figma doesn't define yet say so. Views use these instead of literals.
enum D {
    // MARK: Colors

    static let ink = rgb(26, 22, 33)
    /// Window background: 75% over a backdrop blur.
    static let windowTint = rgb(17, 15, 22).opacity(0.75)
    static let windowStroke = Color.white.opacity(0.24)

    static let accent = rgb(118, 97, 255)
    static let accentDeep = rgb(86, 35, 255)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.5)

    /// Card outline (2 pt).
    static let cardStroke = Color.black.opacity(0.8)
    /// Behind the thumbnail, and where there is none.
    static let cardBackdrop = Color.black
    /// The empty list's outline card. Not in Figma: designed in M1.
    static let emptyCardFill = ink.opacity(0.4)

    /// Round icon buttons on cards: dots, trash.
    static let pillFill = ink.opacity(0.8)
    static let pillStroke = Color.white.opacity(0.12)
    /// Round icon buttons in the bottom bar: sort, add.
    static let barButtonFill = ink.opacity(0.2)

    static let progressTrack = rgb(47, 47, 47).opacity(0.5)
    /// 1 pt light edge under the track, and the shadow inside its top edge.
    static let progressRim = Color.white.opacity(0.1)
    static let progressInnerShadow = Color.black.opacity(0.2)
    static let progressLabel = Color.white.opacity(0.9)
    /// The fill's opacity while it shows no progress yet (Fetching) or stopped progress (Paused).
    /// Not in Figma: designed in M1 for those states.
    static let dimmedFill = 0.45

    // MARK: Gradients

    /// Figma: 84.5°, so left to right with a slight rise.
    static let titleGradient = LinearGradient(
        colors: [rgb(246, 240, 250), rgb(168, 155, 255)],
        startPoint: UnitPoint(x: 0, y: 0.55), endPoint: UnitPoint(x: 1, y: 0.45),
    )

    /// Progress fill and its halftone dots. Figma's gradients run to 177% of the
    /// fill; these are their colors at 100%.
    static let progressStart = accentDeep.opacity(0.6)
    static let progressEnd = rgb(104, 70, 255).opacity(0.6)
    static let progressDotStart = rgb(145, 112, 255)
    static let progressDotEnd = rgb(155, 133, 254)

    /// Done: the dots are the fill's own colors, so they show where they stack.
    static let doneStart = rgb(16, 215, 76).opacity(0.6)
    static let doneEnd = rgb(97, 255, 147).opacity(0.6)

    /// Not in Figma: the Failed state, designed in M1 in the progress bar's style.
    static let failedStart = Color(red: 0.85, green: 0.25, blue: 0.30).opacity(0.75)
    static let failedEnd = Color(red: 0.95, green: 0.42, blue: 0.45).opacity(0.75)

    static let progressFill = LinearGradient(horizontalColors: [progressStart, progressEnd])
    static let doneFill = LinearGradient(horizontalColors: [doneStart, doneEnd])
    static let failedFill = LinearGradient(horizontalColors: [failedStart, failedEnd])

    /// Over the thumbnail, so the title reads on any image.
    static let cardScrim = LinearGradient(
        horizontalStops: [(Color.black, 0.0), (Color.black.opacity(0.5), 1.0)],
    )

    /// Matches Figma's bottom bar image (`519:283`): ink, clear at the top to opaque at
    /// the bottom, over the bar's own height.
    static let bottomFade = LinearGradient(
        verticalStops: [(ink.opacity(0), 0.0), (ink, 1.0)],
    )

    // MARK: Shape and size

    enum Radius {
        static let window: CGFloat = 24
        static let card: CGFloat = 12
    }

    enum Stroke {
        static let window: CGFloat = 1.5
        static let card: CGFloat = 2
    }

    enum Size {
        static let cardHeight: CGFloat = 105
        static let progressHeight: CGFloat = 20
        static let cardIcon: CGFloat = 18
        /// The dot between the meta line's parts.
        static let metaDot: CGFloat = 4
        static let cardIconPadding: CGFloat = 6
        static let barIcon: CGFloat = 24
        static let barIconPadding: CGFloat = 8
        /// The floating bottom bar, its 8 pt margins included.
        static let bottomBar: CGFloat = 56
        static let toolbarIcon: CGFloat = 20
        /// The title bar's center line, from the window's top: Figma centers the title
        /// and toolbar icons here, and the traffic lights are moved onto it.
        static let titleLine: CGFloat = 22
    }

    enum Spacing {
        static let list: CGFloat = 12
        /// Cards' distance from the window's sides (Figma: 16; 8 since M1.5 for wider cards).
        static let listInset: CGFloat = 8
        /// Space between the title bar and the first card.
        static let listTop: CGFloat = 12
        static let cardPadding: CGFloat = 10
        static let cardActions: CGFloat = 10
        static let cardTitleMeta: CGFloat = 10
        /// Between the meta line's parts and its dots: Figma's 2 pt gap plus the dot's 8 pt frame.
        static let cardMeta: CGFloat = 4
        static let toolbar: CGFloat = 8
        /// Section headers: not in Figma. Close to their own cards, in line with the
        /// cards' rounded corners.
        static let sectionHeader: CGFloat = 8
        static let sectionHeaderInset: CGFloat = 6
    }

    // MARK: Type

    enum Font {
        /// Space Grotesk Medium (bundled, OFL) with the stylistic sets Figma turns
        /// on: `salt` and `ss01`–`ss05`.
        static let appTitle = SwiftUI.Font(spaceGrotesk(size: 16))
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .bold)
        /// SF Pro at 80% width.
        static let cardMeta = SwiftUI.Font.system(size: 12, weight: .medium).width(.condensed)
        static let progressLabel = SwiftUI.Font.system(size: 14, weight: .bold)
        /// Section headers: not in Figma. The card meta's face, one weight heavier.
        static let sectionHeader = SwiftUI.Font.system(size: 12, weight: .semibold).width(.condensed)
    }

    static func spaceGrotesk(size: CGFloat) -> CTFont {
        let features = ["salt", "ss01", "ss02", "ss03", "ss04", "ss05"].map {
            [kCTFontOpenTypeFeatureTag: $0, kCTFontOpenTypeFeatureValue: 1] as CFDictionary
        }
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "SpaceGrotesk-Medium",
            kCTFontFeatureSettingsAttribute: features,
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}

extension LinearGradient {
    init(horizontalColors colors: [Color]) {
        self.init(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    init(horizontalStops stops: [(Color, Double)]) {
        self.init(stops: stops, start: .leading, end: .trailing)
    }

    init(verticalStops stops: [(Color, Double)]) {
        self.init(stops: stops, start: .top, end: .bottom)
    }

    private init(stops: [(Color, Double)], start: UnitPoint, end: UnitPoint) {
        self.init(
            gradient: Gradient(stops: stops.map { Gradient.Stop(color: $0.0, location: $0.1) }),
            startPoint: start, endPoint: end,
        )
    }
}
