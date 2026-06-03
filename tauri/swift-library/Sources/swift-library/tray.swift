import AppKit
import Foundation

@MainActor
private final class TrayPopoverStorage {
    static var popover: NSPopover? = nil
    static var statusButton: NSStatusBarButton? = nil
}

private struct TraySendablePointers: @unchecked Sendable {
    let window: UnsafeMutableRawPointer
    let button: UnsafeMutableRawPointer
}

public func initTrayPopoverManager(
    nsWindowPtr: UnsafeMutableRawPointer,
    nsStatusBarButtonPtr: UnsafeMutableRawPointer,
    isFullSizeContent: Bool
) {
    let containers = TraySendablePointers(window: nsWindowPtr, button: nsStatusBarButtonPtr)

    DispatchQueue.main.async {
        let window = Unmanaged<NSWindow>.fromOpaque(containers.window).takeUnretainedValue()
        let button = Unmanaged<NSStatusBarButton>.fromOpaque(containers.button)
            .takeUnretainedValue()

        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        let placeholderView = NSView(frame: .zero)
        window.contentView = placeholderView
        window.orderOut(nil)

        let viewController = NSViewController()
        viewController.view = contentView

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = viewController
        popover.contentSize = window.frame.size

        if isFullSizeContent {
            popover.hasFullSizeContent = true
        }

        TrayPopoverStorage.popover = popover
        TrayPopoverStorage.statusButton = button
    }
}

public func openTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = TrayPopoverStorage.popover,
            let button = TrayPopoverStorage.statusButton
        else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
}

public func closeTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = TrayPopoverStorage.popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

public func isTrayPopoverVisible() -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { TrayPopoverStorage.popover?.isShown ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { TrayPopoverStorage.popover?.isShown ?? false }
        }
    }
}

