use std::ffi::c_void;

use swift_rs::SRString;

// popover
swift_rs::swift!(pub fn show_native_popover(x: f64, y: f64));

// tooltip
swift_rs::swift!(
    pub fn show_native_tooltip(text: SRString, keys_array: SRString, x: f64, y: f64)
);
swift_rs::swift!(pub fn close_native_tooltip());

// toast
swift_rs::swift!(pub fn show_native_toast(text: SRString, icon: SRString, icon_hex: SRString, x: f64, y: f64));

// window as popover
swift_rs::swift!(pub fn show_window_as_popover(window_raw_ptr: *mut c_void, x: f64, y: f64));
swift_rs::swift!(pub fn close_window_as_popover());
