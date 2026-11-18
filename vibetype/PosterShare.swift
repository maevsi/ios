import Foundation

// Removes the poster the share extension left at `url` and returns it, unless it is more than a day old.
func takeSharedPoster(at url: URL, now: Date = Date()) -> Data? {
    guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return nil }
    let jpeg = try? Data(contentsOf: url)
    try? FileManager.default.removeItem(at: url)
    guard now.timeIntervalSince(modified) < 24 * 60 * 60 else { return nil }
    return jpeg
}

// MARK: - Poster Share Handlers
extension ViewController {

    // Moves a shared poster from the App Group container into memory and reports whether there was one.
    func receiveSharedPoster() -> Bool {
        guard let url = sharedPosterUrl(), let jpeg = takeSharedPoster(at: url) else { return false }
        sharedPoster = jpegDataUrl(jpeg)
        return true
    }

    @objc func openSharedPoster() {
        if receiveSharedPoster() {
            vibetype.webView.load(URLRequest(url: posterHuntingUrl))
        }
    }

    // The page asks once it is mounted, which for a signed-out user only happens after signing in.
    // A pushed event could arrive before the page listens, as sign-in returns to it by client-side navigation.
    func handlePosterSharedRequest() {
        guard let sharedPoster else { return }
        self.sharedPoster = nil
        dispatchEvent(eventName: "poster-shared", detail: sharedPoster)
    }
}
