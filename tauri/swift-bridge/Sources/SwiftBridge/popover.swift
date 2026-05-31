import Cocoa
import SwiftRs

@MainActor
class NativePopoverManager {
    static let shared = NativePopoverManager()
    
    var activePopover: NSPopover?
    var activeController: PopoverContentViewController?

    func showOrToggle(x: Double, y: Double) {
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
        let adjustedX = CGFloat(x)
        let targetRect = NSRect(x: adjustedX, y: adjustedY, width: 1, height: 1)

        let popover = NSPopover()
        let controller = PopoverContentViewController()
        
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        
        popover.delegate = controller
        
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
        
        self.activePopover = nil
        self.activeController = nil
        print(" Managed Native Popover references removed and memory recycled.")
    }
}

@MainActor
class PopoverContentViewController: NSViewController, NSPopoverDelegate {
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

        let label = NSTextField(labelWithString: "⌥ + ⌘ + E")
        label.frame = NSRect(x: 50, y: 40, width: 100, height: 20)
        self.view.addSubview(label)
    }
    
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            // Empty out the global tracking containers to safely wrap up lifecycle
            NativePopoverManager.shared.activePopover = nil
            NativePopoverManager.shared.activeController = nil
        }
    }
}

@_cdecl("show_native_popover")
public func showNativePopover(x: Double, y: Double) {
    DispatchQueue.main.async {
        NativePopoverManager.shared.showOrToggle(x: x, y: y)
    }
}
