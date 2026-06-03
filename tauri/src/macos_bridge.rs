use std;
#[cfg(target_os = "macos")]
use std::{ffi::c_void, ops::Deref};

#[cfg(target_os = "macos")]
use objc2_app_kit::{NSWindow, NSWindowButton};

#[cfg(target_os = "macos")]
use tauri::{Manager, WebviewWindow};

#[cfg(target_os = "macos")]
use crate::{domain, TAURI_APP_HANDLE};

#[swift_bridge::bridge]
pub mod ffi {
    #[derive(Debug)]
    enum WindowAsPopoverEventType {
        Opened,
        Closed,
    }

    enum WindowAsPanelEventType {
        Opened { panel_id: String },
        Closed { panel_id: String },
    }

    extern "Rust" {
        fn window_as_popover_event(event_type: WindowAsPopoverEventType);

        fn window_as_panel_event(event_type: WindowAsPanelEventType);
    }

    extern "Swift" {
        // native popover
        fn showNativePopover(x: f64, y: f64);

        // native tooltip
        fn showNativeTooltip(text: String, keysArrayStr: String, x: f64, y: f64);
        fn closeNativeTooltip();

        // native toast
        fn showNativeToast(text: String, icon: String, iconHex: String, x: f64, y: f64);

        // show any Tauri window as a popover
        fn showWindowAsPopover(windowRawPtr: *mut std::ffi::c_void, x: f64, y: f64);
        fn closeWindowAsPopover();
        fn isWindowAsPopoverVisible() -> bool;

        // show any Tauri window as panel
        fn showWindowAsPanel(id: String, windowRawPtr: *mut std::ffi::c_void, x: f64, y: f64);
        fn closeWindowAsPanel(id: String);
        fn isWindowAsPanelVisible(id: String) -> bool;
        fn moveWindowAsPanel(id: String, x: f64, y: f64);

        // haptic
        fn triggerTrackpadHaptic(intensity: f64, sharpness: f64);
    }
}

// Hide the native traffic light buttons
#[cfg(target_os = "macos")]
pub fn hide_traffic_light_buttons(window: &tauri::WebviewWindow<tauri::Wry>) {
    if let Ok(ns_window_ptr) = window.ns_window() {
        unsafe {
            let ns_window = &*(ns_window_ptr as *const NSWindow);

            if let Some(close_btn) = ns_window.standardWindowButton(NSWindowButton::CloseButton) {
                close_btn.setHidden(true);
            }
            if let Some(mini_btn) =
                ns_window.standardWindowButton(NSWindowButton::MiniaturizeButton)
            {
                mini_btn.setHidden(true);
            }
            if let Some(zoom_btn) = ns_window.standardWindowButton(NSWindowButton::ZoomButton) {
                zoom_btn.setHidden(true);
            }
        }
    }
}

// native popover
#[cfg(target_os = "macos")]
pub fn show_native_popover(x: f64, y: f64) {
    ffi::showNativePopover(x, y);
}

// native tooltip
#[cfg(target_os = "macos")]
pub fn show_native_tooltip(text: &str, hotkeys: Vec<String>, x: f64, y: f64) {
    let keys = hotkeys.deref().join(" ");
    ffi::showNativeTooltip(text.to_string(), keys, x, y);
}

#[cfg(target_os = "macos")]
pub fn close_native_tooltip() {
    ffi::closeNativeTooltip();
}

// native toast
#[cfg(target_os = "macos")]
pub fn show_native_toast(
    text: &str,
    icon_string: Option<&str>,
    icon_hex: Option<&str>,
    x: Option<f64>,
    y: Option<f64>,
) {
    ffi::showNativeToast(
        text.to_string(),
        icon_string.unwrap_or_default().to_string(),
        icon_hex.unwrap_or_default().to_string(),
        x.unwrap_or(-1.0),
        y.unwrap_or(-1.0),
    );
}

// show any Tauri window as a popover (NSPopover): we can only have 1 popover at a time
#[cfg(target_os = "macos")]
pub fn show_window_as_popover(window: &WebviewWindow, x: f64, y: f64) {
    if let Ok(ns_window_ptr) = window.ns_window() {
        let raw_window_ptr = ns_window_ptr as *mut c_void;
        ffi::showWindowAsPopover(raw_window_ptr, x, y);
    }
}

#[cfg(target_os = "macos")]
pub fn close_window_as_popover() {
    ffi::closeWindowAsPopover();
}

#[cfg(target_os = "macos")]
pub fn is_window_as_popover_visible() -> bool {
    ffi::isWindowAsPopoverVisible()
}

#[cfg(target_os = "macos")]
fn window_as_popover_event(event_type: ffi::WindowAsPopoverEventType) {
    println!("Window as popover event {:?}", event_type);
    match event_type {
        ffi::WindowAsPopoverEventType::Closed => {
            if let Ok(guard) = TAURI_APP_HANDLE.lock() {
                if let Some(app_handle) = guard.as_ref() {
                    let popover_window_label = domain::AppWindow::Popover.as_str();
                    if let Some(window) = app_handle.get_webview_window(popover_window_label) {
                        let _ = window.destroy();
                    }
                } else {
                    eprintln!("Tauri AppHandle hasn't been initialized in the global state yet!");
                }
            }
        }
        _ => {}
    }
}

// show any Tauri window as panel (NSPanel): we can have multiple panels at a time
#[cfg(target_os = "macos")]
pub fn show_window_as_panel(panel_id: &str, window: &WebviewWindow, x: f64, y: f64) {
    if let Ok(ns_window_ptr) = window.ns_window() {
        let raw_window_ptr = ns_window_ptr as *mut c_void;
        ffi::showWindowAsPanel(panel_id.to_string(), raw_window_ptr, x, y);
    }
}

#[cfg(target_os = "macos")]
pub fn close_window_as_panel(panel_id: &str) {
    ffi::closeWindowAsPanel(panel_id.to_string());
}

#[cfg(target_os = "macos")]
pub fn is_window_as_panel_visible(panel_id: &str) -> bool {
    ffi::isWindowAsPanelVisible(panel_id.to_string())
}

#[cfg(target_os = "macos")]
pub fn move_window_as_panel(panel_id: &str, x: f64, y: f64) {
    ffi::moveWindowAsPanel(panel_id.to_string(), x, y);
}

#[cfg(target_os = "macos")]
fn window_as_panel_event(event_type: ffi::WindowAsPanelEventType) {
    match event_type {
        ffi::WindowAsPanelEventType::Opened { panel_id } => {
            println!("Window as panel event Opened id={}", panel_id);
        }
        ffi::WindowAsPanelEventType::Closed { panel_id } => {
            println!("Window as panel event Closed id={}", panel_id);
            if let Ok(guard) = TAURI_APP_HANDLE.lock() {
                if let Some(app_handle) = guard.as_ref() {
                    let panel_window_label =
                        domain::AppWindow::Panel.get_panel_window_label_by_id(&panel_id);
                    if let Some(window) = app_handle.get_webview_window(&panel_window_label) {
                        let _ = window.destroy();
                    }
                } else {
                    eprintln!("Tauri AppHandle hasn't been initialized in the global state yet!");
                }
            }
        }
        _ => {}
    }
}

// trackpad haptics
#[cfg(target_os = "macos")]
pub fn trigger_trackpad_haptic(intensity: Option<f64>, sharpness: Option<f64>) {
    ffi::triggerTrackpadHaptic(intensity.unwrap_or(0.85), sharpness.unwrap_or(1.0));
}
