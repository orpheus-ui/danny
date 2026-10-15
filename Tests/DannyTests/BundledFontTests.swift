import CoreText
@testable import Danny
import Foundation
import Testing

struct BundledFontTests {
    /// CoreText falls back to a system font silently when a name isn't registered, so
    /// check the font that comes back is the bundled one.
    @Test
    func `title font is the bundled Space Grotesk`() {
        let font = D.spaceGrotesk(size: 16)
        #expect(CTFontCopyPostScriptName(font) as String == "SpaceGrotesk-Medium")
        // And it is the app's copy, not a same-named font installed on the system.
        let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL
        #expect(url?.path.hasSuffix("Contents/Resources/Fonts/SpaceGrotesk-Medium.otf") == true)
    }
}
