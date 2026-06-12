import SwiftUI
import WebKit

// MARK: - Mermaid diagram renderer
/// Renders a Mermaid diagram from its source via a lightweight WKWebView that
/// loads mermaid.js and reports the rendered SVG height back so the view sizes
/// to its content. Used by `MessageMarkdownView` for ```mermaid code blocks.
struct MermaidView: View {
    let source: String
    var fontScale: Double = 1.0
    @State private var height: CGFloat = 60
    @State private var showSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("diagram")
                    .font(.system(size: AppFont.pt(10), weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showSource.toggle() }) {
                    Image(systemName: showSource ? "chart.bar.doc.horizontal" : "curlybraces")
                        .font(.system(size: AppFont.pt(10)))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(showSource ? "Show diagram" : "Show source")
                #if os(macOS)
                .help(showSource ? "Show diagram" : "Show source")
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))

            if showSource {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(source)
                        .font(.system(size: AppFont.pt(12), design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(12)
                }
            } else {
                MermaidWebView(source: source, height: $height)
                    .frame(height: height)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.hairline))
    }
}

// MARK: - WKWebView bridge

#if os(macOS)
private typealias PlatformWebViewRepresentable = NSViewRepresentable
#else
private typealias PlatformWebViewRepresentable = UIViewRepresentable
#endif

private struct MermaidWebView: PlatformWebViewRepresentable {
    let source: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    private func makeWebView(_ context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "sizer")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")  // transparent
        #else
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        #endif
        webView.loadHTMLString(Self.html(for: source), baseURL: nil)
        return webView
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView { makeWebView(context) }
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.reloadIfNeeded(webView, source: source)
    }
    #else
    func makeUIView(context: Context) -> WKWebView { makeWebView(context) }
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.reloadIfNeeded(webView, source: source)
    }
    #endif

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let height: Binding<CGFloat>
        private var lastSource: String = ""

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func reloadIfNeeded(_ webView: WKWebView, source: String) {
            guard source != lastSource else { return }
            lastSource = source
            webView.loadHTMLString(MermaidWebView.html(for: source), baseURL: nil)
        }

        func userContentController(
            _ controller: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard let value = message.body as? NSNumber else { return }
            let h = CGFloat(truncating: value)
            if h > 0 {
                DispatchQueue.main.async { self.height.wrappedValue = min(max(h, 40), 2000) }
            }
        }
    }

    /// Self-contained HTML: mermaid from CDN, transparent background, and a
    /// resize observer that posts the rendered height back to Swift.
    static func html(for source: String) -> String {
        // JSON-encode the diagram source so quotes/newlines are safe in JS.
        let encoded =
            (try? String(
                data: JSONSerialization.data(withJSONObject: [source], options: []),
                encoding: .utf8))?.dropFirst().dropLast() ?? "\"\""
        return """
            <!doctype html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              html,body{margin:0;padding:0;background:transparent;}
              #d{display:flex;justify-content:center;padding:4px 8px;
                 font-family:-apple-system,sans-serif;}
              .err{color:#c0392b;font:12px -apple-system;padding:8px;}
            </style></head>
            <body><div id="d" class="mermaid">loading…</div>
            <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
            <script>
              const src = [\(encoded)][0];
              function report(){
                const h = document.getElementById('d').scrollHeight;
                window.webkit?.messageHandlers?.sizer?.postMessage(h);
              }
              (async () => {
                try {
                  mermaid.initialize({startOnLoad:false, securityLevel:'strict',
                    theme: matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'});
                  const {svg} = await mermaid.render('g', src);
                  document.getElementById('d').innerHTML = svg;
                } catch (e) {
                  document.getElementById('d').innerHTML =
                    '<pre class="err">'+String(e).replace(/[<&]/g,'')+'</pre>';
                }
                report(); setTimeout(report, 120);
              })();
            </script></body></html>
            """
    }
}
