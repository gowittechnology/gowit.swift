import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS) || os(tvOS)

/// A Safari-style in-app browser for displaying ad destinations
///
/// This view provides a full-featured browser with navigation controls,
/// refresh capability, and a close button.
public struct InAppBrowserView: View {
    @Binding var isPresented: Bool
    let url: URL
    
    @StateObject private var viewModel = InAppBrowserViewModel()
    
    public init(isPresented: Binding<Bool>, url: URL) {
        self._isPresented = isPresented
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
                        isPresented = false
                    }) {
                        Text("Close")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Back button
                        Button(action: {
                            viewModel.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!viewModel.canGoBack)
                        
                        // Forward button
                        Button(action: {
                            viewModel.goForward()
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!viewModel.canGoForward)
                        
                        // Refresh button
                        Button(action: {
                            viewModel.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
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
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Store webView reference in view model
        DispatchQueue.main.async {
            viewModel.webView = webView
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load URL only if not already loaded
        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
        }
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
            viewModel.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.isLoading = false
            viewModel.pageTitle = webView.title
            viewModel.canGoBack = webView.canGoBack
            viewModel.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            viewModel.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            viewModel.isLoading = false
        }
    }
}

// MARK: - View Model

class InAppBrowserViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var pageTitle: String?
    @Published var canGoBack = false
    @Published var canGoForward = false
    
    weak var webView: WKWebView? {
        didSet {
            // Observe progress
            webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        }
    }
    
    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            DispatchQueue.main.async { [weak self] in
                self?.estimatedProgress = self?.webView?.estimatedProgress ?? 0
            }
        }
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

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            Button("Show Browser") {
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                InAppBrowserView(
                    isPresented: $isPresented,
                    url: URL(string: "https://www.example.com")!
                )
            }
        }
    }
    
    return PreviewWrapper()
}

#endif // os(iOS) || os(tvOS)
