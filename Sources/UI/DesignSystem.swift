import SwiftUI

enum D {
    static let ink = Color(red: 26 / 255, green: 22 / 255, blue: 33 / 255)
    static let glassTint = Color(red: 30 / 255, green: 26 / 255, blue: 38 / 255).opacity(0.35)
    static let windowStroke = Color.white.opacity(0.22)

    static let accent = Color(red: 118 / 255, green: 98 / 255, blue: 1)
    static let accentDeep = Color(red: 86 / 255, green: 35 / 255, blue: 1)

    static let titleGradient = LinearGradient(
        colors: [
            Color(red: 246 / 255, green: 240 / 255, blue: 250 / 255),
            Color(red: 168 / 255, green: 155 / 255, blue: 1),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing,
    )

    static let progressFill = LinearGradient(
        colors: [
            Color(red: 0.40, green: 0.30, blue: 1),
            Color(red: 0.58, green: 0.50, blue: 1),
        ],
        startPoint: .leading, endPoint: .trailing,
    )

    static let doneFill = LinearGradient(
        colors: [
            Color(red: 22 / 255, green: 166 / 255, blue: 99 / 255),
            Color(red: 22 / 255, green: 219 / 255, blue: 160 / 255),
        ],
        startPoint: .leading, endPoint: .trailing,
    )

    static let failedFill = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.25, blue: 0.30),
            Color(red: 0.95, green: 0.42, blue: 0.45),
        ],
        startPoint: .leading, endPoint: .trailing,
    )

    static let cardShade = LinearGradient(
        horizontalStops: [(Color.black.opacity(0.92), 0.0), (Color.black.opacity(0.45), 1.0)],
    )

    static let titlebarFade = LinearGradient(
        verticalStops: [
            (Color.black.opacity(0.55), 0.0),
            (Color.black.opacity(0.25), 0.55),
            (Color.black.opacity(0), 1.0),
        ],
    )

    static let bottomFade = LinearGradient(
        verticalStops: [(Color.black.opacity(0), 0.0), (Color.black.opacity(0.55), 1.0)],
    )
}

extension LinearGradient {
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
