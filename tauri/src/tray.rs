use std::{os::raw::c_void, sync::Mutex};
use tauri::{tray::TrayIcon, Manager, Runtime, WebviewWindow};

swift_rs::swift!(
    fn init_tray_popover_manager_bridge(
        ns_window_ptr: *mut c_void,
        ns_statusbar_button_ptr: *mut c_void,
        is_fullsize_content: bool
    )
);

swift_rs::swift!(fn open_tray_popover_bridge());
swift_rs::swift!(pub fn close_tray_popover_bridge());
swift_rs::swift!(pub fn is_tray_popover_visible_bridge() -> bool);

pub struct ToPopoverOptions {
    pub is_fullsize_content: bool,
}

pub trait WindowExt<R: Runtime> {
    fn to_popover(&self, options: Option<ToPopoverOptions>);
    fn is_tray_popover_shown(&self) -> bool;
    fn open_tray_popover(&self);
    fn close_tray_popover(&self);
}

pub trait RawAppKitHandles {
    fn raw_statusbar_button(&self) -> *mut std::ffi::c_void;
}

impl<R: Runtime> RawAppKitHandles for TrayIcon<R> {
    fn raw_statusbar_button(&self) -> *mut std::ffi::c_void {
        struct SendPtr(*mut std::ffi::c_void);
        unsafe impl Send for SendPtr {}

        self.with_inner_tray_icon(|inner| {
            let status_item = inner.ns_status_item().expect("NSStatusItem dropped");
            let button: objc2::rc::Retained<objc2_app_kit::NSStatusBarButton> =
                unsafe { objc2::msg_send![&*status_item, button] };
            let raw_ptr = objc2::rc::Retained::into_raw(button) as *mut std::ffi::c_void;
            SendPtr(raw_ptr)
        })
        .expect("Failed to bridge tray pointer thread boundary")
        .0
    }
}

impl<R: Runtime> WindowExt<R> for WebviewWindow<R> {
    fn to_popover(&self, options: Option<ToPopoverOptions>) {
        let _options = options.unwrap_or(ToPopoverOptions {
            is_fullsize_content: false,
        });
        let tray = self
            .app_handle()
            .tray_by_id(self.label())
            .expect("Tray not initialized");
        let raw_button = tray.raw_statusbar_button();
        let ns_window_ptr = self.ns_window().unwrap() as *mut std::ffi::c_void;

        unsafe {
            init_tray_popover_manager_bridge(
                ns_window_ptr,
                raw_button,
                _options.is_fullsize_content,
            );
        }

        let state = self.app_handle().state::<AppState>();
        *state.0.lock().unwrap() = true;
    }

    fn is_tray_popover_shown(&self) -> bool {
        let state = self.app_handle().state::<AppState>();
        if !*state.0.lock().unwrap() {
            return false;
        }

        unsafe { is_tray_popover_visible_bridge() }
    }

    fn open_tray_popover(&self) {
        let state = self.app_handle().state::<AppState>();
        if !*state.0.lock().unwrap() {
            return;
        }

        unsafe {
            open_tray_popover_bridge();
        }
    }

    fn close_tray_popover(&self) {
        let state = self.app_handle().state::<AppState>();
        if !*state.0.lock().unwrap() {
            return;
        }

        unsafe {
            close_tray_popover_bridge();
        }
    }
}

pub struct AppState(pub Mutex<bool>);

pub fn init<R: Runtime>(app: &mut tauri::App<R>) {
    app.manage(AppState(Mutex::new(false)));
}
