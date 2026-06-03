import Cocoa

@MainActor
class NativeToastManager {
    static let shared = NativeToastManager()

    private var activePanel: NSPanel?
    private var activeController: ToastViewController?
    private var autoHideTimer: Timer?

    func show(text: String, iconName: String?, iconHex: String?, minX: Double?, minY: Double?) {
        autoHideTimer?.invalidate()
        if let existingPanel = activePanel {
            existingPanel.close()
        }

        guard
            let parentWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
        else { return }
        let controller = ToastViewController(text: text, iconName: iconName, iconHex: iconHex)
        let requiredSize = controller.view.fittingSize

        let targetRect: NSRect
        if let x = minX, let y = minY {
            targetRect = calculateToastFrame(
                parentWindow: parentWindow, size: requiredSize, minX: x, minY: y)
        } else {
            targetRect = calculateDefaultToastFrame(size: requiredSize)
        }

        let panel = NSPanel(
            contentRect: targetRect,
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

        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1.0
        }

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                self?.dismissWithAnimation()
            }
        }
    }

    private func calculateDefaultToastFrame(size: NSSize) -> NSRect {
        guard let primaryScreen = NSScreen.main else { return .zero }
        let screenFrame = primaryScreen.visibleFrame

        let panelX = screenFrame.origin.x + (screenFrame.width - size.width) / 2
        let panelY = screenFrame.origin.y + 100

        return NSRect(x: panelX, y: panelY, width: size.width, height: size.height)
    }

    private func calculateToastFrame(
        parentWindow: NSWindow, size: NSSize, minX: Double, minY: Double
    ) -> NSRect {
        let activeScreen = parentWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = activeScreen else { return .zero }

        let screenFrame = screen.frame
        let safeBounds = screen.visibleFrame

        let targetScreenX: CGFloat
        let targetScreenY: CGFloat

        if minX <= 1.0 && minY <= 1.0 {
            targetScreenX = screenFrame.origin.x + (screenFrame.width * CGFloat(minX))
            targetScreenY =
                screenFrame.origin.y + screenFrame.height - (screenFrame.height * CGFloat(minY))
        } else {
            targetScreenX = screenFrame.origin.x + CGFloat(minX)
            targetScreenY = screenFrame.origin.y + screenFrame.height - CGFloat(minY)
        }

        var panelX = targetScreenX - (size.width / 2)
        var panelY = targetScreenY - size.height

        if panelX < safeBounds.origin.x {
            panelX = safeBounds.origin.x + 12
        } else if panelX + size.width > safeBounds.origin.x + safeBounds.size.width {
            panelX = (safeBounds.origin.x + safeBounds.size.width) - size.width - 12
        }

        if panelY < safeBounds.origin.y {
            panelY = safeBounds.origin.y + 12
        } else if panelY + size.height > safeBounds.origin.y + safeBounds.size.height {
            panelY = (safeBounds.origin.y + safeBounds.size.height) - size.height - 12
        }

        return NSRect(origin: NSPoint(x: panelX, y: panelY), size: size)
    }

    private func dismissWithAnimation() {
        guard let panel = activePanel else { return }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0.0
            },
            completionHandler: {
                Task { @MainActor in
                    panel.close()
                    if self.activePanel == panel {
                        self.activePanel = nil
                        self.activeController = nil
                    }
                }
            })
    }
}

@MainActor
class ToastViewController: NSViewController {
    private let text: String
    private let iconName: String?
    private let iconHex: String?

    init(text: String, iconName: String?, iconHex: String?) {
        self.text = text
        self.iconName = iconName
        self.iconHex = iconHex
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
        visualEffect.layer?.cornerRadius = 20.0
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.1).cgColor
        container.addSubview(visualEffect)

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
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

            stackView.heightAnchor.constraint(equalToConstant: 42.0),
        ])

        if let icon = iconName, !icon.isEmpty {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let nsImage = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            {
                let imageView = NSImageView(image: nsImage)
                imageView.translatesAutoresizingMaskIntoConstraints = false

                let tintedColor = NSColor.fromHex(iconHex ?? "", maxAlpha: 1.0) ?? .white
                imageView.contentTintColor = tintedColor

                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                ])
                stackView.addArrangedSubview(imageView)
            }
        }

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(white: 0.95, alpha: 1.0)
        stackView.addArrangedSubview(label)

        self.view = container
    }
}

extension NSColor {
    static func fromHex(_ hex: String, maxAlpha: CGFloat) -> NSColor? {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.remove(at: cleanHex.startIndex) }

        guard cleanHex.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        return NSColor(red: r, green: g, blue: b, alpha: maxAlpha)
    }
}

public func showNativeToast(
    text: RustString, icon: RustString, iconHex: RustString, x: Double, y: Double
) {
    let textStr = text.toString()
    let iconStr = icon.toString()
    let iconHexStr = iconHex.toString()

    let optionalIcon = iconStr.isEmpty ? nil : iconStr
    let optionalIconHex = iconHexStr.isEmpty ? nil : iconHexStr

    let optionalX = (x == -1.0) ? nil : x
    let optionalY = (y == -1.0) ? nil : y

    DispatchQueue.main.async {
        NativeToastManager.shared.show(
            text: textStr,
            iconName: optionalIcon,
            iconHex: optionalIconHex,
            minX: optionalX,
            minY: optionalY
        )
    }
}
