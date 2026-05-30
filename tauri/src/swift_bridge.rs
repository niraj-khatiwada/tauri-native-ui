// popover
swift_rs::swift!(pub fn show_native_popover(x: f64, y: f64));

// popover webview
swift_rs::swift!(
    pub fn show_webview_popover(
        url: swift_rs::SRString,
        x: f64,
        y: f64,
        enable_dev_tools: swift_rs::Bool
    )
);

// raycast like native tooltip
swift_rs::swift!(
    pub fn show_native_tooltip(text: swift_rs::SRString, keys: swift_rs::SRString, x: f64, y: f64)
);
swift_rs::swift!(pub fn hide_native_tooltip());

// toast
swift_rs::swift!(pub fn show_native_toast(text: swift_rs::SRString, icon: swift_rs::SRString,icon_hex: swift_rs::SRString));
