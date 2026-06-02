import { invoke } from "@tauri-apps/api/core";

export default function PanelWindow({ panelId }: { panelId: string }) {
  const handleClosePanel = () => {
    invoke("close_window_panel", {
      panelId,
    });
  };

  return (
    <>
      <div className="p-4 w-screen h-screen my-4">
        <h1 className="text-2xl text-center text-white">Pane id @{panelId}</h1>
        <p className="text-white">
          These panels are different than the normal Tauri transparent window.
          They do not lose focus of the main window.
        </p>

        <div className="w-full flex items-center justify-center gap-2 text-white text-xs">
          <button
            onClick={handleClosePanel}
            className="bg-blue-600 px-4 py-1 rounded-md text-xs w-fit"
          >
            Close Panel
          </button>
        </div>
      </div>
    </>
  );
}
