import AppKit
import SwiftUI

/// The light that passes through a progress bar's dots. Core Animation moves it in
/// the render server, so a pass costs the app nothing: it wakes once per pass to
/// start the animation, and between passes nothing is attached at all.
///
/// The light layer spans the whole track and the view clips it to the fill, so it
/// moves at the same speed through every bar; passes start on the shared clock
/// (`ProgressSweep`), so they cross the list together.
struct ProgressLight: NSViewRepresentable {
    let trackWidth: CGFloat
    let isRunning: Bool

    func makeNSView(context _: Context) -> LightView { LightView() }

    func updateNSView(_ view: LightView, context _: Context) {
        view.update(trackWidth: trackWidth, isRunning: isRunning)
    }

    /// A bar that leaves the list stops its passes: a card that finishes moves to
    /// another section as a new view, and the old one's pass task would keep it alive,
    /// waking every period for as long as Danny runs.
    static func dismantleNSView(_ view: LightView, coordinator _: ()) {
        view.stop()
    }

    final class LightView: NSView {
        private let glow = CAGradientLayer()
        private let sparkle = CAGradientLayer()
        private let sparkleHost = CALayer()
        private let dots = CALayer()
        private var trackWidth: CGFloat = 0
        private var passes: Task<Void, Never>?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.masksToBounds = true
            // A soft band over everything, and a brighter one only where the dots are.
            configure(glow, alpha: 0.12)
            configure(sparkle, alpha: 0.6)
            sparkleHost.addSublayer(sparkle)
            sparkleHost.mask = dots
            layer?.addSublayer(glow)
            layer?.addSublayer(sparkleHost)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

        override var isFlipped: Bool { true }
        override func hitTest(_: NSPoint) -> NSView? { nil }

        private static let bandWidth: CGFloat = 90

        private func configure(_ band: CAGradientLayer, alpha: CGFloat) {
            let white = NSColor.white
            band.colors = [white.withAlphaComponent(0), white.withAlphaComponent(alpha), white.withAlphaComponent(0)]
                .map(\.cgColor)
            band.startPoint = CGPoint(x: 0, y: 0.5)
            band.endPoint = CGPoint(x: 1, y: 0.5)
            band.position.x = -10000 // off the bar between passes
        }

        func update(trackWidth: CGFloat, isRunning: Bool) {
            if trackWidth != self.trackWidth || dots.contents == nil {
                self.trackWidth = trackWidth
                layout(height: D.Size.progressHeight)
            }
            if isRunning, passes == nil {
                passes = Task { [weak self] in await self?.runPasses() }
            } else if !isRunning {
                stop()
            }
        }

        func stop() {
            passes?.cancel()
            passes = nil
            [glow, sparkle].forEach { $0.removeAllAnimations() }
        }

        private func layout(height: CGFloat) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let band = CGRect(x: 0, y: 0, width: Self.bandWidth, height: height)
            glow.bounds = band
            sparkle.bounds = band
            glow.position.y = height / 2
            sparkle.position.y = height / 2
            let track = CGRect(x: 0, y: 0, width: trackWidth, height: height)
            sparkleHost.frame = track
            dots.frame = track
            dots.contents = Self.dotMask(size: track.size, scale: window?.backingScaleFactor ?? 2)
            CATransaction.commit()
        }

        private func runPasses() async {
            while !Task.isCancelled {
                let wait = ProgressSweep.untilNextPass(at: Date.timeIntervalSinceReferenceDate)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                pass()
                try? await Task.sleep(for: .seconds(ProgressSweep.duration + 0.1))
            }
        }

        private func pass() {
            let elapsed = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ProgressSweep.period)
            for band in [glow, sparkle] {
                let move = CABasicAnimation(keyPath: "position.x")
                move.fromValue = -Self.bandWidth
                move.toValue = trackWidth + Self.bandWidth
                move.duration = ProgressSweep.duration
                move.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0, 0.25, 1)
                move.beginTime = band.convertTime(CACurrentMediaTime(), from: nil) - min(elapsed, 0.2)
                band.add(move, forKey: "pass")
            }
        }

        /// The dots' positions, matching ProgressBar.metal's grid: staggered 3 pt cells.
        private static func dotMask(size: CGSize, scale: CGFloat) -> CGImage? {
            let width = Int(size.width * scale), height = Int(size.height * scale)
            guard width > 0, height > 0,
                  let context = CGContext(
                      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue,
                  )
            else { return nil }
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            let cell: CGFloat = 3, radius: CGFloat = 1
            var row: CGFloat = 0
            while row * cell < size.height {
                let shift = row.truncatingRemainder(dividingBy: 2) * cell / 2
                var column: CGFloat = 0
                while column * cell - shift < size.width {
                    let center = CGPoint(x: column * cell + cell / 2 - shift, y: row * cell + cell / 2)
                    context.fillEllipse(in: CGRect(
                        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2,
                    ))
                    column += 1
                }
                row += 1
            }
            return context.makeImage()
        }
    }
}
