// use objc2::{msg_send, rc::Retained, runtime::Bool};
// use objc2_app_kit::{NSColor, NSPopover, NSPopoverBehavior, NSView, NSViewController, NSWindow};
// use objc2_foundation::MainThreadMarker;

// pub struct PopoverController {
//     popover: Retained<NSPopover>,
// }

// impl PopoverController {
//     pub fn new(window: &NSWindow, _x: f64, _y: f64) -> Self {
//         let popover = Self::create_popover(window);
//         return PopoverController { popover };
//     }

//     pub fn popover(&self) -> Retained<NSPopover> {
//         self.popover.clone()
//     }

//     fn get_target_view(ns_window: &NSWindow) -> Retained<NSView> {
//         let view = ns_window.contentView().unwrap();
//         view.setWantsLayer(true);
//         unsafe {
//             let color = NSColor::clearColor();
//             let _: () = msg_send![&*view, setBackgroundColor: &*color];
//             let _: () = msg_send![&*view, setOpaque: Bool::YES];
//         }

//         // Replace the window's contentView with an empty placeholder view.
//         let mtm = MainThreadMarker::new().unwrap();
//         // SAFETY: NSView::new is safe to call with a valid MainThreadMarker
//         let placeholder = unsafe { NSView::new(mtm) };
//         ns_window.setContentView(Some(&placeholder));

//         return view;
//     }

//     fn create_popover(window: &NSWindow) -> Retained<NSPopover> {
//         let view = Self::get_target_view(window);
//         unsafe {
//             let mtm = MainThreadMarker::new().unwrap();
//             let ctrl = NSViewController::new(mtm);

//             ctrl.setView(view.as_ref());

//             let popover = NSPopover::new(mtm);
//             popover.setBehavior(NSPopoverBehavior::Transient);
//             popover.setContentViewController(Some(ctrl.as_ref()));
//             let content_size = window.frame().size;
//             popover.setContentSize(content_size);

//             popover
//         }
//     }
// }

use objc2::{msg_send, rc::Retained, runtime::Bool, MainThreadOnly};
use objc2_app_kit::{
    NSBackingStoreType, NSColor, NSPopover, NSPopoverBehavior, NSView, NSViewController, NSWindow,
    NSWindowStyleMask,
};
use objc2_foundation::{MainThreadMarker, NSPoint, NSRect, NSRectEdge, NSSize};

pub struct PopoverController {
    popover: Retained<NSPopover>,
    // 🌟 CRITICAL: We must hold a strong reference to our invisible target
    // window so AppKit doesn't garbage collect it out of memory while active!
    _anchor_window: Retained<NSWindow>,
}

impl PopoverController {
    // 🌟 Coordinates are no longer ignored! They drive the tracking frame placement
    pub fn new(window: &NSWindow, x: f64, y: f64) -> Self {
        let mtm = MainThreadMarker::new().unwrap();

        // 1. Extract and clean up the original Tauri WebView
        let view = Self::get_target_view(window);
        let target_size = window.frame().size;

        // 2. Coordinate System Translation (Flipped Y-Axis Calculation)
        let screen_frame = window.screen().unwrap().frame();
        let anchor_x = screen_frame.origin.x + x;
        // Map top-left Y space down into macOS bottom-left coordinate layout
        let anchor_y = screen_frame.origin.y + (screen_frame.size.height - y);

        // 3. Build a completely borderless 1x1 invisible target frame anchor
        let dummy_rect = NSRect::new(NSPoint::new(anchor_x, anchor_y), NSSize::new(1.0, 1.0));

        let anchor_window: Retained<NSWindow> = unsafe {
            NSWindow::initWithContentRect_styleMask_backing_defer(
                mtm.alloc(),
                dummy_rect,
                NSWindowStyleMask::Borderless,
                NSBackingStoreType::Buffered,
                false,
            )
        };

        // Completely strip any physical trace of the dummy helper window layout
        anchor_window.setOpaque(false);
        anchor_window.setBackgroundColor(Some(&NSColor::clearColor()));
        anchor_window.setAlphaValue(0.0);
        anchor_window.setIgnoresMouseEvents(true);
        anchor_window.setLevel(objc2_app_kit::NSMainMenuWindowLevel as isize + 1);
        anchor_window.orderFrontRegardless();

        // 4. Construct modern Popover and View Hierarchy contexts via raw FFI allocations
        let popover: Retained<NSPopover> = unsafe {
            let ctrl: Retained<NSViewController> = msg_send![NSViewController::alloc(mtm), init];
            ctrl.setView(&view);

            let pop: Retained<NSPopover> = msg_send![NSPopover::alloc(mtm), init];
            pop.setBehavior(NSPopoverBehavior::Transient);
            pop.setContentViewController(Some(ctrl.as_ref()));
            pop.setContentSize(target_size);
            pop
        };

        // 5. Instantly trigger visibility layout anchors pointing to our coordinate point
        unsafe {
            let dummy_view = anchor_window.contentView().unwrap();
            let dummy_bounds = dummy_view.bounds();

            popover.showRelativeToRect_ofView_preferredEdge(
                dummy_bounds,
                &dummy_view,
                NSRectEdge::MinY, // Spawns downward from the pixel coordinate point
            );
        }

        PopoverController {
            popover,
            _anchor_window: anchor_window,
        }
    }

    pub fn popover(&self) -> Retained<NSPopover> {
        self.popover.clone()
    }

    fn get_target_view(ns_window: &NSWindow) -> Retained<NSView> {
        let view = ns_window.contentView().unwrap();
        view.setWantsLayer(true);

        unsafe {
            let color = NSColor::clearColor();
            let _: () = msg_send![&*view, setBackgroundColor: Some(&*color)];
            // 🌟 FIXED: Changed to NO to preserve transparent canvas rendering layers cleanly
            let _: () = msg_send![&*view, setOpaque: Bool::NO];
        }

        // Replace the window's contentView with an empty placeholder view.
        let mtm = MainThreadMarker::new().unwrap();
        let placeholder = unsafe { NSView::new(mtm) };
        ns_window.setContentView(Some(&placeholder));

        view
    }
}
