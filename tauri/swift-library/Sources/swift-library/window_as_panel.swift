import Cocoa

struct WindowAsPanelSendableWindowPointer: Sendable {
    let address: Int

    var rawPointer: OpaquePointer {
        OpaquePointer(bitPattern: address)!
    }
}

@MainActor
private final class PanelInstanceContainer {
    let panel: HoverResponsivePanel
    weak var sourceWindow: NSWindow?
    var trackingArea: NSTrackingArea?
    
    init(panel: HoverResponsivePanel, sourceWindow: NSWindow? = nil, trackingArea: NSTrackingArea? = nil) {
        self.panel = panel
        self.sourceWindow = sourceWindow
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
            if let parentPanel = window.parent as? NSPanel {
                parentPanel.performDrag(with: event)
            } else {
                window.performDrag(with: event)
            }
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

        if let parent = sourceWindow.parent {
            parent.removeChildWindow(sourceWindow)
        }

        guard let primaryScreen = sourceWindow.screen ?? NSScreen.main else { return }
        let screenFrame = primaryScreen.frame
        let targetSize = sourceWindow.frame.size

        let panelX = screenFrame.origin.x + CGFloat(x)
        let panelY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height

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

        let handleHeight: CGFloat = 16.0
        let dragHandle = SwiftDragHandleView()
        dragHandle.frame = NSRect(x: 0, y: targetSize.height - handleHeight, width: targetSize.width, height: handleHeight)
        dragHandle.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(dragHandle)

        containerView.addSubview(visualEffectView)
        panel.contentView = containerView

        sourceWindow.styleMask = [.borderless]
        sourceWindow.isOpaque = false
        sourceWindow.backgroundColor = .clear
        sourceWindow.hasShadow = false
        
        sourceWindow.setFrame(NSRect(x: panelX, y: panelY, width: targetSize.width, height: targetSize.height - handleHeight), display: true)

        panel.addChildWindow(sourceWindow, ordered: .above)
        
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
            container.sourceWindow = sourceWindow
            container.trackingArea = trackingArea
        }
        
        WindowAsPanelPanelStorage.isCleaningUp = false
        
        window_as_panel_event(.Opened(panel_id: RustString(id))) // notify rust
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
        
        if let sourceWindow = container.sourceWindow {
            let handleHeight: CGFloat = 16.0
            sourceWindow.setFrame(NSRect(x: panelX, y: panelY, width: targetSize.width, height: targetSize.height - handleHeight), display: true)
        }
    }

    private func clearPanelContents(for id: String) {
        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        let panel = container.panel
        
        if let sourceWindow = container.sourceWindow {
            panel.removeChildWindow(sourceWindow)
            sourceWindow.orderOut(nil)
        }
        
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
        
        window_as_panel_event(.Closed(panel_id: RustString(id))) // notify rust
        
    }
}

public func showWindowAsPanel(id: RustString, windowRawPtr: UnsafeMutableRawPointer?, x: Double, y: Double) {
    let idStr = id.toString()
    let ptrInt = Int(bitPattern: windowRawPtr)
    let sendableContainer = WindowAsPanelSendableWindowPointer(address: ptrInt)

    DispatchQueue.main.async {
        WindowAsPanelManager.shared.show(id: idStr, sendablePtr: sendableContainer, x: x, y: y)
    }
}

public func moveWindowAsPanel(id: RustString, x: Double, y: Double) {
    let idStr = id.toString()
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.movePanel(id: idStr, x: x, y: y)
    }
}

public func closeWindowAsPanel(id: RustString) {
    let idStr = id.toString()
        
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.closePanel(id: idStr)
    }
}

public func isWindowAsPanelVisible(id: RustString) -> Bool {
    let idStr = id.toString()
    
    if Thread.isMainThread {
        return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
        }
    }
}

//
//import Cocoa
//
//struct WindowAsPanelSendableWindowPointer: Sendable {
//    let address: Int
//
//    var rawPointer: OpaquePointer {
//        OpaquePointer(bitPattern: address)!
//    }
//}
//
//@MainActor
//private final class PanelInstanceContainer {
//    let panel: HoverResponsivePanel
//    weak var sourceWindow: NSWindow?
//    var trackingArea: NSTrackingArea?
//    
//    init(panel: HoverResponsivePanel, sourceWindow: NSWindow? = nil, trackingArea: NSTrackingArea? = nil) {
//        self.panel = panel
//        self.sourceWindow = sourceWindow
//        self.trackingArea = trackingArea
//    }
//}
//
//@MainActor
//private final class WindowAsPanelPanelStorage {
//    static var activePanels: [String: PanelInstanceContainer] = [:]
//    static var isCleaningUp = false
//}
//
//class HoverResponsivePanel: NSPanel {
//    // Keep track of its registration ID to emit move coordinates correctly
//    var panelId: String = ""
//    
//    override var canBecomeKey: Bool {
//        return true
//    }
//    
//    override var acceptsMouseMovedEvents: Bool {
//        get { return true }
//        set { }
//    }
//    
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//}
//
//class SwiftDragHandleView: NSView {
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//        
//        let pillWidth: CGFloat = 40.0
//        let pillHeight: CGFloat = 4.0
//        
//        let pillRect = NSRect(
//            x: (bounds.width - pillWidth) / 2.0,
//            y: (bounds.height - pillHeight) / 2.0,
//            width: pillWidth,
//            height: pillHeight
//        )
//        
//        let path = NSBezierPath(roundedRect: pillRect, xRadius: 2.0, yRadius: 2.0)
//        NSColor.secondaryLabelColor.withAlphaComponent(0.4).set()
//        path.fill()
//    }
//    
//    override func mouseDown(with event: NSEvent) {
//        if let window = self.window {
//            if let parentPanel = window.parent as? NSPanel {
//                parentPanel.performDrag(with: event)
//            } else {
//                window.performDrag(with: event)
//            }
//        } else {
//            super.mouseDown(with: event)
//        }
//    }
//    
//    override func resetCursorRects() {
//        super.resetCursorRects()
//        addCursorRect(bounds, cursor: .openHand)
//    }
//}
//
//@MainActor
//class WindowAsPanelManager {
//    static let shared = WindowAsPanelManager()
//
//    private func getOrCreatePanel(for id: String) -> HoverResponsivePanel {
//        if let container = WindowAsPanelPanelStorage.activePanels[id] {
//            return container.panel
//        }
//
//        let panel = HoverResponsivePanel(
//            contentRect: .zero,
//            styleMask: [.borderless, .nonactivatingPanel],
//            backing: .buffered,
//            defer: false
//        )
//        
//        panel.panelId = id
//        panel.isOpaque = false
//        panel.backgroundColor = .clear
//        panel.hasShadow = true
//        panel.ignoresMouseEvents = false
//        panel.isReleasedWhenClosed = false
//        panel.isMovableByWindowBackground = false
//        
//        panel.hidesOnDeactivate = false
//        panel.level = .statusBar
//
//        panel.collectionBehavior = [
//            .canJoinAllSpaces,
//            .ignoresCycle,
//            .stationary
//        ]
//        
//        // 🛠️ Setup observer to listen to drag positions updates natively
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handlePanelMovedNotification(_:)),
//            name: NSWindow.didMoveNotification,
//            object: panel
//        )
//
//        let newContainer = PanelInstanceContainer(panel: panel)
//        WindowAsPanelPanelStorage.activePanels[id] = newContainer
//        return panel
//    }
//
//    func show(id: String, sendablePtr: WindowAsPanelSendableWindowPointer, x: Double, y: Double) {
//        if WindowAsPanelPanelStorage.activePanels[id] != nil {
//            clearPanelContents(for: id)
//        }
//        
//        let panel = getOrCreatePanel(for: id)
//
//        let rawUnsafe = UnsafeMutableRawPointer(sendablePtr.rawPointer)
//        let sourceWindow = Unmanaged<NSWindow>.fromOpaque(rawUnsafe).takeUnretainedValue()
//
//        if let parent = sourceWindow.parent {
//            parent.removeChildWindow(sourceWindow)
//        }
//
//        guard let primaryScreen = sourceWindow.screen ?? NSScreen.main else { return }
//        let screenFrame = primaryScreen.frame
//        let targetSize = sourceWindow.frame.size
//
//        let panelX = screenFrame.origin.x + CGFloat(x)
//        let panelY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height
//
//        let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
//        panel.setFrame(panelRect, display: true, animate: false)
//
//        let customCornerRadius: CGFloat = 20.0
//
//        let containerView = NSView(frame: NSRect(origin: .zero, size: targetSize))
//        containerView.autoresizingMask = [.width, .height]
//
//        let visualEffectView = NSVisualEffectView()
//        visualEffectView.frame = containerView.bounds
//        visualEffectView.autoresizingMask = [.width, .height]
//        
//        visualEffectView.wantsLayer = true
//        visualEffectView.layer?.masksToBounds = true
//        visualEffectView.layer?.cornerRadius = customCornerRadius
//        visualEffectView.material = .popover
//        visualEffectView.blendingMode = .withinWindow
//        visualEffectView.state = .active
//
//        let handleHeight: CGFloat = 16.0
//        let dragHandle = SwiftDragHandleView()
//        dragHandle.frame = NSRect(x: 0, y: targetSize.height - handleHeight, width: targetSize.width, height: handleHeight)
//        dragHandle.autoresizingMask = [.width, .minYMargin]
//        visualEffectView.addSubview(dragHandle)
//
//        containerView.addSubview(visualEffectView)
//        panel.contentView = containerView
//
//        sourceWindow.styleMask = [.borderless]
//        sourceWindow.isOpaque = false
//        sourceWindow.backgroundColor = .clear
//        sourceWindow.hasShadow = false
//        
//        sourceWindow.setFrame(NSRect(x: panelX, y: panelY, width: targetSize.width, height: targetSize.height - handleHeight), display: true)
//
//        panel.addChildWindow(sourceWindow, ordered: .above)
//        
//        WindowAsPanelPanelStorage.isCleaningUp = false
//
//        panel.orderFrontRegardless()
//        panel.makeKey()
//        panel.invalidateShadow()
//        
//        let trackingArea = NSTrackingArea(
//            rect: containerView.bounds,
//            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
//            owner: containerView,
//            userInfo: nil
//        )
//        containerView.addTrackingArea(trackingArea)
//        
//        if let container = WindowAsPanelPanelStorage.activePanels[id] {
//            container.sourceWindow = sourceWindow
//            container.trackingArea = trackingArea
//        }
//        
//        WindowAsPanelPanelStorage.isCleaningUp = false
//        
//        // 🔔 Event 1: Fire Opened back to Rust
//        window_as_panel_event(.Opened(panel_id: RustString(id)))
//    }
//
//    func movePanel(id: String, x: Double, y: Double) {
//        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
//        let panel = container.panel
//        
//        guard let primaryScreen = panel.screen ?? NSScreen.main else { return }
//        let screenFrame = primaryScreen.frame
//        let targetSize = panel.frame.size
//        
//        let panelX = screenFrame.origin.x + CGFloat(x)
//        let panelY = screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height
//        
//        let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
//        
//        // Temporarily turn off standard notifications while moving programmatically
//        // to prevent infinite loops or redundant event echoes.
//        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
//        panel.setFrame(panelRect, display: true, animate: false)
//        NotificationCenter.default.addObserver(self, selector: #selector(handlePanelMovedNotification(_:)), name: NSWindow.didMoveNotification, object: panel)
//        
//        if let sourceWindow = container.sourceWindow {
//            let handleHeight: CGFloat = 16.0
//            sourceWindow.setFrame(NSRect(x: panelX, y: panelY, width: targetSize.width, height: targetSize.height - handleHeight), display: true)
//        }
//    }
//
//    @objc private func handlePanelMovedNotification(_ notification: Notification) {
//        guard let panel = notification.object as? HoverResponsivePanel else { return }
//        let id = panel.panelId
//        
//        guard let primaryScreen = panel.screen ?? NSScreen.main else { return }
//        let screenFrame = primaryScreen.frame
//        let panelFrame = panel.frame
//        
//        // Convert screen coordinates back into Tauri's expected logical workspace bounds
//        let tauriX = Double(panelFrame.origin.x - screenFrame.origin.x)
//        let tauriY = Double(screenFrame.size.height - (panelFrame.origin.y - screenFrame.origin.y) - panelFrame.size.height)
//        
//        // 🔔 Event 3: Fire Moved back to Rust
//        window_as_panel_event(.Moved(panel_id: RustString(id), x: tauriX, y: tauriY))
//    }
//
//    private func clearPanelContents(for id: String) {
//        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
//        let panel = container.panel
//        
//        if let sourceWindow = container.sourceWindow {
//            panel.removeChildWindow(sourceWindow)
//            sourceWindow.orderOut(nil)
//        }
//        
//        if let content = panel.contentView {
//            if let tracking = container.trackingArea {
//                content.removeTrackingArea(tracking)
//                container.trackingArea = nil
//            }
//            for subview in content.subviews {
//                subview.removeFromSuperview()
//            }
//        }
//        panel.contentView = nil
//    }
//
//    func closePanel(id: String) {
//        guard !WindowAsPanelPanelStorage.isCleaningUp,
//              let container = WindowAsPanelPanelStorage.activePanels[id],
//              container.panel.isVisible
//        else { return }
//
//        WindowAsPanelPanelStorage.isCleaningUp = true
//        
//        let panel = container.panel
//        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
//        panel.orderOut(nil)
//        
//        clearPanelContents(for: id)
//        
//        WindowAsPanelPanelStorage.activePanels.removeValue(forKey: id)
//        WindowAsPanelPanelStorage.isCleaningUp = false
//        
//        // 🔔 Event 2: Fire Closed back to Rust
//        window_as_panel_event(.Closed(panel_id: RustString(id)))
//    }
//}
//
//public func showWindowAsPanel(id: RustString, windowRawPtr: UnsafeMutableRawPointer?, x: Double, y: Double) {
//    let idStr = id.toString()
//    let ptrInt = Int(bitPattern: windowRawPtr)
//    let sendableContainer = WindowAsPanelSendableWindowPointer(address: ptrInt)
//
//    DispatchQueue.main.async {
//        WindowAsPanelManager.shared.show(id: idStr, sendablePtr: sendableContainer, x: x, y: y)
//    }
//}
//
//public func moveWindowAsPanel(id: RustString, x: Double, y: Double) {
//    let idStr = id.toString()
//    DispatchQueue.main.async {
//        WindowAsPanelManager.shared.movePanel(id: idStr, x: x, y: y)
//    }
//}
//
//public func closeWindowAsPanel(id: RustString) {
//    let idStr = id.toString()
//        
//    DispatchQueue.main.async {
//        WindowAsPanelManager.shared.closePanel(id: idStr)
//    }
//}
//
//public func isWindowAsPanelVisible(id: RustString) -> Bool {
//    let idStr = id.toString()
//    
//    if Thread.isMainThread {
//        return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
//    } else {
//        return DispatchQueue.main.sync {
//            return MainActor.assumeIsolated { WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false }
//        }
//    }
//}
