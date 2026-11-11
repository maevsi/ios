import WebKit

struct Cookie {
    var name: String
    var value: String
}

// URL for first launch
let rootUrl = URL(string: "https://vibetype.app/?source=pwa")!

// allowed origin is for what we are sticking to pwa domain
// This should also appear in Info.plist
let allowedOrigins: [String] = ["vibetype.app"]

let platformCookie = Cookie(name: "vibetype_platform", value: "ios")

// UI options
let displayMode = "standalone" // standalone / fullscreen.
let adaptiveUIStyle = true     // Change app theme on the fly to dark/light related to WebView background color.
let pullToRefresh = true    // Enable/disable pull down to refresh page
