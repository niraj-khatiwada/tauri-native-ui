use objc2::rc::Retained;
use objc2_app_kit::{NSPopover, NSStatusBarButton, NSWindow};
use objc2_foundation::{MainThreadMarker, NSRectEdge};
use tauri::{
    plugin::{Builder, TauriPlugin},
    tray::TrayIcon,
    AppHandle, Manager, Runtime, State, WebviewWindow,
};

use std::sync::Mutex;

mod popover;

use popover::PopoverController;

pub struct ToPopoverOptions {
    pub is_fullsize_content: bool,
    pub tray_id: Option<String>,
    pub x: f64,
    pub y: f64,
}

pub trait WindowExt<R: Runtime> {
    fn to_popover(&self, options: ToPopoverOptions);
}
pub trait AppExt<R: Runtime> {
    fn is_popover_shown(&self) -> bool;
    fn show_popover(&self);
    fn hide_popover(&self);
    fn ns_popover(&self) -> Retained<NSPopover>;
    fn ns_statusbar_button(&self) -> Retained<NSStatusBarButton>;
}

pub use tauri::tray::TrayIconId;

pub trait StatusItemGetter {
    fn get_status_bar_button(&self) -> Retained<NSStatusBarButton>;
}

impl<R: Runtime> StatusItemGetter for TrayIcon<R> {
    fn get_status_bar_button(&self) -> Retained<NSStatusBarButton> {
        struct SendButton(Retained<NSStatusBarButton>);
        unsafe impl Send for SendButton {}

        self.with_inner_tray_icon(|inner| {
            let mtm =
                MainThreadMarker::new().expect("with_inner_tray_icon closure runs on main thread");
            let status = inner
                .ns_status_item()
                .expect("NSStatusItem unavailable (tray dropped?)");
            SendButton(status.button(mtm).expect("NSStatusBarButton unavailable"))
        })
        .expect("with_inner_tray_icon dispatch failed")
        .0
    }
}

impl<R: Runtime> WindowExt<R> for WebviewWindow<R> {
    fn to_popover(&self, options: ToPopoverOptions) {
        let tray_id = match options.tray_id {
            Some(id) => id,
            None => "main".to_string(),
        };
        let tray = self.app_handle().tray_by_id(tray_id.as_str()).unwrap();

        let button = tray.get_status_bar_button();

        let window = self;
        let window = window.ns_window().unwrap();
        let ns_window = unsafe { (window.cast() as *mut NSWindow).as_ref().unwrap() };

        let _scale = self.scale_factor().unwrap();

        let popover_controller = PopoverController::new(ns_window, options.x, options.y);
        let _ = self.hide();

        let popover = SafeNSPopover(popover_controller.popover());
        if options.is_fullsize_content {
            unsafe { popover.0.setHasFullSizeContent(true) };
        }
        let button = SafeNSStatusBarButton(button);

        let state = self.app_handle().state() as State<'_, AppState>;
        *state.0.lock().unwrap() = Some(AppStateInner { popover, button });
    }
}

impl<R: Runtime> AppExt<R> for AppHandle<R> {
    fn is_popover_shown(&self) -> bool {
        let state: State<AppState> = self.state();

        if state.0.lock().unwrap().as_ref().is_none() {
            return false;
        }

        let state_guard = state.0.lock().unwrap();
        let inner = state_guard.as_ref().unwrap();
        let popover = &inner.popover.0;

        unsafe { popover.isShown() }
    }
    fn ns_popover(&self) -> Retained<NSPopover> {
        let state: State<AppState> = self.state();
        let guard = state.0.lock().unwrap();
        let inner = guard.as_ref().unwrap();
        let popover = &inner.popover.0;

        // Create a new reference to the same popover
        popover.clone()
    }
    fn ns_statusbar_button(&self) -> Retained<NSStatusBarButton> {
        let state: State<AppState> = self.state();
        let button = state.0.lock().unwrap().as_ref().unwrap().button.0.clone();

        button
    }

    fn show_popover(&self) {
        let state: State<AppState> = self.state();
        if state.0.lock().unwrap().as_ref().is_none() {
            return;
        }

        let popover = self.ns_popover();
        let button = self.ns_statusbar_button();
        let rect = button.bounds();

        if unsafe { !popover.isShown() } {
            unsafe {
                popover.showRelativeToRect_ofView_preferredEdge(
                    rect,
                    button.as_ref(),
                    NSRectEdge::MaxY,
                );
            }
        }
    }
    fn hide_popover(&self) {
        let state: State<AppState> = self.state();

        if state.0.lock().unwrap().as_ref().is_none() {
            return;
        }
        let popover = self.ns_popover();

        if unsafe { popover.isShown() } {
            unsafe { popover.performClose(None) };
        }
    }
}

struct SafeNSPopover(Retained<NSPopover>);
struct SafeNSStatusBarButton(Retained<NSStatusBarButton>);

unsafe impl Send for SafeNSPopover {}
unsafe impl Send for SafeNSStatusBarButton {}

#[tauri::command]
fn show_popover<R: Runtime>(app: AppHandle<R>) -> Result<(), String> {
    app.show_popover();

    return Ok(());
}

#[tauri::command]
fn hide_popover<R: Runtime>(app: AppHandle<R>) -> Result<(), String> {
    app.hide_popover();

    Ok(())
}

#[tauri::command]
fn is_popover_shown<R: Runtime>(app: AppHandle<R>) -> Result<bool, String> {
    return Ok(app.is_popover_shown());
}

struct AppStateInner {
    popover: SafeNSPopover,
    button: SafeNSStatusBarButton,
}

struct AppState(Mutex<Option<AppStateInner>>);

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("nspopover")
        .invoke_handler(tauri::generate_handler![
            show_popover,
            hide_popover,
            is_popover_shown
        ])
        .setup(|app, _| {
            app.manage(AppState(Mutex::new(None)));

            Ok(())
        })
        .build()
}

// use objc2::rc::Retained;
// use objc2_app_kit::{NSPopover, NSStatusBarButton, NSWindow};
// use objc2_foundation::{MainThreadMarker, NSRectEdge};
// use tauri::{
//     plugin::{Builder, TauriPlugin},
//     AppHandle, Manager, Runtime, State, WebviewWindow,
// };

// use std::sync::Mutex;

// mod popover;

// use popover::PopoverController;

// pub struct ToPopoverOptions {
//     pub is_fullsize_content: bool,
//     pub window_label: Option<String>,
//     // 🌟 Added coordinate arguments directly to options footprint
//     pub x: f64,
//     pub y: f64,
// }

// pub trait WindowExt<R: Runtime> {
//     fn to_popover(&self, options: ToPopoverOptions);
// }

// pub trait AppExt<R: Runtime> {
//     fn is_popover_shown(&self) -> bool;
//     fn show_popover(&self);
//     fn hide_popover(&self);
//     fn ns_popover(&self) -> Retained<NSPopover>;
// }

// impl<R: Runtime> WindowExt<R> for WebviewWindow<R> {
//     fn to_popover(&self, options: ToPopoverOptions) {
//         let window = self;
//         let window_ptr = window.ns_window().unwrap();
//         let ns_window = unsafe { (window_ptr.cast() as *mut NSWindow).as_ref().unwrap() };

//         let _scale = self.scale_factor().unwrap();

//         let popover_controller = PopoverController::new(ns_window, options.x, options.y);

//         let _ = self.hide();

//         let popover = SafeNSPopover(popover_controller.popover());
//         if options.is_fullsize_content {
//             unsafe { popover.0.setHasFullSizeContent(true) };
//         }

//         // 🌟 STEP 3: Pin state layout safely in memory
//         let state = self.app_handle().state() as State<'_, AppState>;
//         *state.0.lock().unwrap() = Some(AppStateInner { popover });
//     }
// }

// impl<R: Runtime> AppExt<R> for AppHandle<R> {
//     fn is_popover_shown(&self) -> bool {
//         let state: State<AppState> = self.state();

//         if state.0.lock().unwrap().as_ref().is_none() {
//             return false;
//         }

//         let state_guard = state.0.lock().unwrap();
//         let inner = state_guard.as_ref().unwrap();
//         let popover = &inner.popover.0;

//         unsafe { popover.isShown() }
//     }

//     fn ns_popover(&self) -> Retained<NSPopover> {
//         let state: State<AppState> = self.state();
//         let guard = state.0.lock().unwrap();
//         let inner = guard.as_ref().unwrap();
//         let popover = &inner.popover.0;

//         popover.clone()
//     }

//     fn show_popover(&self) {
//         let state: State<AppState> = self.state();
//         if state.0.lock().unwrap().as_ref().is_none() {
//             return;
//         }

//         let popover = self.ns_popover();

//         if unsafe { !popover.isShown() } {
//             unsafe {
//                 // Call the activation routine directly on the underlying view model
//                 let _: () = objc2::msg_send![&*popover, orderFrontRegardless];
//             }
//         }
//     }

//     fn hide_popover(&self) {
//         let state: State<AppState> = self.state();

//         if state.0.lock().unwrap().as_ref().is_none() {
//             return;
//         }
//         let popover = self.ns_popover();

//         unsafe {
//             let _: () = objc2::msg_send![&*popover, close];
//         };
//     }
// }

// struct SafeNSPopover(Retained<NSPopover>);
// unsafe impl Send for SafeNSPopover {}

// #[tauri::command]
// fn show_popover<R: Runtime>(app: AppHandle<R>) -> Result<(), String> {
//     app.show_popover();
//     Ok(())
// }

// #[tauri::command]
// fn hide_popover<R: Runtime>(app: AppHandle<R>) -> Result<(), String> {
//     app.hide_popover();
//     Ok(())
// }

// #[tauri::command]
// fn is_popover_shown<R: Runtime>(app: AppHandle<R>) -> Result<bool, String> {
//     Ok(app.is_popover_shown())
// }

// struct AppStateInner {
//     popover: SafeNSPopover,
// }

// struct AppState(Mutex<Option<AppStateInner>>);

// pub fn init<R: Runtime>() -> TauriPlugin<R> {
//     Builder::new("nspopover")
//         .invoke_handler(tauri::generate_handler![
//             show_popover,
//             hide_popover,
//             is_popover_shown
//         ])
//         .setup(|app, _| {
//             app.manage(AppState(Mutex::new(None)));
//             Ok(())
//         })
//         .build()
// }
