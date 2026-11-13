import UIKit
import WebKit
import AuthenticationServices
import SafariServices

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: AnyObject?

    init(delegate: AnyObject & WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        (delegate as? WKScriptMessageHandler)?.userContentController(userContentController, didReceive: message)
    }
}

func createWebView(container: UIView, WKSMH: AnyObject & WKScriptMessageHandler, WKND: WKNavigationDelegate) -> WKWebView{

    let config = WKWebViewConfiguration()
    let userContentController = WKUserContentController()
    let deviceModel = UIDevice.current.model
    let osVersion = ProcessInfo().operatingSystemVersion
    let weakHandler = WeakScriptMessageHandler(delegate: WKSMH)

    userContentController.add(weakHandler, name: "att-get-idfa")
    userContentController.add(weakHandler, name: "att-get-status")
    userContentController.add(weakHandler, name: "att-request-permission")
    userContentController.add(weakHandler, name: "print")
    userContentController.add(weakHandler, name: "push-permission-request")
    userContentController.add(weakHandler, name: "push-permission-state")
    userContentController.add(weakHandler, name: "push-subscribe")
    userContentController.add(weakHandler, name: "push-token")

    config.userContentController = userContentController

    config.limitsNavigationsToAppBoundDomains = true;
    config.allowsInlineMediaPlayback = true
    config.preferences.javaScriptCanOpenWindowsAutomatically = true
    config.preferences.setValue(true, forKey: "standalone")
    config.applicationNameForUserAgent = "Device/\(deviceModel) Version/\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion) Safari/vibetype"

    let webView = WKWebView(frame: calcWebviewFrame(webviewView: container), configuration: config)
    setCustomCookie(webView: webView)

    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.isHidden = true;
    webView.navigationDelegate = WKND
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.allowsBackForwardNavigationGestures = true

    #if DEBUG
    if #available(iOS 16.4, *) {
        webView.isInspectable = true
    }
    #endif

    return webView
}

// A host belongs to an origin if it is that origin or one of its subdomains.
// A substring match would also accept hosts like `vibetype.app.example.com`.
func hostMatches(_ host: String, origin: String) -> Bool {
    let host = host.lowercased()
    let origin = origin.lowercased()
    return host == origin || host.hasSuffix("." + origin)
}

func setCustomCookie(webView: WKWebView) {
    let _platformCookie = HTTPCookie(properties: [
        .domain: rootUrl.host!,
        .path: "/",
        .name: platformCookie.name,
        .value: platformCookie.value,
        .secure: "FALSE",
        .expires: NSDate(timeIntervalSinceNow: 31556926)
    ])!

    webView.configuration.websiteDataStore.httpCookieStore.setCookie(_platformCookie)

}

func calcWebviewFrame(webviewView: UIView) -> CGRect{
    let winScene = UIApplication.shared.connectedScenes.first
    let windowScene = winScene as! UIWindowScene
    var statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 0

    switch displayMode {
    case "fullscreen":
        #if targetEnvironment(macCatalyst)
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        #endif
        return CGRect(x: 0, y: 0, width: webviewView.frame.width, height: webviewView.frame.height)
    default:
        #if targetEnvironment(macCatalyst)
        statusBarHeight = 29
        #endif
        let windowHeight = webviewView.frame.height - statusBarHeight
        return CGRect(x: 0, y: statusBarHeight, width: webviewView.frame.width, height: windowHeight)
    }
}

extension ViewController: WKUIDelegate, WKDownloadDelegate {
    // redirect new tabs to main webview
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if (navigationAction.targetFrame == nil) {
            webView.load(navigationAction.request)
        }
        return nil
    }
    // restrict navigation to target host, open external links in 3rd party apps
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if (navigationAction.request.url?.scheme == "about") {
            return decisionHandler(.allow)
        }
        if (navigationAction.shouldPerformDownload || navigationAction.request.url?.scheme == "blob") {
            return decisionHandler(.download)
        }

        if let requestUrl = navigationAction.request.url{
            // Schemes that are always handed off to the system instead of being treated as in-app navigation.
            let externalSchemes = ["tel", "telprompt", "mailto", "facetime", "facetime-audio", "fb", "fb-messenger", "sms", "itms-services", "itms-apps", "itms", "maps"]
            if let requestScheme = requestUrl.scheme?.lowercased(), externalSchemes.contains(requestScheme) {
                decisionHandler(.cancel)
                // `canOpenURL` reports false for schemes missing from `LSApplicationQueriesSchemes`, `open` needs no declaration.
                UIApplication.shared.open(requestUrl)
                return
            }

            if let requestHost = requestUrl.host {
                let matchingHostOrigin = allowedOrigins.first(where: { hostMatches(requestHost, origin: $0) })
                if (matchingHostOrigin != nil) {
                    // Open in main webview
                    decisionHandler(.allow)
                    return
                }
                // Embedded frames may load third-party content, the main frame leaves the app instead.
                if navigationAction.targetFrame?.isMainFrame == false {
                    decisionHandler(.allow)
                    return
                }
                else {
                    decisionHandler(.cancel)
                }


                if ["http", "https"].contains(requestUrl.scheme?.lowercased() ?? "") {
                    // Can open with SFSafariViewController
                    let safariViewController = SFSafariViewController(url: requestUrl)
                    self.present(safariViewController, animated: true, completion: nil)
                } else {
                    // Scheme is not supported or no scheme is given, use openURL
                    UIApplication.shared.open(requestUrl)
                }
            } else {
                decisionHandler(.cancel)
            }
        }
        else {
            decisionHandler(.cancel)
        }
    }
    // Handle javascript: `window.alert(message: String)`
    func webView(_ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler
                completionHandler()
            }
        )
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }
    // Handle javascript: `window.confirm(message: String)`
    func webView(_ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        // Add a confirmation action “Cancel”
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // Call completionHandler
                completionHandler(false)
            }
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler
                completionHandler(true)
            }
        )
        alert.addAction(cancelAction)
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }
    // Handle javascript: `window.prompt(prompt: String, defaultText: String?)`
    func webView(_ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: prompt,
            preferredStyle: .alert
        )

        // Add a confirmation action “Cancel”
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // Call completionHandler
                completionHandler(nil)
            }
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler with Alert input
                completionHandler(alert.textFields?.first?.text ?? "")
            }
        )

        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(cancelAction)
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }

    func openFile(url: URL) {
        self.documentController = UIDocumentInteractionController(url: url)
        self.documentController?.delegate = self
        self.documentController?.presentPreview(animated: true)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                suggestedFilename: String,
                completionHandler: @escaping (URL?) -> Void) {

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(suggestedFilename)

        // Remove existing file if it exists, otherwise it may show an old file/content just by having the same name.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        downloadDestinations[download] = fileURL
        completionHandler(fileURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let fileURL = downloadDestinations.removeValue(forKey: download) {
            self.openFile(url: fileURL)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: download)
        print("Download failed: \(error.localizedDescription)")
    }
}
