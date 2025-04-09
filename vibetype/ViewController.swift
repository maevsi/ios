import UIKit
import WebKit
import AppTrackingTransparency

var webView: WKWebView! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate {

    var documentController: UIDocumentInteractionController?
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    var toolbarView: UIToolbar!

    var htmlIsLoaded = false;

    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified
    override var preferredStatusBarStyle : UIStatusBarStyle {
        if #available(iOS 13, *), overrideStatusBar{
            if #available(iOS 15, *) {
                return .default
            } else {
                return statusBarTheme == "dark" ? .lightContent : .darkContent
            }
        }
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        initToolbarView()
        loadRootUrl()
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        vibetype.webView.frame = calcWebviewFrame(webviewView: webviewView, toolbarView: nil)
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        vibetype.webView.setNeedsLayout()
    }

    func initWebView() {
        vibetype.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        webviewView.addSubview(vibetype.webView);

        vibetype.webView.uiDelegate = self;

        vibetype.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if(pullToRefresh){
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: UIControl.Event.valueChanged)
            vibetype.webView.scrollView.addSubview(refreshControl)
            vibetype.webView.scrollView.bounces = true
        }

        if #available(iOS 15.0, *), adaptiveUIStyle {
            themeObservation = vibetype.webView.observe(\.underPageBackgroundColor) { [unowned self] webView, _ in
                currentWebViewTheme = vibetype.webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        vibetype.webView?.reload()
        sender.endRefreshing()
    }

    func createToolbarView() -> UIToolbar{
        let winScene = UIApplication.shared.connectedScenes.first
        let windowScene = winScene as! UIWindowScene
        var statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 60

        #if targetEnvironment(macCatalyst)
        if (statusBarHeight == 0){
            statusBarHeight = 30
        }
        #endif

        let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: webviewView.frame.width, height: 0))
        toolbarView.sizeToFit()
        toolbarView.frame = CGRect(x: 0, y: 0, width: webviewView.frame.width, height: toolbarView.frame.height + statusBarHeight)
//        toolbarView.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin, .flexibleWidth]

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(loadRootUrl))
        toolbarView.setItems([close,flex], animated: true)

        toolbarView.isHidden = true

        return toolbarView
    }

    func overrideUIStyle(toDefault: Bool = false) {
        if #available(iOS 15.0, *), adaptiveUIStyle {
            if (((htmlIsLoaded && !vibetype.webView.isHidden) || toDefault) && self.currentWebViewTheme != .unspecified) {
                UIApplication
                    .shared
                    .connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme;
            }
        }
    }

    func initToolbarView() {
        toolbarView =  createToolbarView()

        webviewView.addSubview(toolbarView)
    }

 @objc func loadRootUrl() {
        vibetype.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    htmlIsLoaded = true
    self.setProgress(1.0, true)
    self.animateConnectionProblem(false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        vibetype.webView.isHidden = false
        self.loadingView.isHidden = true
        self.setProgress(0.0, false)
        self.overrideUIStyle()
        self.handleTrackingPermission()
    }
}

// Enable this block for local simulator testing to bypass SSL certificate validation.
// (Do NOT use this in production.)
/*
func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, 
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    } else {
        completionHandler(.performDefaultHandling, nil)
    }
}
*/


    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;

        if (error as NSError)._code != (-999) {
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
    func returnTrackingPermissionResult(isAuthorized: Bool) {
        let result = isAuthorized ? "authorized" : "denied"
        dispatchEventToWebView(name: "tracking-permission-request", data: result)
    }

    func returnTrackingPermissionState(state: String) {
        dispatchEventToWebView(name: "tracking-permission-state", data: state)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "print":
            printView(webView: vibetype.webView)
        case "push-subscribe":
            handleSubscribeTouch(message: message)
        case "push-permission-request":
            handlePushPermission()
        case "push-permission-state":
            handlePushState()
        case "push-token":
            handleFCMToken()
        case "tracking-permission-request":
            handleTrackingPermission()
        case "tracking-permission-state":
            handleTrackingState()
        default:
            break
        }
    }

    func handleTrackingPermission() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            let isAuthorized = status == .authorized
            self?.dispatchEventToWebView(
                name: "tracking-permission-result",
                data: isAuthorized ? "authorized" : "denied"
            )
        }
    }

func dispatchEventToWebView(name: String, data: String) {
    DispatchQueue.main.async {
        vibetype.webView.evaluateJavaScript("""
            window.dispatchEvent(new CustomEvent('\(name)', { detail: '\(data)' }));
            """, completionHandler: nil)
    }
}

func handleTrackingState() {
    let status = ATTrackingManager.trackingAuthorizationStatus
    let isAuthorized = status == .authorized
    let state = isAuthorized ? "authorized" : "denied"
    returnTrackingPermissionState(state: state)
}
}
