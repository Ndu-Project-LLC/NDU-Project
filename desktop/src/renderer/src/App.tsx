import { useCallback, useEffect, useRef, useState } from 'react'
import type { AppInfo, WebAppState } from '@shared/ipc'
import { ErrorFallback } from './components/ErrorFallback'
import { FlutterHost } from './components/FlutterHost'
import { LoadingOverlay } from './components/LoadingOverlay'

/** Must match the partition the main process hardens in `hardenWebviewSession`. */
const WEBVIEW_PARTITION = 'persist:ndu'

export default function App() {
  const [appInfo, setAppInfo] = useState<AppInfo | null>(null)
  const [bootError, setBootError] = useState<string | null>(null)
  const [appState, setAppState] = useState<WebAppState>('loading')
  const [failure, setFailure] = useState<string | null>(null)
  /** Bumped to remount the host, which is how "Try again" reloads the app. */
  const [attempt, setAttempt] = useState(0)
  /** `did-stop-loading` fires many times per session; report the first only. */
  const reportedReadyRef = useRef(false)

  useEffect(() => {
    let cancelled = false
    window.ndu
      .getAppInfo()
      .then((info) => {
        if (!cancelled) setAppInfo(info)
      })
      .catch((error: unknown) => {
        if (!cancelled) {
          setBootError(error instanceof Error ? error.message : String(error))
        }
      })
    return () => {
      cancelled = true
    }
  }, [])

  const handleLoading = useCallback(() => {
    setAppState('loading')
  }, [])

  const handleReady = useCallback(() => {
    setFailure(null)
    setAppState('ready')
    if (!reportedReadyRef.current) {
      reportedReadyRef.current = true
      window.ndu.reportState('ready')
    }
  }, [])

  const handleError = useCallback((detail: string) => {
    setFailure(detail)
    setAppState('error')
    window.ndu.reportState('error', detail)
  }, [])

  const handleRetry = useCallback(() => {
    setFailure(null)
    setAppState('loading')
    reportedReadyRef.current = false
    setAttempt((value) => value + 1)
  }, [])

  const handleReloadShell = useCallback(() => {
    window.location.reload()
  }, [])

  if (bootError) {
    return (
      <ErrorFallback
        title="NDU Project could not start"
        message={bootError}
        onRetry={handleReloadShell}
      />
    )
  }

  if (!appInfo) {
    return <LoadingOverlay />
  }

  if (!appInfo.webAppUrl) {
    return (
      <ErrorFallback
        title="Application build not found"
        message={
          'The desktop shell could not locate the Flutter web build.\n\n' +
          'Build it with `flutter build web` (or `./deploy.sh`) so that ' +
          '`build/web/index.html` exists, or point the shell at a deployment ' +
          'with the NDU_WEB_URL environment variable.'
        }
        onRetry={handleRetry}
      />
    )
  }

  const openInBrowser = () => {
    if (appInfo.webAppOrigin) void window.ndu.openExternal(appInfo.webAppOrigin)
  }

  return (
    <div className="shell">
      <FlutterHost
        key={attempt}
        url={appInfo.webAppUrl}
        origin={appInfo.webAppOrigin}
        partition={WEBVIEW_PARTITION}
        onLoading={handleLoading}
        onReady={handleReady}
        onError={handleError}
      />

      {appState === 'loading' && !failure ? <LoadingOverlay /> : null}

      {failure ? (
        <ErrorFallback
          title="NDU Project could not load"
          message={failure}
          onRetry={handleRetry}
          onOpenInBrowser={openInBrowser}
        />
      ) : null}
    </div>
  )
}
