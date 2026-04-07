import SwiftUI
import WebKit

struct StravaAuthView: View {
    @ObservedObject var strava: StravaService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            StravaWebView(strava: strava, dismiss: dismiss)
                .navigationTitle("Connect to Strava")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#if os(iOS)
struct StravaWebView: UIViewRepresentable {
    let strava: StravaService
    let dismiss: DismissAction
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = strava.authURL {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(strava: strava, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let strava: StravaService
        let dismiss: DismissAction
        
        init(strava: StravaService, dismiss: DismissAction) {
            self.strava = strava
            self.dismiss = dismiss
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.host == "localhost" {
                Task { @MainActor in
                    await strava.handleCallback(url: url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#else
struct StravaWebView: NSViewRepresentable {
    let strava: StravaService
    let dismiss: DismissAction
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = strava.authURL {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(strava: strava, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let strava: StravaService
        let dismiss: DismissAction
        
        init(strava: StravaService, dismiss: DismissAction) {
            self.strava = strava
            self.dismiss = dismiss
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.host == "localhost" {
                Task { @MainActor in
                    await strava.handleCallback(url: url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif
