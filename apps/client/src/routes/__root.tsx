import { createRootRouteWithContext, Outlet } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/react-router-devtools";

import { QueryClientProvider } from "~/provider/QueryClientProvider";
import Titlebar from "~/tauri/components/Titlebar";
import { getPlatform } from "~/tauri/utils";

export const Route = createRootRouteWithContext()({
  component: RootComponent,
});

const isDev = import.meta.env.DEV;
const { isMacOS } = getPlatform();

function RootComponent() {
  return (
    <>
      <QueryClientProvider>
        {isMacOS ? <Titlebar /> : null}
        <Outlet />
      </QueryClientProvider>
      {isDev ? <TanStackRouterDevtools position="bottom-right" /> : null}
    </>
  );
}
