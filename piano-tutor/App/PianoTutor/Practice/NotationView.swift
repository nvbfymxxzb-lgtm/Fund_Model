import SwiftUI
import WebKit

/// Controls the sheet-music display. The score is drawn by a web page bundled inside the app (no network is used).
final class NotationController: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    @Published private(set) var errorMessage: String?
    var onMeasureTapped: ((Int) -> Void)?

    private var pageReady = false
    private var scoreLoaded = false
    private var pendingXML: (String, Double)?
    private var queued: [(String, [String: Any])] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        configuration.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        controller.add(WeakMessageHandler(self), name: "notation")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.bounces = true
        if let page = Bundle.main.url(forResource: "notation", withExtension: "html")
            ?? Bundle.main.url(forResource: "notation", withExtension: "html", subdirectory: "notation") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else {
            errorMessage = "The notation page is missing from the app bundle."
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        if let (xml, zoom) = pendingXML { pendingXML = nil; load(xml: xml, zoom: zoom) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "loaded":
            scoreLoaded = true
            errorMessage = nil
            let calls = queued
            queued = []
            for (script, arguments) in calls { run(script, arguments) }
        case "error":
            errorMessage = (body["message"] as? String).map { "This score could not be drawn: \($0)" } ?? "This score could not be drawn."
        case "measureTapped":
            if let measure = body["measure"] as? Int { onMeasureTapped?(measure) }
        default: break
        }
    }

    private func run(_ script: String, _ arguments: [String: Any]) {
        webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page, completionHandler: nil)
    }

    private func call(_ script: String, _ arguments: [String: Any] = [:]) {
        if scoreLoaded { run(script, arguments) } else { queued.append((script, arguments)) }
    }

    func load(xml: String, zoom: Double = 1.0) {
        scoreLoaded = false
        queued = []
        guard pageReady else { pendingXML = (xml, zoom); return }
        run("window.notation.load(xml, zoom);", ["xml": xml, "zoom": zoom])
    }

    func setCurrent(_ keys: [String], scroll: Bool = true) { call("window.notation.setCurrent(keys, scroll);", ["keys": keys, "scroll": scroll]) }
    func mark(_ keys: [String], state: String) { if !keys.isEmpty { call("window.notation.mark(keys, state);", ["keys": keys, "state": state]) } }
    func clearMarks() { call("window.notation.clearMarks(); window.notation.setCurrent([], false);") }
    func setRange(first: Int, last: Int) { call("window.notation.setRange(first, last);", ["first": first, "last": last]) }
    func clearRange() { call("window.notation.setRange(null, null);") }
    func scrollToMeasure(_ index: Int) { call("window.notation.scrollToMeasure(m);", ["m": index]) }
}

/// Avoids the web view keeping its controller alive for ever.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

struct NotationView: UIViewRepresentable {
    let controller: NotationController
    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// A short piece of notation inside a lesson.
struct NotationSnippet: View {
    let xml: String
    var height: CGFloat = 190
    @StateObject private var controller = NotationController()

    init(xml: String, height: CGFloat = 190) { self.xml = xml; self.height = height }

    var body: some View {
        NotationView(controller: controller)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
            .onAppear { controller.load(xml: xml, zoom: 0.9) }
            .accessibilityLabel("Music notation example")
    }
}
