import Cocoa
import SwiftRs

@MainActor
class NativeToastManager {
    static let shared = NativeToastManager()
    
    private var activePanel: NSPanel?
    private var activeController: ToastViewController?
    private var autoHideTimer: Timer?

    func show(text: String, iconName: String?, iconHex: String?) {
        autoHideTimer?.invalidate()
        if let existingPanel = activePanel {
            existingPanel.close()
        }

        guard let primaryScreen = NSScreen.main else { return }
        let screenFrame = primaryScreen.visibleFrame
        
        let controller = ToastViewController(text: text, iconName: iconName, iconHex: iconHex)
        let requiredSize = controller.view.fittingSize
        
        let panelX = screenFrame.origin.x + (screenFrame.width - requiredSize.width) / 2
        let panelY = screenFrame.origin.y + 100
        let targetRect = NSRect(x: panelX, y: panelY, width: requiredSize.width, height: requiredSize.height)

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
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissWithAnimation()
            }
        }
    }
    
    private func dismissWithAnimation() {
        guard let panel = activePanel else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
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
            
            stackView.heightAnchor.constraint(equalToConstant: 42.0)
        ])
        
        if let icon = iconName, !icon.isEmpty {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let nsImage = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let imageView = NSImageView(image: nsImage)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                
                let tintedColor = NSColor.fromHex(iconHex ?? "", maxAlpha: 1.0) ?? .white
                imageView.contentTintColor = tintedColor
                
                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16)
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

@_cdecl("show_native_toast")
public func showNativeToast(text: SRString, icon: SRString, iconHex: SRString) {
    let textStr = text.toString()
    let iconStr = icon.toString()
    let iconHexStr = iconHex.toString()
    
    let optionalIcon = iconStr.isEmpty ? nil : iconStr
    let optionalIconHex = iconHexStr.isEmpty ? nil : iconHexStr
    
    DispatchQueue.main.async {
        NativeToastManager.shared.show(
            text: textStr,
            iconName: optionalIcon,
            iconHex: optionalIconHex
        )
    }
}
