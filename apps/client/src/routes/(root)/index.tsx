import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";
import { getWindowTitlebarSize } from "~/tauri/utils";

export const Route = createFileRoute("/(root)/")({
  component: App,
});

function App() {
  const { data: windowTitlebarSize } = useQuery({
    queryKey: ["windowTitlebarSize"],
    queryFn: getWindowTitlebarSize,
  });

  const titlebarHeight = windowTitlebarSize?.logical?.height ?? 0;

  const handleWindowPopver = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_window_popover", {
      x: rect.left + rect.width / 2,
      y: rect.bottom + titlebarHeight,
      width: 500,
      height: 300,
    });
  };

  const handleWindowPanelShow = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_window_panel", {
      x: rect.left + rect.width / 2,
      y: rect.bottom + titlebarHeight,
      width: 500,
      height: 300,
    });
  };

  const handleWindowPanelHide = async (evt: any) => {
    invoke("close_window_panel");
  };

  const handleNativePopver = async (evt: any) => {
    const rect = evt.target.getBoundingClientRect();
    invoke("open_native_popover", {
      x: rect.left + rect.width / 2,
      y: rect.bottom + titlebarHeight,
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
      y: rect.top - rect.height - 5 + titlebarHeight,
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
      // Both % and absolute values are supported
      // (x=0.5, y=0.5) => center of the screen | (x=1.0, y=0.9) => bottom right of the screen
      // (x=100, y=200) => 100 from left & 200 from top of the screeen
      x: 1,
      y: 0.9,
    });
  };

  const handleSaveError = () => {
    invoke("open_native_toast", {
      text: "Failed to connect to database runtime",
      icon: "exclamationmark.triangle.fill",
      iconHex: "#FF6060",
    });
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
            onClick={handleWindowPanelShow}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Window Panel
          </button>

          <button
            onClick={handleWindowPanelHide}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Hide Window Panel
          </button>
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
      </div>
    </>
  );
}
