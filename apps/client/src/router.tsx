import {
  createHashHistory,
  createRouter,
  RouterProvider,
} from "@tanstack/react-router";

import ReactDOM from "react-dom/client";
import "./styles.css";

import { routeTree } from "./routeTree.gen";
import PopoverWindow from "./webviews/popover";
import TrayWindow from "./webviews/tray";
import PanelWindow from "./webviews/panel";

// See `vite.config.ts` for all defined values.
window.__appVersion = __appVersion;
window.__envMode = __envMode;

const hashHistory = createHashHistory();

const router = createRouter({
  routeTree,
  defaultPreload: "intent",
  history: hashHistory,
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

let defaultRender = <RouterProvider router={router} />;

const hash = window.location.hash as
  | "#popover"
  | "#tray"
  | "#panel"
  | undefined;

if (hash === "#popover") {
  defaultRender = <PopoverWindow />;
} else if (hash === "#tray") {
  defaultRender = <TrayWindow />;
} else if (hash === "#panel") {
  let panelId: string | null;
  try {
    const searchParams = new URLSearchParams(window.location.search);
    panelId = searchParams.get("panelId");
  } catch {}
  defaultRender = <PanelWindow panelId={panelId!} />;
}

const rootElement = document.getElementById("app")!;
if (!rootElement.innerHTML) {
  const root = ReactDOM.createRoot(rootElement);
  root.render(defaultRender);
}
