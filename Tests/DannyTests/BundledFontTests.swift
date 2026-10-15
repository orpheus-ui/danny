import CoreText
@testable import Danny
import Testing

struct BundledFontTests {
    /// CoreText falls back to a system font silently when a name isn't registered, so
    /// check the font that comes back is the bundled one.
    @Test
    func `title font is the bundled Space Grotesk`() {
        let font = D.spaceGrotesk(size: 16)
        #expect(CTFontCopyPostScriptName(font) as String == "SpaceGrotesk-Medium")
    }
}
