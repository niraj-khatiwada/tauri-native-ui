import { LogicalSize } from "@tauri-apps/api/dpi";
import { getCurrentWindow } from "@tauri-apps/api/window";
/**
 * Current platform
 * @returns {string}: 'linux', 'macos', 'ios', 'freebsd', 'dragonfly', 'netbsd', 'openbsd', 'solaris', 'android', 'windows'. Returns null for unsupported platform.
 */
export function getPlatform() {
  const userAgent =
    typeof window === "object" ? window?.navigator?.userAgent : undefined;
  return {
    isLinux: userAgent?.includes?.("Linux"),
    isMacOS: userAgent?.includes?.("Mac"),
    isWindows: userAgent?.includes?.("Win"),
  };
}

interface WindowFrameSize {
  physical: { width: number; height: number };
  logical: { width: number; height: number };
}

/**
 * Calculates the native OS window framing size (title bar height and side borders)
 *
 * @returns {Promise<WindowFrameSize>}
 */
export async function getWindowTitlebarSize(): Promise<WindowFrameSize> {
  const appWindow = getCurrentWindow();

  const [scaleFactor, outerSize] = await Promise.all([
    appWindow.scaleFactor(),
    appWindow.outerSize(),
  ]);

  const docWidth = document.documentElement.clientWidth;
  const docHeight = document.documentElement.clientHeight;

  const docLogicalSize = new LogicalSize(docWidth, docHeight);
  const docPhysicalSize = docLogicalSize.toPhysical(scaleFactor);

  const physicalWidth = Math.max(0, outerSize.width - docPhysicalSize.width);
  const physicalHeight = Math.max(0, outerSize.height - docPhysicalSize.height);

  const logicalWidth = physicalWidth / scaleFactor;
  const logicalHeight = physicalHeight / scaleFactor;

  return {
    physical: {
      width: physicalWidth,
      height: physicalHeight,
    },
    logical: {
      width: logicalWidth,
      height: logicalHeight,
    },
  };
}
