import UIKit
import WebKit

var webView: WKWebView! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate {

    var documentController: UIDocumentInteractionController?
    var downloadDestinations: [WKDownload: URL] = [:]
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!

    var htmlIsLoaded = false;

    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified

    override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        loadRootUrl()

        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        vibetype.webView.frame = calcWebviewFrame(webviewView: webviewView)
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        vibetype.webView.setNeedsLayout()
    }

    func initWebView() {
        vibetype.webView = createWebView(container: webviewView, WKSMH: self, WKND: self)
        webviewView.addSubview(vibetype.webView);

        vibetype.webView.uiDelegate = self;

        vibetype.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if pullToRefresh {
            #if !targetEnvironment(macCatalyst)
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: .valueChanged)
            vibetype.webView.scrollView.addSubview(refreshControl)
            vibetype.webView.scrollView.bounces = true
            #endif
        }

        if adaptiveUIStyle {
            // Pin the web view to the true system appearance. The chrome override below is set on the
            // key window, which would otherwise propagate into the web view and change what
            // `prefers-color-scheme` reports to the page. That feedback loop locks a "follow system"
            // page to whichever style we last forced (e.g. it never returns to dark after being
            // switched to light). An explicit override on the web view decouples it from the window.
            syncWebViewInterfaceStyle()
            themeObservation = vibetype.webView.observe(\.underPageBackgroundColor) { [unowned self] webView, _ in
                currentWebViewTheme = vibetype.webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Keep the web view aligned with the true device appearance when the user changes the
        // system dark/light setting while the app is running.
        syncWebViewInterfaceStyle()
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        vibetype.webView?.reload()
        sender.endRefreshing()
    }

    func overrideUIStyle(toDefault: Bool = false) {
        if adaptiveUIStyle {
            guard toDefault || (htmlIsLoaded && !vibetype.webView.isHidden) else { return }
            let style: UIUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme
            UIApplication
                .shared
                .connectedScenes
                .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = style
        }
    }

    // The true device appearance, unaffected by the chrome override we place on the key window.
    // Trait overrides only propagate downward, so the window scene above the window keeps the real
    // system style.
    private var systemInterfaceStyle: UIUserInterfaceStyle {
        // Prefer the scene hosting this view controller when available.
        if let windowScene = view.window?.windowScene {
            return windowScene.traitCollection.userInterfaceStyle
        }
        // Fallback to the foreground-active scene.
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return windowScene?.traitCollection.userInterfaceStyle ?? .unspecified
    }

    func syncWebViewInterfaceStyle() {
        if adaptiveUIStyle {
            vibetype.webView?.overrideUserInterfaceStyle = systemInterfaceStyle
        }
    }

    @objc func loadRootUrl() {
        vibetype.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true

        // The launch link has been served, later reloads start from the root again.
        SceneDelegate.universalLinkToLaunch = nil
        SceneDelegate.shortcutLinkToLaunch = nil

        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            vibetype.webView.isHidden = false
            self.loadingView.isHidden = true

            self.setProgress(0.0, false)

            self.overrideUIStyle()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;

        // -999 is a cancelled load, 102 a navigation that the policy handler cancelled or turned into a download.
        if ![-999, 102].contains((error as NSError).code) {
            self.overrideUIStyle(toDefault: true);

            webView.isHidden = true;
            loadingView.isHidden = false;
            animateConnectionProblem(true);

            setProgress(0.05, true);

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setProgress(0.1, true);
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.loadRootUrl();
                }
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath == #keyPath(WKWebView.estimatedProgress) &&
                vibetype.webView.isLoading &&
                !self.loadingView.isHidden &&
                !self.htmlIsLoaded) {
                    var progress = Float(vibetype.webView.estimatedProgress);

                    if (progress >= 0.8) { progress = 1.0; };
                    if (progress >= 0.3) { self.animateConnectionProblem(false); }

                    self.setProgress(progress, true);
        }
    }

    func setProgress(_ progress: Float, _ animated: Bool) {
        self.progressView.setProgress(progress, animated: animated);
    }


    func animateConnectionProblem(_ show: Bool) {
        if (show) {
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }

    deinit {
        vibetype.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        themeObservation?.invalidate()
    }
}

extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Embedded frames must not reach the native bridge.
        guard message.frameInfo.isMainFrame else { return }
        if message.name == "att-get-idfa" {
            handleATTGetIDFA()
        }
        if message.name == "att-get-status" {
            handleATTGetStatus()
        }
        if message.name == "att-request-permission" {
            handleATTPermissionRequest()
        }
        if message.name == "print" {
            printView(webView: vibetype.webView)
        }
        if message.name == "push-permission-request" {
            handlePushPermission()
        }
        if message.name == "push-permission-state" {
            handlePushState()
        }
        if message.name == "push-subscribe" {
            handleSubscribeTouch(message: message)
        }
        if message.name == "push-token" {
            handleFCMToken()
        }
  }
}

// MARK: - App Tracking Transparency Handlers
extension ViewController {

    private func dispatchATTEvent(eventName: String, detail: String) {
        func toJsonString(_ value: String) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return String(json.dropFirst().dropLast()) // strip wrapping [ and ]
        }
        guard let detailJson = toJsonString(detail),
              let eventNameJson = toJsonString(eventName) else {
            print("Error encoding ATT event data for: \(eventName)")
            return
        }
        let script = "window.dispatchEvent(new CustomEvent(\(eventNameJson), { detail: \(detailJson) }));"
        vibetype.webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error dispatching \(eventName): \(error)")
            }
        }
    }

    func handleATTPermissionRequest() {
        TrackingTransparencyManager.requestPermission { [weak self] status in
            guard let self else { return }
            self.dispatchATTEvent(eventName: "att-permission-response", detail: TrackingTransparencyManager.statusToString(status))
        }
    }

    func handleATTGetStatus() {
        dispatchATTEvent(eventName: "att-status-response", detail: TrackingTransparencyManager.getStatusString())
    }

    func handleATTGetIDFA() {
        dispatchATTEvent(eventName: "att-idfa-response", detail: TrackingTransparencyManager.getIDFA() ?? "")
    }
}
