import SwiftUI
import WebKit

private let sniffJS = """
(function () {
  if (window.__dannySniffInstalled) return;
  window.__dannySniffInstalled = true;
  var send = function (u) {
    if (!u || typeof u !== 'string' || u.startsWith('data:') || u.startsWith('blob:')) return;
    try { window.webkit.messageHandlers.dannySniff.postMessage({ url: u }); } catch (e) {}
  };
  var byExtension = /\\.(m3u8|mpd|mp4|webm|mov|m4v|mkv|ts|mp3|m4a|aac|flac|opus|ogg)(\\?|$)/i;
  var byPattern = /videoplayback|googlevideo|manifest|playlist|master|chunklist|\\.mpd/i;
  var isMedia = function (u) { return byExtension.test(u) || byPattern.test(u); };

  var origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function () {
      try {
        var input = arguments[0];
        var u = typeof input === 'string' ? input : (input && input.url);
        if (u && isMedia(u)) send(u);
      } catch (e) {}
      return origFetch.apply(this, arguments);
    };
  }

  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try {
      if (url && typeof url === 'string' && isMedia(url)) send(url);
    } catch (e) {}
    return origOpen.apply(this, arguments);
  };

  var scanMedia = function () {
    try {
      document.querySelectorAll('video, audio').forEach(function (el) {
        var s = el.currentSrc || el.src || el.getAttribute('src');
        if (s) send(s);
      });
      document.querySelectorAll('video source, audio source').forEach(function (el) {
        var s = el.src || el.getAttribute('src');
        if (s) send(s);
      });
    } catch (e) {}
  };
  new MutationObserver(scanMedia).observe(document.documentElement || document, {
    subtree: true, childList: true, attributes: true
  });

  setInterval(function () {
    try {
      performance.getEntriesByType('resource').forEach(function (entry) {
        if (isMedia(entry.name)) send(entry.name);
      });
    } catch (e) {}
  }, 1200);

  document.addEventListener('DOMContentLoaded', scanMedia);
})();
"""

final class SniffingWebView: WKWebView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            teardownMedia()
            return
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: window)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        teardownMedia()
    }

    private func teardownMedia() {
        stopLoading()
        configuration.userContentController.removeAllScriptMessageHandlers()
        if let blank = URL(string: "about:blank") {
            load(URLRequest(url: blank))
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct MediaSnifferWebView: NSViewRepresentable {
    let startURL: URL
    let reference: WebViewReference
    let onCaptured: @MainActor (String) -> Void
    let onCommitted: @MainActor (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptured: onCaptured, onCommitted: onCommitted)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "dannySniff")
        controller.addUserScript(
            WKUserScript(source: sniffJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        configuration.userContentController = controller

        let webView = SniffingWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        reference.webView = webView
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        reference.webView = webView
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var webView: WKWebView?
        private let onCaptured: @MainActor (String) -> Void
        private let onCommitted: @MainActor (URL?) -> Void

        init(onCaptured: @escaping @MainActor (String) -> Void, onCommitted: @escaping @MainActor (URL?) -> Void) {
            self.onCaptured = onCaptured
            self.onCommitted = onCommitted
        }
    }
}

extension MediaSnifferWebView.Coordinator: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let rawURL = body["url"] as? String
        else { return }
        Task { @MainActor in
            self.onCaptured(rawURL)
        }
    }
}

extension MediaSnifferWebView.Coordinator: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Task { @MainActor in
            self.onCommitted(webView.url)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }
}

extension MediaSnifferWebView.Coordinator: WKUIDelegate {
    nonisolated func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
}
