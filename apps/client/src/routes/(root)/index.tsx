import { createFileRoute } from "@tanstack/react-router";
import { invoke } from "@tauri-apps/api/core";

export const Route = createFileRoute("/(root)/")({
  component: App,
});

function App() {
  const handleWindowPopver = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_window_popover", {
      x: rect.left + rect.width / 2,
      y: rect.bottom,
      width: 350,
      height: 100,
    });
  };

  const handleNativePopver = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_native_popover", {
      x: rect.left + rect.width / 2,
      y: rect.bottom,
      width: 350,
      height: 250,
    });
  };

  const handleMouseEnter = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();

    invoke("open_native_tooltip", {
      text: "About Menu",
      keys: ["⇧", "⌘", "K"],
      x: rect.left + rect.width / 2,
      y: rect.top - rect.height,
    });
  };

  const handleMouseLeave = () => {
    invoke("close_native_tooltip");
  };

  const handleCopySuccess = () => {
    invoke("open_native_toast", {
      text: "Copied configuration token to clipboard",
      icon: "doc.on.doc.fill",
      iconHex: "#10B981",
      // You can also pass toast position
      // x: 500,
      // y: 500,
    });
  };

  const handleSaveError = () => {
    invoke("open_native_toast", {
      text: "Failed to connect to database runtime",
      icon: "exclamationmark.triangle.fill",
      iconHex: "#FF6060",
    });
  };

  const handleTrayPopoverOpen = () => {
    invoke("open_tray_popover");
  };

  const handleTrayPopoverClose = () => {
    invoke("close_tray_popover");
  };

  return (
    <>
      <div className="h-screen w-screen flex flex-col items-center justify-center gap-2 overflow-y-auto text-white">
        <button
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit absolute top-4 left-4"
          onClick={handleWindowPopver}
        >
          Window Popver
        </button>
        <button
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit absolute top-4 right-4"
          onClick={handleNativePopver}
        >
          Native Popver
        </button>
        <div
          className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit absolute bottom-5 left-5"
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
        >
          Hover Over
        </div>
        <div className="w-full flex items-center justify-center gap-2 text-white text-xs">
          <button
            onClick={handleCopySuccess}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Show Success Toast
          </button>

          <button
            onClick={handleSaveError}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Show Error Toast
          </button>
        </div>
        <div className="w-full flex items-center justify-center gap-2 text-white text-xs">
          <button
            onClick={handleTrayPopoverOpen}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Open Tray Popover
          </button>

          <button
            onClick={handleTrayPopoverClose}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Close Tray Popover
          </button>
        </div>
      </div>
    </>
  );
}
