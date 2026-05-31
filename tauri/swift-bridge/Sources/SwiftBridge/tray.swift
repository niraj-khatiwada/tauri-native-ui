import AppKit
import Foundation
import SwiftRs

@MainActor
private final class PopoverStorage {
    static var popover: NSPopover? = nil
    static var statusButton: NSStatusBarButton? = nil
}

private struct SendablePointers: @unchecked Sendable {
    let window: UnsafeMutableRawPointer
    let button: UnsafeMutableRawPointer
}

@_cdecl("init_tray_popover_manager_bridge")
public func initTrayPopoverManager(
    nsWindowPtr: UnsafeMutableRawPointer,
    nsStatusBarButtonPtr: UnsafeMutableRawPointer,
    isFullSizeContent: Bool
) {
    let containers = SendablePointers(window: nsWindowPtr, button: nsStatusBarButtonPtr)

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

        PopoverStorage.popover = popover
        PopoverStorage.statusButton = button
    }
}

@_cdecl("open_tray_popover_bridge")
public func openTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = PopoverStorage.popover,
            let button = PopoverStorage.statusButton
        else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
}

@_cdecl("close_tray_popover_bridge")
public func closeTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = PopoverStorage.popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

@_cdecl("is_tray_popover_visible_bridge")
public func isTrayPopoverVisible() -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { PopoverStorage.popover?.isShown ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { PopoverStorage.popover?.isShown ?? false }
        }
    }
}

