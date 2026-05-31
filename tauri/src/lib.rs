use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconEvent},
    ActivationPolicy, Manager,
};
use tauri_plugin_nspopover::{AppExt, ToPopoverOptions, WindowExt};

mod commands;
mod macos;
mod swift_bridge;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_nspopover::init())
        .invoke_handler(tauri::generate_handler![
            commands::open_window_popover,
            commands::close_window_popover,
            commands::open_native_popover,
            commands::open_native_tooltip,
            commands::close_native_tooltip,
            commands::open_native_toast,
        ])
        .setup(|app| {
            if let Some(main_window) = app.get_webview_window("main") {
                // // Tray
                // app.set_activation_policy(ActivationPolicy::Accessory);

                // let tray_window = app.handle().get_webview_window("tray").unwrap();
                // tray_window.to_popover(ToPopoverOptions {
                //     is_fullsize_content: false,
                //     tray_id: Some("0".to_string()),
                //     x: 0.,
                //     y: 0.,
                // });

                // let tray = app.tray_by_id("tray").unwrap();
                // let app_handle = app.handle().clone();
                // tray.on_tray_icon_event(move |_, event| match event {
                //     TrayIconEvent::Click {
                //         button,
                //         button_state,
                //         ..
                //     } => {
                //         println!(">> clicked");
                //         if button == MouseButton::Left && button_state == MouseButtonState::Up {
                //             if !app_handle.is_popover_shown() {
                //                 app_handle.show_popover();
                //             } else {
                //                 app_handle.hide_popover();
                //             }
                //         }
                //     }
                //     _ => {}
                // });

                let main_window_clone = main_window.clone();
                macos::hide_traffic_light_buttons(&main_window_clone);

                // Close app when not focused (Temp until we get the screen recording access)
                // #[cfg(not(debug_assertions))]
                // main_window.on_window_event(move |event| match event {
                //     tauri::WindowEvent::Focused(is_focused) => {
                //         if !is_focused && main_window_clone.webview_windows().len() == 1 {
                //             main_window_clone.close().unwrap();
                //         }
                //     }
                //     _ => {}
                // });
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
