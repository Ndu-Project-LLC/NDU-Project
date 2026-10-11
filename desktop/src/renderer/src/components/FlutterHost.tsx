import { useEffect, useRef } from 'react'
import type { MenuCommand } from '@shared/ipc'
import { ERR_ABORTED, type WebviewLoadEvent } from '../types'

interface FlutterHostProps {
  /** Absolute URL to load, e.g. `http://127.0.0.1:41234/#/sign-in`. */
  url: string
  /** Origin of the embedded app, used to resolve in-app routes. */
  origin: string | null
  /** Persistent partition so the session survives a restart. */
  partition: string
  onLoading: () => void
  onReady: () => void
  onError: (detail: string) => void
}

const MIN_ZOOM = 0.5
const MAX_ZOOM = 3
const ZOOM_STEP = 0.1

/**
 * Embeds the Flutter web application.
 *
 * A `<webview>` guest is used rather than an `<iframe>` on purpose: it runs as
 * a top-level browsing context with its own storage, so Google/Firebase
 * sign-in popups, custom-protocol returns and third-party cookie policy behave
 * the way they do in a normal browser tab. In a cross-origin iframe those
 * flows are the first thing to break.
 */
export function FlutterHost({ url, origin, partition, onLoading, onReady, onError }: FlutterHostProps) {
  const elementRef = useRef<HTMLWebViewElement | null>(null)
  const currentUrlRef = useRef<string>(url)

  // Reflect the guest's own address bar so "Open in browser" and the OAuth
  // return always act on where the app actually is.
  const trackCurrentUrl = (element: HTMLWebViewElement) => {
    try {
      const live = element.getURL()
      if (live) currentUrlRef.current = live
    } catch {
      // The guest is not attached yet; keep the last known URL.
    }
  }

  useEffect(() => {
    const element = elementRef.current
    if (!element) return

    const handleStart = () => onLoading()
    const handleStop = () => {
      trackCurrentUrl(element)
      onReady()
    }
    const handleNavigate = () => trackCurrentUrl(element)
    const handleFail = (event: Event) => {
      const failure = event as WebviewLoadEvent
      // Sub-resource failures and aborted navigations are normal and must not
      // tear the app down.
      if (failure.isMainFrame === false) return
      if (failure.errorCode === ERR_ABORTED) return
      const detail = [
        failure.errorDescription ?? 'The application failed to load.',
        failure.errorCode !== undefined ? `(error ${failure.errorCode})` : '',
        failure.validatedURL ?? ''
      ]
        .filter(Boolean)
        .join(' ')
      onError(detail)
    }

    const handleDomReady = () => trackCurrentUrl(element)

    element.addEventListener('did-start-loading', handleStart)
    element.addEventListener('did-stop-loading', handleStop)
    element.addEventListener('dom-ready', handleDomReady)
    element.addEventListener('did-navigate', handleNavigate)
    element.addEventListener('did-navigate-in-page', handleNavigate)
    element.addEventListener('did-fail-load', handleFail)

    return () => {
      element.removeEventListener('did-start-loading', handleStart)
      element.removeEventListener('did-stop-loading', handleStop)
      element.removeEventListener('dom-ready', handleDomReady)
      element.removeEventListener('did-navigate', handleNavigate)
      element.removeEventListener('did-navigate-in-page', handleNavigate)
      element.removeEventListener('did-fail-load', handleFail)
    }
  }, [url, onLoading, onReady, onError])

  useEffect(() => {
    return window.ndu.onMenuCommand((command: MenuCommand) => {
      const element = elementRef.current
      if (!element) return

      switch (command.type) {
        case 'reload':
          element.reload()
          break

        case 'hard-reload':
          element.reloadIgnoringCache()
          break

        case 'navigate': {
          if (!origin) break
          const route = command.route.startsWith('/') ? command.route : `/${command.route}`
          void element.loadURL(`${origin}/#${route}`)
          break
        }

        case 'oauth-callback': {
          trackCurrentUrl(element)
          try {
            const next = new URL(currentUrlRef.current)
            next.search = command.query
            void element.loadURL(next.toString())
          } catch {
            if (origin) void element.loadURL(`${origin}/${command.query}`)
          }
          break
        }

        case 'toggle-devtools':
          if (element.isDevToolsOpened()) element.closeDevTools()
          else element.openDevTools()
          break

        case 'zoom': {
          const current = element.getZoomFactor()
          const next =
            command.direction === 'reset'
              ? 1
              : command.direction === 'in'
                ? Math.min(MAX_ZOOM, current + ZOOM_STEP)
                : Math.max(MIN_ZOOM, current - ZOOM_STEP)
          element.setZoomFactor(Number(next.toFixed(2)))
          break
        }

        case 'open-in-browser':
          trackCurrentUrl(element)
          void window.ndu.openExternal(currentUrlRef.current)
          break
      }
    })
  }, [origin])

  return (
    <webview
      ref={elementRef}
      className="shell__webview"
      src={url}
      partition={partition}
      allowpopups={true}
    />
  )
}
