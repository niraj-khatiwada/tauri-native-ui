import Cocoa
import SwiftRs

struct WindowAsPanelSendableWindowPointer: Sendable {
    let address: Int

    var rawPointer: OpaquePointer {
        OpaquePointer(bitPattern: address)!
    }
}

@MainActor
private final class PanelInstanceContainer {
    let panel: HoverResponsivePanel
    var trackingArea: NSTrackingArea?
    
    init(panel: HoverResponsivePanel, trackingArea: NSTrackingArea? = nil) {
        self.panel = panel
        self.trackingArea = trackingArea
    }
}

@MainActor
private final class WindowAsPanelPanelStorage {
    static var activePanels: [String: PanelInstanceContainer] = [:]
    static var isCleaningUp = false
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

    private func getOrCreatePanel(for id: String) -> HoverResponsivePanel {
        if let container = WindowAsPanelPanelStorage.activePanels[id] {
            return container.panel
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

        let newContainer = PanelInstanceContainer(panel: panel)
        WindowAsPanelPanelStorage.activePanels[id] = newContainer
        return panel
    }

    func show(id: String, sendablePtr: WindowAsPanelSendableWindowPointer, x: Double, y: Double) {
        if WindowAsPanelPanelStorage.activePanels[id] != nil {
            clearPanelContents(for: id)
        }
        
        let panel = getOrCreatePanel(for: id)

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

        let containerView = NSView(frame: NSRect(origin: .zero, size: targetSize))
        containerView.autoresizingMask = [.width, .height]

        let visualEffectView = NSVisualEffectView()
        visualEffectView.frame = containerView.bounds
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

        visualEffectView.addSubview(stolenView)
        
        let handleHeight: CGFloat = 16.0
        let dragHandle = SwiftDragHandleView()
        dragHandle.frame = NSRect(x: 0, y: targetSize.height - handleHeight, width: targetSize.width, height: handleHeight)
        dragHandle.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(dragHandle)

        containerView.addSubview(visualEffectView)
        panel.contentView = containerView
        
        WindowAsPanelPanelStorage.isCleaningUp = false

        panel.orderFrontRegardless()
        panel.makeKey()
        
        panel.invalidateShadow()
        
        let trackingArea = NSTrackingArea(
            rect: containerView.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: containerView,
            userInfo: nil
        )
        containerView.addTrackingArea(trackingArea)
        
        if let container = WindowAsPanelPanelStorage.activePanels[id] {
            container.trackingArea = trackingArea
        }
        
        WindowAsPanelPanelStorage.isCleaningUp = false
    }

    func movePanel(id: String, x: Double, y: Double) {
        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        let panel = container.panel
        
        guard let primaryScreen = panel.screen ?? NSScreen.main else { return }
        let screenFrame = primaryScreen.frame
        let targetSize = panel.frame.size
        
        let panelX = screenFrame.origin.x + CGFloat(x)
        let panelY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height
        
        let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
        panel.setFrame(panelRect, display: true, animate: false)
    }

    private func clearPanelContents(for id: String) {
        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        let panel = container.panel
        
        if let content = panel.contentView {
            if let tracking = container.trackingArea {
                content.removeTrackingArea(tracking)
                container.trackingArea = nil
            }
            
            for subview in content.subviews {
                subview.removeFromSuperview()
            }
        }
        panel.contentView = nil
    }

    func closePanel(id: String) {
        guard !WindowAsPanelPanelStorage.isCleaningUp,
              let container = WindowAsPanelPanelStorage.activePanels[id],
              container.panel.isVisible
        else { return }

        WindowAsPanelPanelStorage.isCleaningUp = true
        
        let panel = container.panel
        panel.orderOut(nil)
        
        clearPanelContents(for: id)
        
        WindowAsPanelPanelStorage.activePanels.removeValue(forKey: id)
        
        WindowAsPanelPanelStorage.isCleaningUp = false
    }
}

@_cdecl("show_window_as_panel_bridge")
public func showWindowAsPanel(id: SRString, windowRawPtr: OpaquePointer, x: Double, y: Double) {
    let idStr = id.toString()
    let ptrInt = Int(bitPattern: windowRawPtr)
    let sendableContainer = WindowAsPanelSendableWindowPointer(address: ptrInt)

    DispatchQueue.main.async {
        WindowAsPanelManager.shared.show(id: idStr, sendablePtr: sendableContainer, x: x, y: y)
    }
}

@_cdecl("move_window_as_panel_bridge")
public func moveWindowAsPanel(id: SRString, x: Double, y: Double) {
    let idStr = id.toString()
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.movePanel(id: idStr, x: x, y: y)
    }
}

@_cdecl("close_window_as_panel_bridge")
public func closeWindowAsPanel(id: SRString) {
    let idStr = id.toString()
        
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.closePanel(id: idStr)
    }
}

@_cdecl("is_window_as_panel_visible_bridge")
public func isWindowAsPanelVisible(id: SRString) -> Bool {
    let idStr = id.toString()
    
    if Thread.isMainThread {
        return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
        }
    }
}
