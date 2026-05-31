import { invoke } from "@tauri-apps/api/core";

export default function TrayWindow() {
  const handleTrayPopoverClose = () => {
    invoke("close_tray_popover");
  };
  return (
    <div className="p-4 w-screen h-screen">
      <div className="w-full flex items-center justify-center gap-2 text-white text-xs">
        <button
          onClick={handleTrayPopoverClose}
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
        >
          Close Tray Popover
        </button>
      </div>
    </div>
  );
}
