import SwiftUI
import WebKit

// MARK: - LaTeX math renderer
/// Renders display math (LaTeX) via a lightweight WKWebView loading KaTeX,
/// reporting the rendered height back so the view sizes to its content.
/// Used by `MessageMarkdownView` for $$…$$ blocks and ```math/latex fences.
struct MathView: View {
    let source: String
    var fontScale: Double = 1.0
    @State private var height: CGFloat = 44
    @State private var showSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("math")
                    .font(.system(size: AppFont.pt(10) * fontScale, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showSource.toggle() }) {
                    Image(systemName: showSource ? "function" : "curlybraces")
                        .font(.system(size: AppFont.pt(10)))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(showSource ? "Show rendered math" : "Show LaTeX source")
                #if os(macOS)
                .help(showSource ? "Show rendered math" : "Show LaTeX source")
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))

            if showSource {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(source)
                        .font(.system(size: AppFont.pt(12) * fontScale, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(12)
                }
            } else {
                MathWebView(source: source, height: $height)
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

private struct MathWebView: PlatformWebViewRepresentable {
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
            webView.loadHTMLString(MathWebView.html(for: source), baseURL: nil)
        }

        func userContentController(
            _ controller: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard let value = message.body as? NSNumber else { return }
            let h = CGFloat(truncating: value)
            if h > 0 {
                DispatchQueue.main.async { self.height.wrappedValue = min(max(h, 32), 1200) }
            }
        }
    }

    /// Self-contained HTML: KaTeX from CDN, transparent background, and a
    /// height report back to Swift after rendering.
    static func html(for source: String) -> String {
        // JSON-encode the LaTeX so quotes/backslashes/newlines are safe in JS.
        let encoded =
            (try? String(
                data: JSONSerialization.data(withJSONObject: [source], options: []),
                encoding: .utf8))?.dropFirst().dropLast() ?? "\"\""
        return """
            <!doctype html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
            <style>
              html,body{margin:0;padding:0;background:transparent;}
              #d{display:flex;justify-content:center;padding:8px 10px;overflow-x:auto;}
              @media (prefers-color-scheme: dark){ #d{color:#ddd;} }
              .err{color:#c0392b;font:12px -apple-system;padding:8px;}
            </style></head>
            <body><div id="d"></div>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
            <script>
              const src = [\(encoded)][0];
              function report(){
                const h = document.getElementById('d').scrollHeight;
                window.webkit?.messageHandlers?.sizer?.postMessage(h);
              }
              try {
                katex.render(src, document.getElementById('d'),
                  {displayMode:true, throwOnError:false});
              } catch (e) {
                document.getElementById('d').innerHTML =
                  '<pre class="err">'+String(e).replace(/[<&]/g,'')+'</pre>';
              }
              report(); setTimeout(report, 120);
            </script></body></html>
            """
    }
}
