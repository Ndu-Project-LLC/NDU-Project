# NDU Project — Desktop (Electron + React)

A desktop build of the NDU Project. The Flutter application is **retained
unchanged for the web**; this package is an Electron shell, written in React +
TypeScript, that runs the existing Flutter web build inside a native window.

Because the shell hosts the real web build rather than re-implementing it, the
desktop app *is* the web application — same screens, same Firebase data, same
behaviour — with the native window, menu bar, tray and deep links a desktop user
expects added around it.

## How it works

```
┌─ Electron main process (src/main) ────────────────────────────────┐
│  • loads the staging deployment by default                          │
│    (or serves build/web over loopback when NDU_WEB_DIR is set)     │
│  • creates the BrowserWindow, native menu bar and tray            │
│  • routes nduproject:// deep links into the running app            │
│  • guards webview attachments, popups and navigation               │
└───────────────────────────────┬───────────────────────────────────┘
                                │ preload (contextBridge → window.ndu)
┌───────────────────────────────▼───────────────────────────────────┐
│  React renderer (src/renderer) — a thin host:                      │
│  • <webview partition="persist:ndu"> loads /#/sign-in             │
│  • boot overlay + failure screen                                   │
│  • applies shell commands (reload, navigate, zoom, devtools)       │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                    the Flutter web application
```

### Where the app is loaded from

The shell loads **`https://staging.nduproject.com`** by default, so a clone with
nothing configured renders the same build as the browser. Resolution order:

1. `NDU_WEB_URL` — an explicit origin (any deployment, or a local dev server)
2. `NDU_WEB_DIR` — an explicitly named local build
3. the staging deployment

Three decisions worth knowing about:

- **A loopback static server, not `file://`.** Flutter web needs an HTTP origin
  for its engine fetches (`main.dart.js`, `canvaskit.wasm`) and for the storage
  the app relies on (IndexedDB, localStorage). The server binds an ephemeral
  port on `127.0.0.1`, so it is unreachable from outside the machine, never
  collides with a dev server, and revalidates instead of caching.
- **A `<webview>` guest, not an `<iframe>`.** The embedded app runs as a
  top-level browsing context with its own storage. That is what keeps
  Google/Firebase sign-in popups, the custom-protocol OAuth return and
  third-party cookie policy working the way they do in a browser tab; in a
  cross-origin iframe those are the first things to break.
- **A persistent, hardened session.** The guest runs in `persist:ndu`, so
  sign-in survives a restart. Its user agent drops the `Electron/…` token
  (provider consent screens reject clients that look like embedded frameworks)
  and every permission is denied except `media`,
  `clipboard-sanitized-write`, `fullscreen` and `notifications`.

## Prerequisites

By default there are none: the shell loads the staging deployment, so `npm run
dev` works on a fresh clone with no build present.

To run against a **local** build instead, one must exist:

```bash
# from the repository root
flutter build web          # -> build/web
# or
./deploy.sh                # -> build/web (production pipeline)
```

and the shell must be pointed at it with `NDU_WEB_DIR`. `src/main/config.ts`
resolves the directory in this order:

1. `NDU_WEB_DIR` (explicit override)
2. `<resources>/web` — where a packaged app ships it
3. `<repo>/build/web` — the standard output of `flutter build web`

## Running

```bash
cd desktop
npm install       # once

npm run dev       # Vite dev server + Electron, with hot reload for the shell
npm run build     # compile main, preload and renderer into out/
npm start         # run the compiled build
```

`npm run dev` hot-reloads the React shell. The Flutter application comes from
staging, so it changes when staging is deployed — nothing to rebuild locally
unless you point the shell at a local build with `NDU_WEB_DIR`.

### Environment variables

| Variable             | Effect                                                             |
| -------------------- | ------------------------------------------------------------------ |
| `NDU_WEB_DIR`        | Serve this local Flutter web build instead of staging.              |
| `NDU_WEB_URL`        | Load this origin instead of staging (another deployment, or a dev server). |
| `NDU_INITIAL_ROUTE`  | Route to open on launch. Defaults to `/sign-in`.                    |

```bash
# Default: the hosted staging deployment
npm run dev

# A specific deployment
NDU_WEB_URL=https://nduproject.com npm run dev

# A local build you just made
NDU_WEB_DIR=$(cd .. && pwd)/build/web npm run dev
```

## The shell opens on the sign-in page

The app uses go_router's hash URL strategy, so routes look like `/#/sign-in`.
The shell launches on `/sign-in` (`NDU_INITIAL_ROUTE` overrides this). This is
also why the loader in `index.html` and the shell's own boot overlay look the
same: the hand-off from shell to app should not read as a second start-up.

## Native features

- **Menu bar** — File/Edit/View/Window/Help, plus Go to Sign In, Reload App,
  Reload App (Ignore Cache), zoom, full screen, developer tools and "Open NDU
  Project in Browser".
- **Tray** — show the window, reload, go to sign-in, quit.
- **Deep links** — the `nduproject://` scheme is registered. A link such as
  `nduproject://create-account` opens the running app at `/create-account`
  (a second launch focuses the existing window instead of starting a rival
  instance). `nduproject://oauth2redirect?code=…` is the app's OAuth return
  channel: its query string is handed to the running app, which is where the
  Flutter integration service reads and then clears it.
- **External links** — `target="_blank"` links and anything that is not an
  in-app route open in the user's real browser. Sign-in popups
  (Firebase, Google, Apple, Microsoft, GitHub, Stripe) are allowed to open as
  real windows so their `postMessage` hand-back works.

## Packaging

```bash
npm run package        # current platform
npm run package:mac    # also: package:win, package:linux
```

`electron-builder.yml` copies `build/web` to `<resources>/web` in the packaged
app and registers the `nduproject://` scheme with the installer. **Rebuild the
Flutter web app before packaging** — the packaged resource is a snapshot.

## Layout

```
desktop/
  electron.vite.config.ts   build config (main / preload / renderer)
  electron-builder.yml      packaging config
  resources/icon.png        app + tray icon
  src/
    shared/ipc.ts           the IPC contract shared by all three processes
    main/
      index.ts              lifecycle, window, menu, tray, deep links, IPC
      config.ts             web-build discovery, origins, deep-link mapping
      static-server.ts      loopback server for the Flutter build
      menu.ts               native menu builder
    preload/index.ts        contextBridge → window.ndu
    renderer/               React shell (App, FlutterHost, overlays)
```

## One deliberate difference from the web build

The Flutter build's `index.html` ships a "boot diagnostics" script that paints
a full-width red banner over the page whenever any uncaught error fires. On the
web that is a sensible last resort. In the desktop shell it is misleading: it
covers the app while the app underneath is still running and interactive, and it
never clears, so one transient background error makes the session look broken.

When the shell serves a local build, its static server removes that block from
the copy of `index.html` it hands to the webview (`BOOT_DIAGNOSTICS_BLOCK` in
`src/main/static-server.ts`). When loading hosted staging, the guest installs a
narrow compatibility guard that removes only this specific banner; guest
`console.error` output is still reported to the main-process log as
`[webapp] console.error: …`, and genuine navigation failures still use the
shell's failure screen. The web source also limits the diagnostic to boot-time
errors, so future deployments won't label post-start runtime exceptions as
startup failures. If the local HTML block is renamed, the static server logs a
warning and serves it unchanged rather than guessing.

## Failure modes

The shell never fails silently: a missing build, an unreachable server or a
failed navigation produces a screen that says what went wrong, with **Try
again** and **Open in browser**.

- *"Application build not found"* — `NDU_WEB_DIR` points at a directory with no
  `index.html`; run `flutter build web` or drop `NDU_WEB_DIR`.
- *"NDU Project could not load"* — the guest failed to load; the message
  includes the Chromium error code and URL.

Main-process logging (`[main]`, `[webapp]`) is on stdout; run with
`ELECTRON_ENABLE_LOGGING=1` to also see the embedded app's console output.
