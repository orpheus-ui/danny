@testable import Danny
import Testing

/// The light's passes end with its bar, so a card that finished or went leaves nothing
/// waking behind it.
@MainActor
struct ProgressLightTests {
    @Test func `a bar that leaves the list stops its light and is released`() async throws {
        var view: ProgressLight.LightView? = ProgressLight.LightView()
        weak var light = view
        view?.update(trackWidth: 200, isRunning: true)
        try await Task.sleep(for: .milliseconds(50)) // the passes are under way

        if let view { ProgressLight.dismantleNSView(view, coordinator: ()) }
        view = nil
        for _ in 0 ..< 100 where light != nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(light == nil)
    }
}
