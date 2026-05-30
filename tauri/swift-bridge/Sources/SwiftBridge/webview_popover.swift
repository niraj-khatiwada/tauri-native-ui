import Cocoa
import SwiftRs
import WebKit

// @MainActor tells the compiler everything inside this class runs on the Main Thread,
// which safely resolves the non-Sendable concurrency warning for the static 'shared' property!
@MainActor
class PopoverManager {
    static let shared = PopoverManager()
    
    var activePopover: NSPopover?
    var activeController: WebViewController?

    func showOrToggle(targetURL: URL, hashFragment: String?, enableDevTools: Bool, x: Double, y: Double) {
        // 1. Toggle behavior: If the exact same popover is already open, close it gracefully
        if let popover = activePopover, popover.isShown {
            closeAndCleanup()
            return
        }
        
        guard let parentWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            print("Error: Could not find any active application window.")
            return
        }
        guard let parentContentView = parentWindow.contentView else { return }

        let windowHeight = parentContentView.bounds.height
        let adjustedY = windowHeight - CGFloat(y)
        let targetRect = NSRect(x: CGFloat(x), y: adjustedY, width: 1, height: 1)

        // 2. Initialize new managed instances
        let popover = NSPopover()
        let controller = WebViewController(url: targetURL, fragment: hashFragment, enableDevTools: enableDevTools)
        
        popover.contentViewController = controller
        popover.behavior = .transient // Automatically closes when clicking outside the window context
        popover.animates = true
        
        // Connect delegate to listen to closure hooks for memory cycling
        popover.delegate = controller
        
        // Hold active references in our singleton instance tracking fields
        self.activePopover = popover
        self.activeController = controller

        popover.show(
            relativeTo: targetRect,
            of: parentContentView,
            preferredEdge: .minY
        )
    }
    
    func closeAndCleanup() {
        guard let popover = activePopover else { return }
        popover.performClose(nil)
        
        // Break references explicitly to ensure ARC frees memory channels instantly
        self.activePopover = nil
        self.activeController = nil
        print("Managed Popover references removed and memory recycled.")
    }
}

@MainActor
class WebViewController: NSViewController, NSPopoverDelegate {
    var targetURL: URL?
    var hashFragment: String?
    var enableDevTools: Bool?
    var webView: WKWebView? // Store local webview reference for teardown procedures

    init(url: URL?, fragment: String?, enableDevTools: Bool?) {
        self.targetURL = url
        self.hashFragment = fragment
        self.enableDevTools = enableDevTools
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // 1. Establish the base view size
        let viewBounds = NSRect(x: 0, y: 0, width: 400, height: 500)
        self.view = NSView(frame: viewBounds)

        // 2. Create the macOS Native Vibrancy Layer (Frosted Glass)
        let visualEffectView = NSVisualEffectView(frame: viewBounds)
        visualEffectView.autoresizingMask = [.width, .height]

        // .popover matches the exact system blur styling of Spotlight and Raycast
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active

        // Add the blur view as the foundation layer
        self.view.addSubview(visualEffectView)

        // 3. Set up the WKWebView Configuration
        let config = WKWebViewConfiguration()

        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        if enableDevTools == true {
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        // 🌟 REGISTER THE JAVASCRIPT SCRIPT MESSAGE HANDLER CHANNEL
        // This injects window.webkit.messageHandlers."tauri" into your React app context
//        config.userContentController.add(self, name: "tauri")

        let wv = WKWebView(frame: viewBounds, configuration: config)
        self.webView = wv // Assign to controller tracking reference
        wv.autoresizingMask = [.width, .height]

        // Disable the default opaque background color channels
        wv.setValue(false, forKey: "drawsBackground") // Disables the default solid canvas drawing
        wv.wantsLayer = true                          // Tells macOS to back this view with a core animation layer
        wv.layer?.backgroundColor = .clear            // Forces the layer channel to be 100% transparent

        // 4. Load the React build assets
        if let url = targetURL {
            if url.isFileURL {
                // Extract the parent directory enclosing your asset chunks (/dist)
                let baseDirectory = url.deletingLastPathComponent()

                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                urlComponents?.fragment = hashFragment
                if let finalRoutedURL = urlComponents?.url {
                    // Load the full compound URL while granting access to the root asset directory
                    wv.loadFileURL(finalRoutedURL, allowingReadAccessTo: baseDirectory)
                    print("🚀 WKWebView successfully routing to local bundle: \(finalRoutedURL.absoluteString)")
                }
            } else {
                // Reconstruct the http://localhost URL with the routing fragment attached!
                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                urlComponents?.fragment = hashFragment

                if let finalDevURL = urlComponents?.url {
                    let request = URLRequest(url: finalDevURL)
                    wv.load(request)
                    print("🌐 WKWebView routing to local dev server: \(finalDevURL.absoluteString)")
                }
            }
        }

        // Stack the transparent webview directly on top of the blur view
        self.view.addSubview(wv)
    }
    
//    // 🌟 CAPTURE INCOMING MESSAGES FROM REACT JAVASCRIPT
//        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//            // Safe context switch back to MainActor
//            Task { @MainActor in
//                // Ensure the message body is a string (like a JSON payload or action ID string)
//                if let actionPayload = message.body as? String {
//                    print("📬 Message captured from JS popover: \(actionPayload)")
//                    
//                    // Fire the action callback directly across the FFI bridge to Rust!
//                    onPopoverAction?(SRString.from(actionPayload))
//                }
//            }
//        }

    // Triggers when the user clicks out or the popover is programmatically closed
    nonisolated func popoverDidClose(_ notification: Notification) {
        // Since delegate callbacks can be nonisolated, explicitly hop back to the MainActor
        Task { @MainActor in
            webView?.load(URLRequest(url: URL(string: "about:blank")!))
            webView?.removeFromSuperview()
            webView = nil
            
            // Empty out the global tracking container references to prevent memory leaks
            PopoverManager.shared.activePopover = nil
            PopoverManager.shared.activeController = nil
        }
    }
}

@_cdecl("show_webview_popover")
public func showWebviewPopover(url: SRString, x: Double, y: Double, enableDevTools: Bool) {
    let urlString = url.toString()

    let parts = urlString.components(separatedBy: "#")
    let baseUrlString = parts[0]
    let hashFragment = parts.count > 1 ? parts[1] : nil

    guard let targetURL = URL(string: baseUrlString) else { return }

    // DispatchQueue.main.async natively targets the MainActor execution lane
    DispatchQueue.main.async {
        // Funnel cleanly into our unified lifecycle singleton manager!
        PopoverManager.shared.showOrToggle(
            targetURL: targetURL,
            hashFragment: hashFragment,
            enableDevTools: enableDevTools,
            x: x,
            y: y
        )
    }
}


//// 🌟 GLOBAL FUNCTION POINTER FOR RUST CALLBACKS
//// This holds the reference to the Rust function that will receive the actions.
//typealias PopoverActionCallback = @convention(c) (SRString) -> Void
//private var onPopoverAction: PopoverActionCallback? = nil
//
//@_cdecl("register_popover_action_callback")
//public func registerPopoverActionCallback(callback: @escaping PopoverActionCallback) {
//    onPopoverAction = callback
//}
