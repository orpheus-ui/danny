import SwiftUI

/// A limit in MB/s, typed or stepped, kept inside what a mode can be set to.
struct SpeedLimitField: View {
    let title: String
    @Binding var bytesPerSecond: Int

    private var megabytes: Binding<Double> {
        Binding(
            get: { Double(bytesPerSecond) / 1_000_000 },
            // Clamped as a Double: a pasted 1e13 would trap in Int().
            set: { guard $0.isFinite else { return }
                bytesPerSecond = Int(min(
                    max($0 * 1_000_000, Double(SpeedMode.limitRange.lowerBound)),
                    Double(SpeedMode.limitRange.upperBound),
                ).rounded())
            },
        )
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: megabytes, format: .number.precision(.fractionLength(0 ... 2)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Text("MB/s").foregroundStyle(.secondary)
                Stepper(title, value: megabytes, in: 0.5 ... 100, step: 0.5)
                    .labelsHidden()
            }
        }
    }
}
