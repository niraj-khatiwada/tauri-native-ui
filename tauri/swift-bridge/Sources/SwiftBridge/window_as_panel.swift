import Cocoa
import SwiftRs

struct WindowAsPanelSendableWindowPointer: Sendable {
    let address: Int

    var rawPointer: OpaquePointer {
        OpaquePointer(bitPattern: address)!
    }
}

@MainActor
private final class WindowAsPanelPanelStorage {
    static var sharedPanel: NSPanel? = nil
    static var isCleaningUp = false
    static var activeTrackingArea: NSTrackingArea? = nil
}

class HoverResponsivePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var acceptsMouseMovedEvents: Bool {
        get { return true }
        set { }
    }
}

class SwiftDragHandleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let pillWidth: CGFloat = 40.0
        let pillHeight: CGFloat = 4.0
        
        let pillRect = NSRect(
            x: (bounds.width - pillWidth) / 2.0,
            y: (bounds.height - pillHeight) / 2.0,
            width: pillWidth,
            height: pillHeight
        )
        
        let path = NSBezierPath(roundedRect: pillRect, xRadius: 2.0, yRadius: 2.0)
        NSColor.secondaryLabelColor.withAlphaComponent(0.4).set()
        path.fill()
    }
    
    override func mouseDown(with event: NSEvent) {
        if let window = self.window {
            window.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}

@MainActor
class WindowAsPanelManager {
    static let shared = WindowAsPanelManager()

    private func getOrCreatePanel() -> NSPanel {
        if let existingPanel = WindowAsPanelPanelStorage.sharedPanel {
            return existingPanel
        }

        let panel = HoverResponsivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        
        panel.hidesOnDeactivate = false
        panel.level = .statusBar

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .stationary
        ]

        WindowAsPanelPanelStorage.sharedPanel = panel
        return panel
    }

    func show(sendablePtr: WindowAsPanelSendableWindowPointer, x: Double, y: Double) {
        if WindowAsPanelPanelStorage.sharedPanel != nil {
            clearCurrentPanelContents()
        }
        
        let panel = getOrCreatePanel()

        let rawUnsafe = UnsafeMutableRawPointer(sendablePtr.rawPointer)
        let sourceWindow = Unmanaged<NSWindow>.fromOpaque(rawUnsafe).takeUnretainedValue()

        guard let stolenView = sourceWindow.contentView else { return }
        
        if let parent = sourceWindow.parent {
            parent.removeChildWindow(sourceWindow)
        }

        let placeholder = NSView()
        sourceWindow.contentView = placeholder
        sourceWindow.orderOut(nil)

        guard let primaryScreen = sourceWindow.screen ?? NSScreen.main else { return }
        let screenFrame = primaryScreen.frame
        let targetSize = sourceWindow.frame.size

        let windowFrameHeight = sourceWindow.frame.height
        let contentBoundsHeight = stolenView.bounds.height
        let titlebarHeight = windowFrameHeight - contentBoundsHeight

        let panelX = screenFrame.origin.x + CGFloat(x)
        let panelY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height - titlebarHeight

        let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
        panel.setFrame(panelRect, display: true, animate: false)

        let customCornerRadius: CGFloat = 20.0

        let visualEffectView = NSVisualEffectView()
        visualEffectView.frame = NSRect(origin: .zero, size: targetSize)
        visualEffectView.autoresizingMask = [.width, .height]
        
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.cornerRadius = customCornerRadius
        
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active

        stolenView.frame = visualEffectView.bounds
        stolenView.autoresizingMask = [.width, .height]
        stolenView.wantsLayer = true
        stolenView.layer?.backgroundColor = NSColor.clear.cgColor
        stolenView.layer?.cornerRadius = customCornerRadius
        stolenView.layer?.masksToBounds = true

        visualEffectView.addSubview(stolenView)
        
        let handleHeight: CGFloat = 16.0
        let dragHandle = SwiftDragHandleView()
        dragHandle.frame = NSRect(x: 0, y: targetSize.height - handleHeight, width: targetSize.width, height: handleHeight)
        dragHandle.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(dragHandle)

        panel.contentView = visualEffectView
        WindowAsPanelPanelStorage.isCleaningUp = false

        panel.orderFrontRegardless()
        panel.makeKey()
        
        if let frameView = panel.contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.isOpaque = false
            frameView.layer?.backgroundColor = NSColor.clear.cgColor
            
            let maskLayer = CAShapeLayer()
            let path = CGPath(
                roundedRect: CGRect(origin: .zero, size: targetSize),
                cornerWidth: customCornerRadius,
                cornerHeight: customCornerRadius,
                transform: nil
            )
            maskLayer.path = path
            
            frameView.layer?.mask = maskLayer
            frameView.layer?.masksToBounds = true
        }
        
        panel.invalidateShadow()
        
        let trackingArea = NSTrackingArea(
            rect: visualEffectView.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: visualEffectView,
            userInfo: nil
        )
        visualEffectView.addTrackingArea(trackingArea)
        WindowAsPanelPanelStorage.activeTrackingArea = trackingArea
        
        WindowAsPanelPanelStorage.isCleaningUp = false
    }

    private func clearCurrentPanelContents() {
        guard let panel = WindowAsPanelPanelStorage.sharedPanel else { return }
        
        if let content = panel.contentView {
            if let tracking = WindowAsPanelPanelStorage.activeTrackingArea {
                content.removeTrackingArea(tracking)
                WindowAsPanelPanelStorage.activeTrackingArea = nil
            }
            
            for subview in content.subviews {
                subview.removeFromSuperview()
            }
        }
        panel.contentView = nil
    }

    func closeActivePanel() {
        guard !WindowAsPanelPanelStorage.isCleaningUp,
              let panel = WindowAsPanelPanelStorage.sharedPanel,
              panel.isVisible
        else { return }

        WindowAsPanelPanelStorage.isCleaningUp = true
        panel.orderOut(nil)
        
        clearCurrentPanelContents()
        
        WindowAsPanelPanelStorage.isCleaningUp = false
    }
}

@_cdecl("show_window_as_panel_bridge")
public func showWindowAsPanel(windowRawPtr: OpaquePointer, x: Double, y: Double) {
    let ptrInt = Int(bitPattern: windowRawPtr)
    let sendableContainer = WindowAsPanelSendableWindowPointer(address: ptrInt)

    DispatchQueue.main.async {
        WindowAsPanelManager.shared.show(sendablePtr: sendableContainer, x: x, y: y)
    }
}

@_cdecl("close_window_as_panel_bridge")
public func closeWindowAsPanel() {
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.closeActivePanel()
    }
}

@_cdecl("is_window_as_panel_visible_bridge")
public func isWindowAsPanelVisible() -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { WindowAsPanelPanelStorage.sharedPanel?.isVisible ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { WindowAsPanelPanelStorage.sharedPanel?.isVisible ?? false }
        }
    }
}
