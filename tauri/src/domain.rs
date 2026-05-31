pub enum AppWindow {
    Main,
    Popover,
    Tray,
}

impl AppWindow {
    pub fn as_str(&self) -> &'static str {
        match self {
            AppWindow::Main => "main",
            AppWindow::Popover => "popover",
            AppWindow::Tray => "tray",
        }
    }
}
