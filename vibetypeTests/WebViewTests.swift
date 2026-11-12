import Testing
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
