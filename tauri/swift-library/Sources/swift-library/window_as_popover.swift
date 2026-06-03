import Cocoa

struct WindowAsPopoverSendableWindowPointer: Sendable {
    let address: Int

    var rawPointer: OpaquePointer {
        OpaquePointer(bitPattern: address)!
    }
}


@MainActor
class WindowAsPopoverManager {
    static let shared = WindowAsPopoverManager()

    public var activePopover: NSPopover?
    private var activeAnchorWindow: NSWindow?

    private var isCleaningUp = false

    func show(sendablePtr: WindowAsPopoverSendableWindowPointer, x: Double, y: Double) {
        self.stopObservingGlobalEvents()
        if let oldAnchor = self.activeAnchorWindow {
                oldAnchor.close()
                self.activeAnchorWindow = nil
        }

        let rawUnsafe = UnsafeMutableRawPointer(sendablePtr.rawPointer)
        let sourceWindow = Unmanaged<NSWindow>.fromOpaque(rawUnsafe).takeUnretainedValue()

        guard let stolenView = sourceWindow.contentView else { return }
        stolenView.wantsLayer = true
        stolenView.layer?.backgroundColor = NSColor.clear.cgColor

        let placeholder = NSView()
        sourceWindow.contentView = placeholder
        sourceWindow.orderOut(nil)

        guard let primaryScreen = sourceWindow.screen ?? NSScreen.main else { return }
        let screenFrame = primaryScreen.frame
        let targetSize = sourceWindow.frame.size

        let windowFrameHeight = sourceWindow.frame.height
        let contentBoundsHeight = stolenView.bounds.height
        let titlebarHeight = windowFrameHeight - contentBoundsHeight

        let anchorX = screenFrame.origin.x + CGFloat(x)
        let anchorY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - titlebarHeight

        let dummyRect = NSRect(x: anchorX, y: anchorY, width: 1.0, height: 1.0)
        let anchorWindow = NSWindow(
            contentRect: dummyRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        anchorWindow.isOpaque = false
        anchorWindow.backgroundColor = .clear
        anchorWindow.alphaValue = 0.0
        anchorWindow.ignoresMouseEvents = true
        anchorWindow.level = .mainMenu + 1
        anchorWindow.orderFrontRegardless()

        let controller = NSViewController()
        controller.view = stolenView

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.contentSize = targetSize

        if let dummyView = anchorWindow.contentView {
            popover.show(relativeTo: dummyView.bounds, of: dummyView, preferredEdge: .minY)
        }

        self.activePopover = popover
        self.activeAnchorWindow = anchorWindow
        self.isCleaningUp = false

        window_as_popover_event(WindowAsPopoverEventType.Opened) // notify rust

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlobalDismissal(_:)),
            name: NSWindow.didMoveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlobalDismissal(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    @objc private func handleGlobalDismissal(_ notification: Notification) {
        guard !isCleaningUp else { return }

        if let window = notification.object as? NSWindow {
            if window == activeAnchorWindow {
                return
            }
        }

        closeActivePopover()
    }

    func closeActivePopover() {
        guard !isCleaningUp else { return }
        isCleaningUp = true

        self.stopObservingGlobalEvents()

        if let popover = activePopover {
            popover.performClose(nil)
        }

        self.activePopover = nil
        self.activeAnchorWindow = nil
        isCleaningUp = false
        
        window_as_popover_event(WindowAsPopoverEventType.Closed) // notify rust
    }

    func isPopoverOpened() -> Bool {
        return activePopover?.isShown ?? false
    }

    private func stopObservingGlobalEvents() {
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.didResignKeyNotification, object: nil)
    }
}

public func showWindowAsPopover(windowRawPtr: UnsafeMutableRawPointer?, x: Double, y: Double) {
    let ptrInt = Int(bitPattern: windowRawPtr)
    let sendableContainer = WindowAsPopoverSendableWindowPointer(address: ptrInt)

    DispatchQueue.main.async {
        WindowAsPopoverManager.shared.show(sendablePtr: sendableContainer, x: x, y: y)
    }
}

public func closeWindowAsPopover() {
    DispatchQueue.main.async {
        WindowAsPopoverManager.shared.closeActivePopover()
    }
}

public func isWindowAsPopoverVisible() -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { WindowAsPopoverManager.shared.isPopoverOpened() }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { WindowAsPopoverManager.shared.isPopoverOpened() }
        }
    }
}
