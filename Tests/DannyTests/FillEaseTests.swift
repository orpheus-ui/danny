@testable import Danny
import Foundation
import SwiftUI
import Testing

/// The bar's fill eases like `.easeOut` over 0.45 s, in at most 30 frames a second that
/// every bar shares, and draws nothing more once it rests.
struct FillEaseTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1000)

    private func easing(from: CGFloat, to: CGFloat) -> FillEase {
        var ease = FillEase()
        ease.move(to: from, at: start.addingTimeInterval(-5))
        ease.move(to: to, at: start)
        return ease
    }

    @Test func `a bar that appears takes its width without easing`() {
        var ease = FillEase()
        ease.move(to: 120, at: start)
        #expect(ease.width(at: start) == 120)
        #expect(ease.frames.allSatisfy { $0 < start })
    }

    @Test func `a new width eases on the ease-out curve`() {
        let ease = easing(from: 100, to: 200)
        #expect(ease.width(at: start) == 100)
        let midway = start.addingTimeInterval(FillEase.duration / 2)
        #expect(abs(ease.width(at: midway) - (100 + 100 * UnitCurve.easeOut.value(at: 0.5))) < 1e-6)
        #expect(ease.width(at: start.addingTimeInterval(FillEase.duration)) == 200)
        #expect(ease.width(at: start.addingTimeInterval(10)) == 200)
    }

    @Test func `frames fall on a shared 30 fps grid and stop at the end`() throws {
        let ease = easing(from: 0, to: 50)
        let frames = ease.frames
        let gaps = zip(frames, frames.dropFirst()).map { $1.timeIntervalSince($0) }
        #expect(gaps.allSatisfy { abs($0 - FillEase.frame) < 1e-6 })
        for frame in frames {
            let ticks = frame.timeIntervalSinceReferenceDate / FillEase.frame
            #expect(abs(ticks - ticks.rounded()) < 1e-6)
        }
        let first = try #require(frames.first), last = try #require(frames.last)
        #expect(first >= start && first < start.addingTimeInterval(FillEase.frame))
        #expect(last >= start.addingTimeInterval(FillEase.duration))
        #expect(frames.count <= Int(FillEase.duration * 30) + 2)
    }

    @Test func `a width that changes mid-ease starts from where the fill is`() {
        var ease = easing(from: 0, to: 100)
        let later = start.addingTimeInterval(0.2)
        let shown = ease.width(at: later)
        ease.move(to: 150, at: later)
        #expect(ease.width(at: later) == shown)
        #expect(ease.width(at: later.addingTimeInterval(FillEase.duration)) == 150)
    }
}
