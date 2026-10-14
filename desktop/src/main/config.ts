import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'

/** Custom protocol the Flutter app already uses for OAuth returns. */
export const APP_SCHEME = 'nduproject'

/** The shell opens on the authentication page. */
export const DEFAULT_INITIAL_ROUTE = '/sign-in'

/**
 * Directory that holds the Flutter web build (`index.html`, `main.dart.js`,
 * `canvaskit/`, ...).
 *
 * Resolution order:
 *  1. `NDU_WEB_DIR` — explicit override (useful for pointing at a fresh build).
 *  2. `<resources>/web` — where electron-builder copies it for a packaged app.
 *  3. `<repo>/build/web` — the standard `flutter build web` output in this repo.
 */
export function resolveWebRoot(): string {
  const candidates = [
    process.env.NDU_WEB_DIR,
    process.resourcesPath ? join(process.resourcesPath, 'web') : undefined,
    // out/main -> out -> desktop -> <repo>
    resolve(__dirname, '..', '..', '..', 'build', 'web'),
    resolve(process.cwd(), '..', 'build', 'web'),
    resolve(process.cwd(), 'build', 'web')
  ].filter((candidate): candidate is string => Boolean(candidate))

  for (const candidate of candidates) {
    if (existsSync(join(candidate, 'index.html'))) return candidate
  }
  // Nothing found: return the packaged location so the error message is
  // actionable rather than a bare "undefined".
  return candidates[1] ?? candidates[0]
}

/**
 * Where the shell loads the application from when nothing overrides it.
 *
 * The desktop app *is* the web application, and staging is the deployment the
 * rest of the team is looking at. A shell started with no environment set
 * therefore renders exactly what the browser shows, rather than a local
 * snapshot that can drift from it.
 */
export const DEFAULT_REMOTE_URL = 'https://staging.nduproject.com'

/**
 * The remote origin to load, or `null` to serve a local build instead.
 *
 * Resolution order:
 *  1. `NDU_WEB_URL` — an explicit origin: any deployment, or a local dev
 *     server.
 *  2. `NDU_WEB_DIR` — an explicitly named local build wins over the default,
 *     so the documented "point at a fresh build" workflow still works.
 *  3. [`DEFAULT_REMOTE_URL`] — the hosted staging deployment.
 *
 * A packaged app resolves the same way, so it also loads staging: point
 * `NDU_WEB_DIR` at its bundled `<resources>/web` to run the snapshot it
 * shipped with instead. Because the default is remote, the shell needs network
 * access at start-up; it says so on screen rather than failing silently.
 */
export function resolveRemoteUrl(): string | null {
  const explicitUrl = process.env.NDU_WEB_URL?.trim()
  if (explicitUrl) return explicitUrl.replace(/\/+$/, '')
  if (process.env.NDU_WEB_DIR?.trim()) return null
  return DEFAULT_REMOTE_URL
}

/** The route the shell opens on, driven by `NDU_INITIAL_ROUTE`. */
export function resolveInitialRoute(): string {
  const raw = process.env.NDU_INITIAL_ROUTE?.trim()
  if (!raw) return DEFAULT_INITIAL_ROUTE
  return raw.startsWith('/') ? raw : `/${raw}`
}

/**
 * The app uses go_router's hash URL strategy, so a route is reached at
 * `/#/sign-in` rather than `/sign-in`.
 */
export function routeToHashUrl(origin: string, route: string): string {
  const path = route.startsWith('/') ? route : `/${route}`
  return `${origin}/#${path}`
}

/**
 * Maps an `nduproject://` deep link onto a route in the embedded app.
 *
 * - `nduproject://sign-in` -> `/sign-in`
 * - `nduproject://project/42` -> `/project/42`
 *
 * The OAuth return link (`nduproject://oauth2redirect?code=...`) is handled
 * separately by the caller, because the Flutter app reads those parameters
 * from the address bar's query string rather than from the route.
 */
export function deepLinkToRoute(deepLink: string): string | null {
  let parsed: URL
  try {
    parsed = new URL(deepLink)
  } catch {
    return null
  }
  if (parsed.protocol !== `${APP_SCHEME}:`) return null

  const host = parsed.hostname || ''
  const path = parsed.pathname === '/' ? '' : parsed.pathname
  if (!host && !path) return null

  const query = parsed.search || ''
  return `/${host}${path}${query}`.replace(/\/{2,}/g, '/')
}

/**
 * Host named in the app's OAuth redirect URI. Deep links with this host carry
 * authorization parameters back to the already-running web app.
 */
export const OAUTH_CALLBACK_HOST = 'oauth2redirect'
