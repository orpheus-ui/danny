import CoreGraphics
@testable import Danny
import Testing

struct PillStyleTests {
    /// Figma: card pills are 18 pt icons with 6 pt padding, bar pills 24 pt with 8 pt.
    @Test(arguments: [(PillStyle.card, CGFloat(30)), (.bar, CGFloat(40))])
    func `pills are circles of the Figma diameter`(style: PillStyle, diameter: CGFloat) {
        #expect(style.diameter == diameter)
    }
}
