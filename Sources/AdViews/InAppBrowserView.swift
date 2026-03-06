import SwiftUI
import WebKit
import Gowit

/// A Safari-style in-app browser for displaying ad destinations
///
/// This view provides a full-featured browser with navigation controls,
/// refresh capability, and a close button.
public struct InAppBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    @StateObject private var viewModel = InAppBrowserViewModel()

    public init(url: URL) {
        GowitLogger.debug("Init called with URL: \(url.absoluteString)")
        self.url = url
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                if viewModel.isLoading {
                    ProgressView(value: viewModel.estimatedProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                } else {
                    Color.clear.frame(height: 2)
                }

                // WebView
                InAppBrowserWebView(
                    url: url,
                    viewModel: viewModel
                )
            }
            .navigationTitle(viewModel.pageTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Text("Close")
                    })
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Back button
                        Button(action: {
                            viewModel.goBack()
                        }, label: {
                            Image(systemName: "chevron.left")
                        })
                        .disabled(!viewModel.canGoBack)

                        // Forward button
                        Button(action: {
                            viewModel.goForward()
                        }, label: {
                            Image(systemName: "chevron.right")
                        })
                        .disabled(!viewModel.canGoForward)

                        // Refresh button
                        Button(action: {
                            viewModel.reload()
                        }, label: {
                            Image(systemName: "arrow.clockwise")
                        })
                    }
                }
            }
        }
    }
}

// MARK: - WebView Representable

struct InAppBrowserWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var viewModel: InAppBrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        GowitLogger.debug("makeUIView called for URL: \(url.absoluteString)")
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Store webView reference in view model
        DispatchQueue.main.async {
            viewModel.webView = webView
        }

        GowitLogger.debug("WKWebView created successfully")
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load URL only if not already loaded
        if webView.url == nil {
            GowitLogger.debug("Loading URL: \(url.absoluteString)")
            let request = URLRequest(url: url)
            webView.load(request)
        }
        // URL already loaded, no need to log repeatedly
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        GowitLogger.debug("Dismantling web view")
        uiView.stopLoading()
        uiView.navigationDelegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: InAppBrowserViewModel

        init(viewModel: InAppBrowserViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            GowitLogger.debug("Navigation started: \(webView.url?.absoluteString ?? "unknown")")
            viewModel.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            GowitLogger.debug("Navigation finished: \(webView.url?.absoluteString ?? "unknown")")
            GowitLogger.debug("Page title: \(webView.title ?? "no title")")
            viewModel.isLoading = false
            viewModel.pageTitle = webView.title
            viewModel.canGoBack = webView.canGoBack
            viewModel.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            GowitLogger.error("Navigation failed: \(error.localizedDescription)")
            GowitLogger.error("Error details: \(error)")
            viewModel.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            GowitLogger.error("Provisional navigation failed: \(error.localizedDescription)")
            GowitLogger.error("Error details: \(error)")
            viewModel.isLoading = false
        }
    }
}

// MARK: - View Model

class InAppBrowserViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var pageTitle: String?
    @Published var canGoBack = false
    @Published var canGoForward = false

    private var progressObservation: NSKeyValueObservation?

    weak var webView: WKWebView? {
        didSet {
            // Observe progress using modern block-based KVO
            progressObservation = webView?.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.estimatedProgress = webView.estimatedProgress
                }
            }
        }
    }

    deinit {
        progressObservation?.invalidate()
    }

    func reload() {
        webView?.reload()
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }
}
