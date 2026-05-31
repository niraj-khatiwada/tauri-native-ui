#[cfg(target_os = "macos")]
use std::{ffi::c_void, ops::Deref};

#[cfg(target_os = "macos")]
use objc2_app_kit::{NSWindow, NSWindowButton};

#[cfg(target_os = "macos")]
use swift_rs::SRString;

#[cfg(target_os = "macos")]
use tauri::WebviewWindow;

#[cfg(target_os = "macos")]
use crate::swift_bridge::{self};

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

// show native popover
#[cfg(target_os = "macos")]
pub fn show_native_popover(x: f64, y: f64) {
    unsafe {
        swift_bridge::show_native_popover(x, y);
    }
}

// show native popover
#[cfg(target_os = "macos")]
pub fn show_native_tooltip(text: &str, hotkeys: Vec<String>, x: f64, y: f64) {
    let keys = hotkeys.deref().join(" ");
    unsafe {
        swift_bridge::show_native_tooltip(
            SRString::from(text),
            SRString::from(keys.as_str()),
            x,
            y,
        );
    }
}

// close native popover
#[cfg(target_os = "macos")]
pub fn close_native_tooltip() {
    unsafe {
        swift_bridge::close_native_tooltip();
    }
}

// show native toast
#[cfg(target_os = "macos")]
pub fn show_native_toast(
    text: &str,
    icon_string: Option<&str>,
    icon_hex: Option<&str>,
    x: Option<f64>,
    y: Option<f64>,
) {
    unsafe {
        swift_bridge::show_native_toast(
            SRString::from(text),
            SRString::from(icon_string.unwrap_or_default()),
            SRString::from(icon_hex.unwrap_or_default()),
            x.unwrap_or(-1.0),
            y.unwrap_or(-1.0),
        );
    }
}

// show any Tauri window as a popover
#[cfg(target_os = "macos")]
pub fn show_window_as_popover(window: &WebviewWindow, x: f64, y: f64) {
    unsafe {
        let raw_window_ptr = window.ns_window().unwrap() as *mut c_void;
        swift_bridge::show_window_as_popover(raw_window_ptr, x, y);
    }
}
// close any Tauri window as a popover (if any; has safe fallback if the popover is not present)
#[cfg(target_os = "macos")]
pub fn close_window_as_popover() {
    unsafe {
        swift_bridge::close_window_as_popover();
    }
}
