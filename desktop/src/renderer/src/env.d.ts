/// <reference types="vite/client" />

import type { NduBridge } from '@shared/ipc'
import type { WebviewElement } from './types'

declare global {
  interface Window {
    /** Native bridge exposed by `src/preload/index.ts`. */
    ndu: NduBridge
  }

  /**
   * React already declares the `<webview>` tag (`WebViewHTMLAttributes`) but
   * types the element as an empty `HTMLWebViewElement`. Electron adds methods
   * to that element which the shell drives, so they are merged in here rather
   * than redeclaring the tag, which would clash with React's own attributes
   * (for example `allowpopups`, typed as a boolean).
   */
  interface HTMLWebViewElement extends WebviewElement {}
}

export {}
