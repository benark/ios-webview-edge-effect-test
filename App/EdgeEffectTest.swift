import UIKit
import WebKit

// A full-screen WKWebView that loads one page and applies one setting to the scroll view's top edge effect.
// It stands in for the iOS Home Screen web app shell, which is the only place that setting can be made.
//
// Launch arguments (read through UserDefaults):
//   -url <page>      page to load
//   -style <name>    automatic (default) | soft | hard | hidden
//   -scroll <px>     scroll the page by this many CSS px after it loads (default 0)
//   -name <label>    name of the report file written to Documents when the page is ready

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = WebViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class WebViewController: UIViewController, WKNavigationDelegate {
    private let defaults = UserDefaults.standard
    private var webView: WKWebView!

    private var style: String { defaults.string(forKey: "style") ?? "automatic" }
    private var reportName: String { defaults.string(forKey: "name") ?? "report" }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // The web view covers the whole screen, status bar included, with no obscured inset of its own.
        webView = WKWebView(frame: view.bounds, configuration: WKWebViewConfiguration())
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)

        let effect = webView.scrollView.topEdgeEffect
        switch style {
        case "soft": effect.style = .soft
        case "hard": effect.style = .hard
        case "hidden": effect.isHidden = true
        default: break
        }

        guard let url = URL(string: defaults.string(forKey: "url") ?? "") else {
            writeReport(["error": "missing or invalid -url"])
            return
        }
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let scroll = defaults.integer(forKey: "scroll")
        webView.evaluateJavaScript("window.scrollTo(0, \(scroll)); null") { _, _ in }
        // Give the page time to settle: iOS can apply the safe-area inset after the first script has run.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.collectReport()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        writeReport(["error": error.localizedDescription])
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        writeReport(["error": error.localizedDescription])
    }

    private func collectReport() {
        let script = "JSON.stringify({ info: (document.getElementById('mode') || {}).textContent || null, scrollY: window.scrollY })"
        webView.evaluateJavaScript(script) { result, error in
            let page = (result as? String) ?? "script error: \(error?.localizedDescription ?? "unknown")"
            Task { @MainActor in self.writeReport(self.nativeState().merging(["page": page]) { _, new in new }) }
        }
    }

    private func nativeState() -> [String: String] {
        let effect = webView.scrollView.topEdgeEffect
        return [
            "style requested": style,
            "url": webView.url?.absoluteString ?? "",
            "topEdgeEffect": String(describing: effect),
            "topEdgeEffect.isHidden": String(effect.isHidden),
            "iOS": UIDevice.current.systemVersion,
            "view bounds": NSCoder.string(for: view.bounds),
            "webView safeAreaInsets": NSCoder.string(for: webView.safeAreaInsets),
            "scrollView adjustedContentInset": NSCoder.string(for: webView.scrollView.adjustedContentInset),
            "scrollView contentOffset": NSCoder.string(for: webView.scrollView.contentOffset),
        ]
    }

    // The test script waits for this file before it takes the screenshot.
    private func writeReport(_ fields: [String: String]) {
        let text = fields.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n") + "\n"
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? text.write(to: directory.appendingPathComponent("\(reportName).txt"), atomically: true, encoding: .utf8)
    }
}
