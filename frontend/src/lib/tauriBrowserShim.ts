/**
 * Browser fallback for the Tauri IPC bridge.
 *
 * Opened in a plain browser (e.g. http://localhost:3118 for CSS/theme
 * debugging) there is no Tauri runtime, so `@tauri-apps/api`'s `invoke` — which
 * reads `window.__TAURI_INTERNALS__` — throws and blocks startup. This installs
 * a no-op bridge ONLY when the real one is absent, so the UI renders instead of
 * crashing. In the packaged app the real bridge exists and this does nothing.
 *
 * ponytail: returns an empty array for every command — the one default that is
 * safe both for list consumers (`.map`/`.length` work) and object consumers
 * (`result.field` reads as `undefined` instead of throwing on null). Enough to
 * render, not to exercise backend behavior. Special-case a command in COMMANDS
 * below if a screen needs a specific shape.
 */
declare global {
  interface Window {
    __TAURI_INTERNALS__?: unknown;
  }
}

// Per-command overrides for screens that need a specific shape to render.
const COMMANDS: Record<string, unknown> = {
  // RecordingStateContext dereferences these fields directly on first mount.
  get_recording_state: {
    is_recording: false,
    is_paused: false,
    is_microphone_muted: false,
    is_system_audio_muted: false,
  },
  // Skip onboarding so the main app chrome renders (flip to render onboarding).
  get_onboarding_status: { completed: true },
  // No pending crash report — otherwise the [] default reads as truthy and the
  // crash dialog blocks the main app.
  get_pending_crash_report: null,
};

if (typeof window !== "undefined" && !window.__TAURI_INTERNALS__) {
  window.__TAURI_INTERNALS__ = {
    invoke: async (cmd: string) => {
      console.debug(`[tauri-browser-shim] invoke ignored: ${cmd}`);
      return cmd in COMMANDS ? COMMANDS[cmd] : [];
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
