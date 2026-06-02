use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconEvent},
    webview::PageLoadEvent,
    AppHandle, Manager, WebviewUrl, WebviewWindow, WebviewWindowBuilder,
};

use crate::tray::WindowExt;

mod commands;
mod domain;
mod macos;
mod tray;

fn create_tray_window(app_handle: &AppHandle, label: &str) -> Result<WebviewWindow, String> {
    let main_window = app_handle
        .get_webview_window(domain::AppWindow::Main.as_str())
        .expect("main window must exist");

    let mut tray_url = main_window.url().map_err(|err| err.to_string())?;
    tray_url.set_fragment(Some(label));

    let tray_window =
        WebviewWindowBuilder::new(app_handle, label, WebviewUrl::CustomProtocol(tray_url))
            .decorations(false)
            .transparent(true)
            .visible(false)
            .inner_size(400.0, 500.0)
            .build()
            .map_err(|err| err.to_string())?;

    Ok(tray_window)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::open_window_popover,
            commands::close_window_popover,
            commands::is_window_popover_visible,
            commands::open_window_panel,
            commands::close_window_panel,
            commands::is_window_panel_visible,
            commands::open_native_popover,
            commands::open_native_tooltip,
            commands::close_native_tooltip,
            commands::open_native_toast,
            commands::open_tray_popover,
            commands::close_tray_popover,
            commands::is_tray_popover_visible,
            commands::focus_or_create_main_window,
            commands::quit_app
        ])
        .setup(|app| {
            let app_handle = app.handle().clone();
            let main_window = app_handle
                .get_webview_window(domain::AppWindow::Main.as_str())
                .expect("main window must exist");
            macos::hide_traffic_light_buttons(&main_window);

            let tray_window_label = domain::AppWindow::Tray.as_str();
            let tray_window =
                create_tray_window(&app_handle, tray_window_label).expect("tray window must exist");

            tray::init(app);
            tray_window.to_popover(None);

            let tray = app
                .tray_by_id(tray_window_label) // tray id from tauri.conf.json
                .expect("tray window must exist");

            let app_handle_clone = app_handle.clone();
            tray.on_tray_icon_event(move |_, event| match event {
                TrayIconEvent::Click {
                    button,
                    button_state,
                    ..
                } => {
                    if button == MouseButton::Left && button_state == MouseButtonState::Up {
                        let window_option = if let Some(window) =
                            app_handle_clone.get_webview_window(tray_window_label)
                        {
                            Some(window)
                        } else {
                            // tray was probably suspended -> create new tray window
                            if let Ok(window) = create_tray_window(&app_handle, tray_window_label) {
                                window.to_popover(None);
                                Some(window)
                            } else {
                                None
                            }
                        };
                        if let Some(window) = window_option {
                            if window.is_tray_popover_visible() {
                                window.close_tray_popover();
                            } else {
                                window.open_tray_popover();
                            }
                        }
                    }
                }
                _ => {}
            });

            Ok(())
        })
        .on_page_load(|window, payload| {
            if let PageLoadEvent::Finished = payload.event() {
                if window.label().eq(domain::AppWindow::Main.as_str()) {
                    let _ = window.window().show();
                    let __ = window.window().set_focus();
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
