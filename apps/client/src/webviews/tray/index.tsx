import { invoke } from "@tauri-apps/api/core";
import { useState } from "react";

export default function TrayWindow() {
  const [counter, setCounter] = useState<number>(0);

  const handleTrayPopoverClose = () => {
    invoke("close_tray_popover", {
      suspend: true,
    });
  };

  const handleFocusMain = async () => {
    await invoke("focus_or_create_main_window");
  };

  const handleQuitApp = async () => {
    try {
      await invoke("quit_app");
    } catch (error) {
      console.error(
        "Failed to issue application process terminate sequence:",
        error,
      );
    }
  };
  return (
    <div className="p-4 w-screen h-screen">
      <div className="w-full flex flex-col items-center justify-center gap-2 text-white text-xs mt-10">
        <button
          onClick={handleFocusMain}
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
        >
          Open/Focus Main Window
        </button>
        <div className="flex flex-col items-center justify-center mt-10">
          <button
            onClick={handleTrayPopoverClose}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Suspend Tray Popover
          </button>
          <p className="text-sm text-white text-center">
            Suspending the tray will recreate the webview
          </p>
        </div>
        <button
          className="text-white text-xl text-center"
          onClick={() => {
            setCounter((s) => s + 1);
          }}
        >
          Counter {counter}
        </button>
        <button
          onClick={handleQuitApp}
          className="bg-red-400 px-4 py-1 rounded-md text-xs w-fit absolute right-4 bottom-4"
        >
          Quit App
        </button>
      </div>
    </div>
  );
}
