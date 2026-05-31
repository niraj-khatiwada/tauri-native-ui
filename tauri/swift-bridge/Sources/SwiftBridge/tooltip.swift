import Cocoa
import SwiftRs

@MainActor
class TooltipManager {
    static let shared = TooltipManager()

    var activePanel: NSPanel?
    var activeController: TooltipViewController?

    func show(text: String, keys: [String], minX: Double, minY: Double) {
        if let panel = activePanel, let controller = activeController {
            controller.updateContent(text: text, keys: keys)
            repositionPanel(panel, minX: minX, minY: minY)
            return
        }

        guard
            let parentWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
        else { return }
        let controller = TooltipViewController(text: text, keys: keys)
        let requiredSize = controller.view.fittingSize

        let finalRect = calculatePanelFrame(
            parentWindow: parentWindow, size: requiredSize, minX: minX, minY: minY)

        let panel = NSPanel(
            contentRect: finalRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentViewController = controller

        self.activePanel = panel
        self.activeController = controller

        panel.orderFrontRegardless()
    }

    func hide() {
        activePanel?.close()
        activePanel = nil
        activeController = nil
    }

    private func repositionPanel(_ panel: NSPanel, minX: Double, minY: Double) {
        guard
            let parentWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first,
            let controller = activeController
        else { return }

        let requiredSize = controller.view.fittingSize
        let finalRect = calculatePanelFrame(
            parentWindow: parentWindow, size: requiredSize, minX: minX, minY: minY)

        panel.setFrame(finalRect, display: true, animate: false)
    }

    private func calculatePanelFrame(
        parentWindow: NSWindow, size: NSSize, minX: Double, minY: Double
    ) -> NSRect {
        let windowFrame = parentWindow.frame

        let contentHeight = parentWindow.contentView?.bounds.height ?? windowFrame.height
        let titlebarHeight = windowFrame.height - contentHeight

        let componentScreenX = windowFrame.origin.x + CGFloat(minX)
        let componentScreenY =
            (windowFrame.origin.y + windowFrame.height) - CGFloat(minY) - titlebarHeight

        var panelX = componentScreenX - (size.width / 2)
        var panelY = componentScreenY + 12

        let activeScreen = parentWindow.screen ?? NSScreen.main
        if let screen = activeScreen {
            let safeBounds = screen.visibleFrame

            if panelX < safeBounds.origin.x {
                panelX = safeBounds.origin.x + 8
            } else if panelX + size.width > safeBounds.origin.x + safeBounds.size.width {
                panelX = (safeBounds.origin.x + safeBounds.size.width) - size.width - 8
            }

            if panelY + size.height > safeBounds.origin.y + safeBounds.size.height {
                panelY = componentScreenY - size.height - 12
            } else if panelY < safeBounds.origin.y {
                panelY = safeBounds.origin.y + 8
            }
        }

        return NSRect(origin: NSPoint(x: panelX, y: panelY), size: size)
    }
}

@MainActor
class TooltipViewController: NSViewController {
    private var text: String
    private var keys: [String]

    private let stackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var keycapViews: [NSView] = []

    init(text: String, keys: [String]) {
        self.text = text
        self.keys = keys
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 9.0
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.1).cgColor

        container.addSubview(visualEffect)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        stackView.heightAnchor.constraint(equalToConstant: 30.0).isActive = true

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.95, alpha: 1.0)
        stackView.addArrangedSubview(titleLabel)

        self.view = container

        buildContent()
    }

    func updateContent(text: String, keys: [String]) {
        self.text = text
        self.keys = keys
        buildContent()
    }

    private func buildContent() {
        titleLabel.stringValue = text

        for view in keycapViews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        keycapViews.removeAll()

        for key in keys where !key.isEmpty {
            let capContainer = NSView()
            capContainer.translatesAutoresizingMaskIntoConstraints = false
            capContainer.wantsLayer = true
            capContainer.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
            capContainer.layer?.cornerRadius = 5.0

            let capLabel = NSTextField(labelWithString: key)
            capLabel.translatesAutoresizingMaskIntoConstraints = false
            capLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            capLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
            capLabel.alignment = .center

            capContainer.addSubview(capLabel)

            NSLayoutConstraint.activate([
                capLabel.topAnchor.constraint(equalTo: capContainer.topAnchor, constant: 2),
                capLabel.bottomAnchor.constraint(equalTo: capContainer.bottomAnchor, constant: -2),
                capLabel.leadingAnchor.constraint(equalTo: capContainer.leadingAnchor, constant: 5),
                capLabel.trailingAnchor.constraint(
                    equalTo: capContainer.trailingAnchor, constant: -5),
                capContainer.heightAnchor.constraint(equalToConstant: 18),
            ])

            stackView.addArrangedSubview(capContainer)
            keycapViews.append(capContainer)
        }
    }
}

@_cdecl("show_native_tooltip_bridge")
public func showNativeTooltip(text: SRString, keysArrayStr: SRString, minX: Double, minY: Double) {
    let textStr = text.toString()
    let keysList = keysArrayStr.toString().components(separatedBy: " ")

    DispatchQueue.main.async {
        TooltipManager.shared.show(
            text: textStr,
            keys: keysList,
            minX: minX,
            minY: minY
        )
    }
}

@_cdecl("close_native_tooltip_bridge")
public func closeNativeTooltip() {
    DispatchQueue.main.async {
        TooltipManager.shared.hide()
    }
}
