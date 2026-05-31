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
        Ok(_) => {}
        Err(_) => {}
    }
}

#[tauri::command]
pub fn close_window_popover() {
    macos::close_window_as_popover();
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
