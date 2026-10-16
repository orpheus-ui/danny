import SwiftUI

/// The card's quality picker for "Ask each time": one chip per option, best first.
/// The first chip is the default and shows when it starts on its own; the manager
/// keeps that deadline, so it starts even while the card is scrolled away.
struct QualityChips: View {
    let options: [QualityOption]
    let deadline: Date?
    let onChoose: (QualityChoice) -> Void

    @State private var now = Date()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    chip(option, isDefault: index == 0)
                }
            }
        }
        .frame(height: 24)
        .task {
            // Once a second, only while the card is on screen.
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var secondsLeft: Int? {
        deadline.map { max(0, Int($0.timeIntervalSince(now).rounded(.up))) }
    }

    private func chip(_ option: QualityOption, isDefault: Bool) -> some View {
        Button { onChoose(option.choice) } label: {
            HStack(spacing: 5) {
                Text(option.label).font(.system(size: 12, weight: .bold))
                if let size = Format.size(option.bytes) {
                    Text(size)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(isDefault ? 0.75 : 0.55))
                }
                if isDefault, let secondsLeft {
                    Text("\(secondsLeft)s")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(Capsule().fill(.black.opacity(0.25)))
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(isDefault ? AnyShapeStyle(D.progressFill) : AnyShapeStyle(.black.opacity(0.45))))
            .overlay { Capsule().strokeBorder(.white.opacity(isDefault ? 0.25 : 0.12)) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isDefault ? "Starts on its own when the countdown ends" : "Download in \(option.label)")
        .animation(.smooth(duration: 0.3), value: secondsLeft)
    }
}
