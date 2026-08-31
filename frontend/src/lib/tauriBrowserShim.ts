/**
 * Browser fallback for the Tauri IPC bridge.
 *
 * Opened in a plain browser (e.g. http://localhost:3118 for CSS/theme
 * debugging) there is no Tauri runtime, so `@tauri-apps/api`'s `invoke` — which
 * reads `window.__TAURI_INTERNALS__` — throws and blocks startup. This installs
 * a no-op bridge ONLY when the real one is absent, so the UI renders instead of
 * crashing. In the packaged app the real bridge exists and this does nothing.
 *
 * ponytail: returns null for every command — enough to render, not to exercise
 * backend behavior. Special-case a command below if a screen needs real data.
 */
declare global {
  interface Window {
    __TAURI_INTERNALS__?: unknown;
  }
}

if (typeof window !== "undefined" && !window.__TAURI_INTERNALS__) {
  window.__TAURI_INTERNALS__ = {
    invoke: async (cmd: string) => {
      console.debug(`[tauri-browser-shim] invoke ignored: ${cmd}`);
      return null;
    },
    transformCallback: (callback?: (response: unknown) => void) => {
      const id = Math.floor(Math.random() * 2 ** 31);
      (window as unknown as Record<string, unknown>)[`_${id}`] =
        callback ?? (() => {});
      return id;
    },
  };
}

export {};
