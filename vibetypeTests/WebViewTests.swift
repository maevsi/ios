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
