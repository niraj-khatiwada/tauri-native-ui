use crate::tray::WindowExt;
use crate::{domain, macos};
use tauri::webview::PageLoadEvent;
use tauri::{AppHandle, Manager, WebviewWindow};
use tauri::{WebviewUrl, WebviewWindowBuilder};

#[tauri::command]
pub fn open_native_popover(_app: tauri::AppHandle, x: f64, y: f64) {
    macos::show_native_popover(x, y);
}

#[tauri::command]
pub fn open_window_popover(
    app_handle: AppHandle,
    current_window: WebviewWindow,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) {
    let position = current_window.outer_position().unwrap();
    let logical_position = position.to_logical::<f64>(current_window.scale_factor().unwrap_or(1.0));

    let target_x = logical_position.x + x;
    let target_y = logical_position.y + y;

    let popover_window_label = domain::AppWindow::Popover.as_str();

    if let Some(window) = app_handle.get_webview_window(popover_window_label) {
        let app_clone = app_handle.clone();
        window.on_window_event(move |event| {
            if let tauri::WindowEvent::Destroyed = event {
                println!("OLD POPOVER DESTROYED");
                let current_window_clone = current_window.clone();
                let app_deferred = app_clone.clone();
                tauri::async_runtime::spawn(async move {
                    create_fresh_popover(
                        &app_deferred,
                        &current_window_clone,
                        target_x,
                        target_y,
                        width,
                        height,
                    );
                });
            }
        });
        let _ = window.destroy();
    } else {
        create_fresh_popover(
            &app_handle,
            &current_window,
            target_x,
            target_y,
            width,
            height,
        );
    }
}

fn create_fresh_popover(
    app_handle: &AppHandle,
    parent_window: &WebviewWindow,
    target_x: f64,
    target_y: f64,
    width: f64,
    height: f64,
) {
    let popover_window_label = domain::AppWindow::Popover.as_str();

    let mut popover_url = parent_window.url().unwrap();
    popover_url.set_fragment(Some(popover_window_label));

    match WebviewWindowBuilder::new(
        app_handle,
        popover_window_label,
        WebviewUrl::CustomProtocol(popover_url),
    )
    .parent(&parent_window)
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
        Ok(_) => {
            println!("FRESH POPOVER CREATED");
        }
        Err(_) => {}
    }
}

#[tauri::command]
pub fn is_window_popover_visible() -> bool {
    macos::is_window_as_popover_visible()
}

#[tauri::command]
pub fn close_window_popover() {
    macos::close_window_as_popover();
}

#[tauri::command]
pub fn open_window_panel(
    app_handle: AppHandle,
    current_window: WebviewWindow,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) {
    let position = current_window.outer_position().unwrap();
    let logical_position = position.to_logical::<f64>(current_window.scale_factor().unwrap_or(1.0));

    let target_x = logical_position.x + x;
    let target_y = logical_position.y + y;

    let panel_window_label = domain::AppWindow::Panel.as_str();

    if let Some(window) = app_handle.get_webview_window(panel_window_label) {
        let app_clone = app_handle.clone();
        window.on_window_event(move |event| {
            if let tauri::WindowEvent::Destroyed = event {
                println!("OLD PANEL DESTROYED");
                let current_window_clone = current_window.clone();
                let app_deferred = app_clone.clone();
                tauri::async_runtime::spawn(async move {
                    create_fresh_panel(
                        &app_deferred,
                        &current_window_clone,
                        target_x,
                        target_y,
                        width,
                        height,
                    );
                });
            }
        });
        let _ = window.destroy();
    } else {
        create_fresh_panel(
            &app_handle,
            &current_window,
            target_x,
            target_y,
            width,
            height,
        );
    }
}

fn create_fresh_panel(
    app_handle: &AppHandle,
    parent_window: &WebviewWindow,
    target_x: f64,
    target_y: f64,
    width: f64,
    height: f64,
) {
    let panel_window_label = domain::AppWindow::Panel.as_str();

    let mut panel_url = parent_window.url().unwrap();
    panel_url.set_fragment(Some(panel_window_label));

    match WebviewWindowBuilder::new(
        app_handle,
        panel_window_label,
        WebviewUrl::CustomProtocol(panel_url),
    )
    .parent(&parent_window)
    .expect("Main parent window context lost")
    .decorations(false)
    .transparent(true)
    .visible(false)
    .inner_size(width, height)
    .on_page_load(move |window, payload| {
        if let PageLoadEvent::Finished = payload.event() {
            macos::show_window_as_panel(&window, target_x, target_y);
        }
    })
    .build()
    {
        Ok(_) => {
            println!("FRESH PANEL CREATED");
        }
        Err(_) => {}
    }
}

#[tauri::command]
pub fn is_window_panel_visible() -> bool {
    macos::is_window_as_panel_visible()
}

#[tauri::command]
pub fn close_window_panel() {
    macos::close_window_as_panel();
}

#[tauri::command]
pub fn open_native_tooltip(text: String, keys: Vec<String>, x: f64, y: f64) {
    macos::show_native_tooltip(text.as_str(), keys, x, y);
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

#[tauri::command]
pub fn open_tray_popover(app_handle: AppHandle) {
    match app_handle.get_webview_window(domain::AppWindow::Tray.as_str()) {
        Some(tray_window) => {
            tray_window.open_tray_popover();
        }
        None => {
            println!("tray window not found");
        }
    };
}

#[tauri::command]
pub fn close_tray_popover(app_handle: AppHandle) {
    match app_handle.get_webview_window(domain::AppWindow::Tray.as_str()) {
        Some(tray_window) => {
            tray_window.close_tray_popover();
        }
        None => {
            println!("tray window not found");
        }
    };
}

#[tauri::command]
pub fn is_tray_popover_visible(app_handle: AppHandle) -> bool {
    match app_handle.get_webview_window(domain::AppWindow::Tray.as_str()) {
        Some(tray_window) => return tray_window.is_tray_popover_visible(),
        None => {
            println!("tray window not found");
        }
    };
    return false;
}

#[tauri::command]
pub fn focus_or_create_main_window(app_handle: tauri::AppHandle) -> Result<(), String> {
    let main_label = domain::AppWindow::Main.as_str();

    match app_handle.get_webview_window(main_label) {
        Some(window) => {
            window.unminimize().map_err(|e| e.to_string())?;
            window.show().map_err(|e| e.to_string())?;
            window.set_focus().map_err(|e| e.to_string())?;
        }
        None => {
            let window_config = app_handle
                .config()
                .app
                .windows
                .iter()
                .find(|w| w.label == main_label)
                .cloned()
                .unwrap_or_default();

            let main_window = WebviewWindowBuilder::from_config(&app_handle, &window_config)
                .map_err(|e| e.to_string())?
                .build()
                .map_err(|e| e.to_string())?;
            macos::hide_traffic_light_buttons(&main_window);
        }
    }
    Ok(())
}

#[tauri::command]
pub fn quit_app(app_handle: AppHandle) {
    app_handle.exit(0);
}
