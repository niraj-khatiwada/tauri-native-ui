use std::sync::Mutex;

use tauri::tray::{MouseButton, MouseButtonState, TrayIconEvent};
use tauri::webview::PageLoadEvent;
use tauri::window::{Effect, EffectsBuilder};
use tauri::{ActivationPolicy, Manager};
use tauri::{WebviewUrl, WebviewWindowBuilder};
use tauri_plugin_nspopover::{AppExt, ToPopoverOptions, WindowExt};

use crate::macos;
use crate::panel_controller::PanelController;
use crate::swift_bridge::{
    hide_native_tooltip, show_native_popover, show_native_toast, show_native_tooltip,
    show_webview_popover,
};

#[tauri::command]
pub fn open_native_popover(_app: tauri::AppHandle, x: f64, y: f64) {
    unsafe {
        show_native_popover(x, y);
    }
}

#[tauri::command]
pub fn open_native_webview_popover(app: tauri::AppHandle, x: f64, y: f64) {
    #[cfg(target_os = "macos")]
    {
        if let Some(main_window) = app.get_webview_window("main") {
            #[cfg(not(debug_assertions))]
            let mut target_url_string = None;

            #[cfg(debug_assertions)]
            let target_url_string = None;

            #[cfg(not(debug_assertions))]
            if let Ok(resource_dir) = app.path().resource_dir() {
                let html_path = resource_dir.join("dist").join("index.html");
                if html_path.exists() {
                    target_url_string =
                        Some(format!("file://{}#popover", html_path.to_string_lossy()));
                }
            }

            let final_url_string = match target_url_string {
                Some(prod_url) => prod_url,
                None => {
                    if let Ok(mut dev_url) = main_window.url() {
                        dev_url.set_fragment(Some("popover"));
                        dev_url.as_str().to_string()
                    } else {
                        "#popover".to_string()
                    }
                }
            };

            let final_path_sr = swift_rs::SRString::from(final_url_string.as_str());

            unsafe {
                show_webview_popover(final_path_sr, x, y, cfg!(debug_assertions));
            }
        }
    }
}

#[tauri::command]
pub fn open_window_popover(app: tauri::AppHandle, x: f64, y: f64, width: f64, height: f64) {
    if let Some(window) = app.get_webview_window("popover_window") {
        println!("popover_window already exists. closing & creating a new one...");
        window.close().unwrap();
    } else {
        if let Some(main_window) = app.get_webview_window("main") {
            let position = main_window.outer_position().unwrap();
            let logical_position = position.to_logical::<f64>(main_window.scale_factor().unwrap());
            let mut popover_url = if let Some(main_win) = app.get_webview_window("main") {
                main_win.url().unwrap()
            } else {
                // Fallback safety string if main window is missing
                "https://tauri.localhost/index.html"
                    .parse::<tauri::Url>()
                    .unwrap()
            };

            popover_url.set_fragment(Some("popover"));

            let app_clone = app.clone();
            let popover = WebviewWindowBuilder::new(
                &app,
                "popover_window",
                WebviewUrl::CustomProtocol(popover_url),
            )
            // .parent(&main_window)
            // .expect("Main parent window not found")
            .decorations(false)
            .transparent(true)
            // .title_bar_style(tauri::TitleBarStyle::Overlay)
            // .hidden_title(true)
            // .always_on_top(true)
            // .skip_taskbar(true)
            // .resizable(false)
            // .maximizable(false)
            // .minimizable(false)
            .focused(false)
            .visible(true)
            // .effects(
            //     EffectsBuilder::new()
            //         .effect(Effect::Menu)
            //         .state(tauri::window::EffectState::Active)
            //         .radius(20.0)
            //         .build(),
            // )
            .inner_size(width, height)
            .position(logical_position.x as f64 + x, logical_position.y as f64 + y)
            .on_page_load(move |window, payload| match payload.event() {
                PageLoadEvent::Started => {
                    println!("{} started loading", payload.url());
                }
                PageLoadEvent::Finished => {
                    println!("🎉 Popover web content ready! Initiating view hijacking...");
                    window.to_popover(ToPopoverOptions {
                        is_fullsize_content: true,
                        tray_id: Some("tray".to_string()),
                        x: logical_position.x as f64 + x,
                        y: logical_position.y as f64 + y,
                    });

                    let tray = app_clone.tray_by_id("tray").unwrap();
                    let app_clone_clone = app_clone.clone();
                    tray.on_tray_icon_event(move |_, event| match event {
                        TrayIconEvent::Click {
                            button,
                            button_state,
                            ..
                        } => {
                            if button == MouseButton::Left && button_state == MouseButtonState::Up {
                                if !app_clone_clone.is_popover_shown() {
                                    app_clone_clone.show_popover();
                                } else {
                                    app_clone_clone.hide_popover();
                                }
                            }
                        }
                        _ => {}
                    });
                }
            })
            .build()
            .unwrap();

            // let popover_clone = popover.clone();
            // let main_window_clone = main_window.clone();

            // macos::hide_traffic_light_buttons(&popover);

            // popover.on_window_event(move |event| match event {
            //     tauri::WindowEvent::Focused(false) => {
            //         let _ = popover_clone.close();
            //         let _ = main_window_clone.set_focus();
            //     }
            //     _ => {}
            // });

            // let main_window_clone = main_window.clone();
            // let popover_main_clone = popover.clone();
            // main_window.on_window_event(move |event| match event {
            //     tauri::WindowEvent::Destroyed | tauri::WindowEvent::Moved(..) => {
            //         if let Some(pop_win) = popover_main_clone
            //             .app_handle()
            //             .get_webview_window("popover_window")
            //         {
            //             let _ = pop_win.close();
            //             let _ = main_window_clone.set_focus();
            //         }
            //     }

            //     _ => {}
            // });
        }
    }
}

#[tauri::command]
pub fn close_window_popover(app: tauri::AppHandle, label: String) -> Result<(), String> {
    if let Some(window) = app.get_webview_window(&label) {
        window.close().map_err(|e| e.to_string())?;
        Ok(())
    } else {
        Err(format!("Window with label '{}' not found", label))
    }
}

#[tauri::command]
pub fn open_native_tooltip(text: String, keys: String, x: f64, y: f64) {
    unsafe {
        show_native_tooltip(
            swift_rs::SRString::from(text.as_str()),
            swift_rs::SRString::from(keys.as_str()),
            x,
            y,
        );
    }
}

#[tauri::command]
pub fn close_native_tooltip() {
    unsafe {
        hide_native_tooltip();
    }
}

#[tauri::command]
pub fn open_native_toast(text: String, icon: Option<String>, icon_hex: Option<String>) {
    let icon_string = icon.unwrap_or_else(|| "".to_string());
    unsafe {
        show_native_toast(
            swift_rs::SRString::from(text.as_str()),
            swift_rs::SRString::from(icon_string.as_str()),
            swift_rs::SRString::from(icon_hex.unwrap_or_default().as_str()),
        );
    }
}

#[tauri::command]
pub fn convert_window_to_floating_panel(app: tauri::AppHandle) {
    // Grab the main Tauri window shell instance
    if let Some(window) = app.get_webview_window("main") {
        // Extract the underlying raw AppKit NSWindow handle pointer safely
        let ns_window_ptr = window.ns_window().unwrap() as *mut std::ffi::c_void;
        let ns_window = unsafe { &*(ns_window_ptr as *const objc2_app_kit::NSWindow) };

        // Hijack the layout view and launch your premium panel container!
        // (Make sure to persist this instance so it isn't dropped from memory immediately)
        let _panel_controller = PanelController::new(ns_window, 1.0, 1.0);

        // Hide the old hollow container window shell framework
        window.hide().unwrap();
    }
}
