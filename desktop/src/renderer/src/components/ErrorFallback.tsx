interface ErrorFallbackProps {
  title: string
  message: string
  onRetry: () => void
  onOpenInBrowser?: () => void
}

/**
 * Replaces the app surface when the embedded build cannot be loaded.
 *
 * A silent failure here would look exactly like a slow load — a blank dark
 * window — so the shell always says what went wrong and offers a way forward.
 */
export function ErrorFallback({ title, message, onRetry, onOpenInBrowser }: ErrorFallbackProps) {
  return (
    <div className="failure" role="alert">
      <div className="failure__card">
        <h1 className="failure__title">{title}</h1>
        <p className="failure__message">{message}</p>
        <div className="failure__actions">
          <button className="button button--primary" type="button" onClick={onRetry}>
            Try again
          </button>
          {onOpenInBrowser ? (
            <button className="button button--secondary" type="button" onClick={onOpenInBrowser}>
              Open in browser
            </button>
          ) : null}
        </div>
      </div>
    </div>
  )
}
