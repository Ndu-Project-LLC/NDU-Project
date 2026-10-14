/**
 * Shown while the embedded app is loading.
 *
 * The markup and colours deliberately mirror the loader in the Flutter build's
 * own `index.html`, so the moment the shell hands over to the web app is not
 * visible as a second, different spinner.
 */
export function LoadingOverlay() {
  return (
    <div className="boot" role="status" aria-live="polite">
      <div className="boot__brand">
        NDU <span className="boot__brand-accent">Project</span>
      </div>
      <div className="boot__spinner" />
      <div className="boot__text">Loading NDU Project…</div>
    </div>
  )
}
