use objc2::{msg_send, rc::Retained, runtime::Bool};
use objc2_app_kit::{
    NSBackingStoreType, NSColor, NSMainMenuWindowLevel, NSPanel, NSView, NSViewController,
    NSWindow, NSWindowCollectionBehavior, NSWindowStyleMask,
};
use objc2_foundation::{MainThreadMarker, NSPoint, NSRect, NSSize};

pub struct PanelController {
    panel: Retained<NSPanel>,
}

impl PanelController {
    pub fn new(source_window: &NSWindow, x: f64, y: f64) -> Self {
        let mtm = MainThreadMarker::new().unwrap();

        // 1. Steal the active webview layout from the source window
        let stolen_view = source_window.contentView().unwrap();
        stolen_view.setWantsLayer(true);

        // Put a blank placeholder back into the original window to keep it stable
        let placeholder = unsafe { NSView::new(mtm) };
        source_window.setContentView(Some(&placeholder));

        // 2. Determine layout geometry (match original window's size)
        let source_frame = source_window.frame();
        let target_size = source_frame.size;
        let screen_frame = source_window.screen().unwrap().frame();

        // // Position the floating panel nicely in the top-third of the screen
        // let screen_frame = source_window.screen().unwrap().visibleFrame();
        // let panel_x = screen_frame.origin.x + (screen_frame.size.width - target_size.width) / 2.0;
        // let panel_y =
        //     screen_frame.origin.y + (screen_frame.size.height * 0.7) - (target_size.height / 2.0);
        //
        // 1. The X axis remains completely identical
        let panel_x = screen_frame.origin.x + x;

        // 2. The Y axis must be flipped relative to the screen height boundary,
        // subtracting your window's own height so it anchors from its top-left edge.
        let panel_y = screen_frame.origin.y + (screen_frame.size.height - y) - target_size.height;

        let panel_rect = NSRect::new(
            NSPoint::new(panel_x, panel_y),
            NSSize::new(target_size.width, target_size.height),
        );

        // 3. Configure the Style Masks for a premium floating card experience
        // - NonactivatingPanel: Keeps your main window from taking heavy focus architecture
        // - Borderless: Removes the classic window titlebar, close buttons, and system chrome
        let style_mask = NSWindowStyleMask::Borderless | NSWindowStyleMask::NonactivatingPanel;

        // 4. Allocate and initialize the native NSPanel
        let panel = unsafe {
            NSPanel::initWithContentRect_styleMask_backing_defer(
                mtm.alloc(),
                panel_rect,
                style_mask,
                NSBackingStoreType::Buffered,
                false,
            )
        };

        // 5. Apply Spotlight-style window properties
        panel.setOpaque(false);
        panel.setHasShadow(true);
        panel.setMovableByWindowBackground(true); // Drag it around from anywhere!
        panel.setBackgroundColor(Some(&NSColor::clearColor()));

        // Float above regular windows, menu bars, and full-screen environments
        panel.setLevel(NSMainMenuWindowLevel as isize + 2);

        // Keep it visible across all virtual desktops/spaces
        panel.setCollectionBehavior(
            NSWindowCollectionBehavior::CanJoinAllSpaces
                | NSWindowCollectionBehavior::FullScreenAuxiliary,
        );

        // 6. Wrap the stolen view into a controller and assign it to the panel
        let ctrl = unsafe { NSViewController::new(mtm) };
        ctrl.setView(&stolen_view);
        panel.setContentViewController(Some(ctrl.as_ref()));

        // 7. Render it live to the desktop instantly!
        panel.orderFrontRegardless();

        PanelController { panel }
    }

    pub fn panel(&self) -> Retained<NSPanel> {
        self.panel.clone()
    }

    pub fn close(&self) {
        self.panel.close();
    }
}
