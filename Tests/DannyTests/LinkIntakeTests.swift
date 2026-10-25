import AppKit
@testable import Danny
import Foundation
import Testing

struct LinkIntakeTests {
    let scratch = TestScratch()

    @Test func `web link is taken as is`() throws {
        let url = try #require(URL(string: "https://www.youtube.com/watch?v=abc"))
        #expect(LinkIntake.link(from: url) == url)
    }

    @Test func `other schemes are refused`() throws {
        #expect(try LinkIntake.link(from: #require(URL(string: "mailto:someone@example.com"))) == nil)
        #expect(try LinkIntake.link(from: #require(URL(string: "ftp://example.com/clip.mp4"))) == nil)
    }

    @Test func `webloc file gives its link`() throws {
        let folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Clip.webloc")
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["URL": "https://vimeo.com/123"], format: .xml, options: 0,
        )
        try plist.write(to: file)
        #expect(LinkIntake.link(from: file) == URL(string: "https://vimeo.com/123"))
    }

    @Test func `other files and broken weblocs are refused`() throws {
        let folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let video = folder.appendingPathComponent("Clip.mp4")
        try Data("not a link".utf8).write(to: video)
        let broken = folder.appendingPathComponent("Broken.webloc")
        try Data("not a plist".utf8).write(to: broken)
        #expect(LinkIntake.link(from: video) == nil)
        #expect(LinkIntake.link(from: broken) == nil)
        #expect(LinkIntake.link(from: folder.appendingPathComponent("Missing.webloc")) == nil)
        let huge = folder.appendingPathComponent("Huge.webloc")
        let padded = try PropertyListSerialization.data(
            fromPropertyList: ["URL": "https://vimeo.com/123", "Pad": String(repeating: "x", count: 70000)],
            format: .xml, options: 0,
        )
        try padded.write(to: huge)
        #expect(LinkIntake.link(from: huge) == nil)
    }

    @MainActor @Test func `pasteboard URL comes before its text`() throws {
        let pasteboard = NSPasteboard(name: .init("DannyTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        try pasteboard.writeObjects([#require(URL(string: "https://vimeo.com/9")) as NSURL])
        #expect(LinkIntake.pasteboardLink(pasteboard) == URL(string: "https://vimeo.com/9"))

        pasteboard.clearContents()
        pasteboard.setString("see https://youtu.be/xyz", forType: .string)
        #expect(LinkIntake.pasteboardLink(pasteboard) == URL(string: "https://youtu.be/xyz"))

        pasteboard.clearContents()
        pasteboard.setString("no link", forType: .string)
        #expect(LinkIntake.pasteboardLink(pasteboard) == nil)
    }
}
