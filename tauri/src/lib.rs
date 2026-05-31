use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconEvent},
    Manager, WebviewUrl, WebviewWindowBuilder,
};

use crate::tray::WindowExt;

mod commands;
mod domain;
mod macos;
mod tray;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::open_window_popover,
            commands::close_window_popover,
            commands::open_native_popover,
            commands::open_native_tooltip,
            commands::close_native_tooltip,
            commands::open_native_toast,
            commands::open_tray_popover,
            commands::close_tray_popover,
        ])
        .setup(|app| {
            // Tray
            let app_handle = app.handle().clone();
            let main_window = app_handle
                .get_webview_window(domain::AppWindow::Main.as_str())
                .expect("main window must exist");

            let tray_window_label = domain::AppWindow::Tray.as_str();
            let mut tray_url = main_window.url().expect("main window url must exist");
            tray_url.set_fragment(Some(tray_window_label));

            let tray_window = WebviewWindowBuilder::new(
                &app_handle,
                tray_window_label,
                WebviewUrl::CustomProtocol(tray_url),
            )
            .parent(&main_window)
            .expect("main parent window must exist")
            .decorations(false)
            .transparent(true)
            .visible(false)
            .inner_size(400.0, 500.0)
            .build()
            .expect("tray window must initialize");

            tray::init(app);
            tray_window.to_popover(None);

            let tray = app
                .tray_by_id(tray_window_label)
                .expect("tray window must exist");
            tray.on_tray_icon_event(move |_, event| match event {
                TrayIconEvent::Click {
                    button,
                    button_state,
                    ..
                } => {
                    if button == MouseButton::Left && button_state == MouseButtonState::Up {
                        tray_window.open_tray_popover();
                    }
                }
                _ => {}
            });

            macos::hide_traffic_light_buttons(&main_window);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
