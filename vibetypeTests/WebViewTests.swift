import JavaScriptCore
import Testing
import UIKit
@testable import vibetype

struct HostMatchesTests {
    @Test(arguments: ["vibetype.app", "www.vibetype.app", "a.b.vibetype.app", "VibeType.App", "WWW.VIBETYPE.APP"])
    func acceptsOriginAndSubdomains(host: String) {
        #expect(hostMatches(host, origin: "vibetype.app"))
    }

    @Test(arguments: ["vibetype.app.example.com", "notvibetype.app", "vibetype.ap", "app", "example.com", ""])
    func rejectsLookAlikeHosts(host: String) {
        #expect(!hostMatches(host, origin: "vibetype.app"))
    }

    @Test func comparesOriginCaseInsensitively() {
        #expect(hostMatches("www.vibetype.app", origin: "VIBETYPE.app"))
    }
}

struct PosterJpegTests {
    private func decodedSize(_ jpeg: Data?) throws -> CGSize {
        let data = try #require(jpeg)
        return try #require(UIImage(data: data)).size
    }

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func downscalesLongEdgeTo2048() throws {
        #expect(try decodedSize(posterJpeg(image(width: 1000, height: 4000))) == CGSize(width: 512, height: 2048))
    }

    @Test func keepsSmallImagesAsTheyAre() throws {
        #expect(try decodedSize(posterJpeg(image(width: 800, height: 600))) == CGSize(width: 800, height: 600))
    }
}

struct TakeSharedPosterTests {
    private func writePoster(modified: Date) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try Data([1, 2, 3]).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func returnsAndRemovesFreshPoster() throws {
        let url = try writePoster(modified: Date())
        #expect(takeSharedPoster(at: url) == Data([1, 2, 3]))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func discardsPosterOlderThanADay() throws {
        let url = try writePoster(modified: Date(timeIntervalSinceNow: -25 * 60 * 60))
        #expect(takeSharedPoster(at: url) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func returnsNothingWithoutPoster() {
        #expect(takeSharedPoster(at: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) == nil)
    }
}

struct GeolocationScriptTests {
    // Runs the injected script against stand-ins for the WebKit globals it uses, with timers fired by hand.
    private func run(_ test: String) throws -> JSContext {
        let context = try #require(JSContext())
        context.evaluateScript("""
        var posted = [], listeners = {}, timers = [], result
        var window = {
          addEventListener: (name, listener) => { listeners[name] = listener },
          webkit: { messageHandlers: { geolocation: { postMessage: (body) => posted.push(body) } } },
        }
        var setTimeout = (callback) => timers.push(callback)
        var clearTimeout = () => {}
        var reply = (detail) => listeners['geolocation-result']({ detail: JSON.stringify(detail) })
        function Geolocation() {}
        """)
        context.evaluateScript(geolocationScript.source)
        context.evaluateScript(test)
        #expect(context.exception == nil)
        return context
    }

    @Test func passesThePositionOn() throws {
        let context = try run("""
        new Geolocation().getCurrentPosition((position) => { result = position.coords.latitude })
        reply({ id: posted[0].id, type: 'start' })
        reply({ id: posted[0].id, position: { coords: { latitude: 51.3 } }, type: 'position' })
        """)
        #expect(context.evaluateScript("posted[0].type").toString() == "get")
        #expect(context.evaluateScript("result").toDouble() == 51.3)
    }

    @Test func reportsDenialWithTheErrorConstants() throws {
        let context = try run("""
        new Geolocation().getCurrentPosition(() => {}, (error) => { result = error.code === error.PERMISSION_DENIED })
        reply({ code: 1, id: posted[0].id, message: 'User denied Geolocation', type: 'error' })
        """)
        #expect(context.evaluateScript("result").toBool())
    }

    @Test func startsTheTimeoutOnlyOncePermitted() throws {
        let context = try run("""
        new Geolocation().getCurrentPosition(() => {}, (error) => { result = error.code }, { timeout: 10000 })
        """)
        #expect(context.evaluateScript("timers.length").toInt32() == 0)
        context.evaluateScript("reply({ id: posted[0].id, type: 'start' }); timers[0]()")
        #expect(context.evaluateScript("result").toInt32() == 3)
        #expect(context.evaluateScript("posted[1].type").toString() == "clear")
    }
}
