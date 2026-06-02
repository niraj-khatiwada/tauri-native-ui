#[derive(Debug, PartialEq, Eq)]
pub enum AppWindow {
    Main,
    Popover,
    Tray,
    Panel,
}

impl AppWindow {
    pub fn as_str(&self) -> &'static str {
        match self {
            AppWindow::Main => "main",
            AppWindow::Popover => "popover",
            AppWindow::Tray => "tray",
            AppWindow::Panel => "panel",
        }
    }

    pub fn get_panel_window_label_by_id(&self, panel_id: &str) -> String {
        if self.eq(&AppWindow::Panel) {
            format!("{}-{}", self.as_str(), panel_id)
        } else {
            self.as_str().to_string()
        }
    }
}
