/**
 * The IPC contract shared by all three processes.
 *
 * Keeping the channel names and payload shapes in one module means the main
 * process, the preload bridge and the React renderer cannot drift apart: a
 * rename breaks the typecheck instead of silently doing nothing at runtime.
 */

export const IpcChannels = {
  /** Renderer -> main, invoke: process/app metadata and the web app URL. */
  appInfo: 'ndu:app-info',
  /** Renderer -> main, invoke: open a URL in the user's default browser. */
  openExternal: 'ndu:open-external',
  /** Renderer -> main, send: current state of the embedded app (for logging). */
  webAppState: 'ndu:web-app-state',
  /** Main -> renderer, send: a menu item or deep link the shell must action. */
  menuCommand: 'ndu:menu-command'
} as const

/** Where the embedded Flutter application is being served from. */
export type WebSource = 'local-build' | 'remote-url'

export interface AppInfo {
  name: string
  version: string
  platform: string
  /** Absolute URL the embedded app is loaded from (origin + initial route). */
  webAppUrl: string
  /** Origin of the embedded app, or null when it has no fixed origin. */
  webAppOrigin: string | null
  /** Route the shell opens on launch, e.g. `/sign-in`. */
  initialRoute: string
  webSource: WebSource
}

/**
 * Commands the main process asks the renderer to perform against the embedded
 * web app. Menu items and `nduproject://` deep links both arrive through here.
 */
export type MenuCommand =
  | { type: 'navigate'; route: string }
  | { type: 'reload' }
  | { type: 'hard-reload' }
  | { type: 'open-in-browser' }
  | { type: 'toggle-devtools' }
  | { type: 'zoom'; direction: 'in' | 'out' | 'reset' }
  /** OAuth return: query string the running app must read from its address bar. */
  | { type: 'oauth-callback'; query: string }

export type WebAppState = 'loading' | 'ready' | 'error'

/** The shape exposed on `window.ndu` by the preload bridge. */
export interface NduBridge {
  getAppInfo(): Promise<AppInfo>
  openExternal(url: string): Promise<boolean>
  reportState(state: WebAppState, detail?: string): void
  /** Subscribe to shell commands. Returns an unsubscribe function. */
  onMenuCommand(listener: (command: MenuCommand) => void): () => void
}
