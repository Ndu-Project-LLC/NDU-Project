/**
 * Minimal typing for Electron's `<webview>` element.
 *
 * The renderer deliberately does not pull in `electron`'s ambient types (that
 * would put Node globals in a browser context), so the methods the shell
 * actually calls are declared here.
 */
export interface WebviewElement extends HTMLElement {
  src: string
  partition: string
  reload(): void
  reloadIgnoringCache(): void
  loadURL(url: string): Promise<void>
  getURL(): string
  canGoBack(): boolean
  goBack(): void
  stop(): void
  openDevTools(): void
  closeDevTools(): void
  isDevToolsOpened(): boolean
  executeJavaScript(code: string): Promise<unknown>
  getZoomFactor(): number
  setZoomFactor(factor: number): void
}

export interface WebviewLoadEvent extends Event {
  errorCode?: number
  errorDescription?: string
  validatedURL?: string
  isMainFrame?: boolean
}

/** Chromium's `ERR_ABORTED`; fires for ordinary navigations, not failures. */
export const ERR_ABORTED = -3
