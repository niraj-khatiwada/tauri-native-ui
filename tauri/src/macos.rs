#[cfg(target_os = "macos")]
use std::{ffi::c_void, ops::Deref};

#[cfg(target_os = "macos")]
use objc2_app_kit::{NSWindow, NSWindowButton};

#[cfg(target_os = "macos")]
use swift_rs::SRString;

#[cfg(target_os = "macos")]
use tauri::WebviewWindow;

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
swift_rs::swift!(fn show_native_popover_bridge(x: f64, y: f64));

#[cfg(target_os = "macos")]
pub fn show_native_popover(x: f64, y: f64) {
    unsafe {
        show_native_popover_bridge(x, y);
    }
}

// native tooltip
#[cfg(target_os = "macos")]
swift_rs::swift!(
    fn show_native_tooltip_bridge(text: SRString, keys_array: SRString, x: f64, y: f64)
);

#[cfg(target_os = "macos")]
pub fn show_native_tooltip(text: &str, hotkeys: Vec<String>, x: f64, y: f64) {
    let keys = hotkeys.deref().join(" ");
    unsafe {
        show_native_tooltip_bridge(SRString::from(text), SRString::from(keys.as_str()), x, y);
    }
}
#[cfg(target_os = "macos")]
swift_rs::swift!(fn close_native_tooltip_bridge());

#[cfg(target_os = "macos")]
pub fn close_native_tooltip() {
    unsafe {
        close_native_tooltip_bridge();
    }
}

// native toast
#[cfg(target_os = "macos")]
swift_rs::swift!(fn show_native_toast_bridge(text: SRString, icon: SRString, icon_hex: SRString, x: f64, y: f64));

#[cfg(target_os = "macos")]
pub fn show_native_toast(
    text: &str,
    icon_string: Option<&str>,
    icon_hex: Option<&str>,
    x: Option<f64>,
    y: Option<f64>,
) {
    unsafe {
        show_native_toast_bridge(
            SRString::from(text),
            SRString::from(icon_string.unwrap_or_default()),
            SRString::from(icon_hex.unwrap_or_default()),
            x.unwrap_or(-1.0),
            y.unwrap_or(-1.0),
        );
    }
}

// show any Tauri window as a popover (NSPopover)
#[cfg(target_os = "macos")]
swift_rs::swift!(fn show_window_as_popover_bridge(window_raw_ptr: *mut c_void, x: f64, y: f64));

#[cfg(target_os = "macos")]
pub fn show_window_as_popover(window: &WebviewWindow, x: f64, y: f64) {
    unsafe {
        let raw_window_ptr = window.ns_window().unwrap() as *mut c_void;
        show_window_as_popover_bridge(raw_window_ptr, x, y);
    }
}

#[cfg(target_os = "macos")]
swift_rs::swift!(fn close_window_as_popover_bridge());

#[cfg(target_os = "macos")]
pub fn close_window_as_popover() {
    unsafe {
        close_window_as_popover_bridge();
    }
}

#[cfg(target_os = "macos")]
swift_rs::swift!(fn is_window_as_popover_visible_bridge() -> bool);

#[cfg(target_os = "macos")]
pub fn is_window_as_popover_visible() -> bool {
    unsafe { is_window_as_popover_visible_bridge() }
}

// show any Tauri window as panel (NSPanel)
#[cfg(target_os = "macos")]
swift_rs::swift!(fn show_window_as_panel_bridge(window_raw_ptr: *mut c_void, x: f64, y: f64));

#[cfg(target_os = "macos")]
pub fn show_window_as_panel(window: &WebviewWindow, x: f64, y: f64) {
    unsafe {
        let raw_window_ptr = window.ns_window().unwrap() as *mut c_void;
        show_window_as_panel_bridge(raw_window_ptr, x, y);
    }
}

#[cfg(target_os = "macos")]
swift_rs::swift!(fn close_window_as_panel_bridge());

#[cfg(target_os = "macos")]
pub fn close_window_as_panel() {
    unsafe {
        close_window_as_panel_bridge();
    }
}

#[cfg(target_os = "macos")]
swift_rs::swift!(fn is_window_as_panel_visible_bridge() -> bool);

#[cfg(target_os = "macos")]
pub fn is_window_as_panel_visible() -> bool {
    unsafe { is_window_as_panel_visible_bridge() }
}
