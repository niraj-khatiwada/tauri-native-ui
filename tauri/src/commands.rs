use crate::macos;
use tauri::webview::PageLoadEvent;
use tauri::{AppHandle, Manager};
use tauri::{WebviewUrl, WebviewWindowBuilder};

#[tauri::command]
pub fn open_native_popover(_app: tauri::AppHandle, x: f64, y: f64) {
    macos::show_native_popover(x, y);
}

#[tauri::command]
pub fn open_window_popover(app_handle: AppHandle, x: f64, y: f64, width: f64, height: f64) {
    if let Some(main_window) = app_handle.get_webview_window("main") {
        let position = main_window.outer_position().unwrap();
        let logical_position = position.to_logical::<f64>(main_window.scale_factor().unwrap());

        let target_x = logical_position.x + x;
        let target_y = logical_position.y + y;

        if let Some(window) = app_handle.get_webview_window("popover_window") {
            println!("popover_window already exists. Registering clean deferred swap...");

            let app_clone = app_handle.clone();
            window.on_window_event(move |event| {
                if let tauri::WindowEvent::Destroyed = event {
                    println!(
                        "💥 Tauri event: 'popover_window' fully dropped. Spawning fresh layout..."
                    );

                    let app_deferred = app_clone.clone();
                    tauri::async_runtime::spawn(async move {
                        create_fresh_popover(&app_deferred, target_x, target_y, width, height);
                    });
                }
            });
            let _ = window.destroy();
        } else {
            create_fresh_popover(&app_handle, target_x, target_y, width, height);
        }
    }
}

fn create_fresh_popover(
    app_handle: &AppHandle,
    target_x: f64,
    target_y: f64,
    width: f64,
    height: f64,
) {
    let main_window = match app_handle.get_webview_window("main") {
        Some(win) => win,
        None => return,
    };

    let mut popover_url = main_window.url().unwrap();
    popover_url.set_fragment(Some("popover"));

    match WebviewWindowBuilder::new(
        app_handle,
        "popover_window",
        WebviewUrl::CustomProtocol(popover_url),
    )
    .parent(&main_window)
    .expect("Main parent window context lost")
    .decorations(false)
    .transparent(true)
    .visible(false)
    .inner_size(width, height)
    .on_page_load(move |window, payload| {
        if let PageLoadEvent::Finished = payload.event() {
            macos::show_window_as_popover(&window, target_x, target_y);
        }
    })
    .build()
    {
        Ok(_) => {}
        Err(_) => {}
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
pub fn open_native_tooltip(app: tauri::AppHandle, text: String, keys: Vec<String>, x: f64, y: f64) {
    if let Some(_) = app.get_webview_window("main") {
        macos::show_native_tooltip(text.as_str(), keys, x, y);
    }
}

#[tauri::command]
pub fn close_native_tooltip() {
    macos::close_native_tooltip();
}

#[tauri::command]
pub fn open_native_toast(
    text: String,
    icon: Option<String>,
    icon_hex: Option<String>,
    x: Option<f64>,
    y: Option<f64>,
) {
    macos::show_native_toast(text.as_str(), icon.as_deref(), icon_hex.as_deref(), x, y);
}
