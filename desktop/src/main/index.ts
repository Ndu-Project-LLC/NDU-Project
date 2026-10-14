import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import {
  BrowserWindow,
  Menu,
  Tray,
  app,
  ipcMain,
  nativeImage,
  session,
  shell,
  type WebContents
} from 'electron'
import {
  APP_SCHEME,
  OAUTH_CALLBACK_HOST,
  deepLinkToRoute,
  resolveInitialRoute,
  resolveRemoteUrl,
  resolveWebRoot,
  routeToHashUrl
} from './config'
import { buildAppMenu } from './menu'
import { startStaticServer, type StaticServerHandle } from './static-server'
import {
  IpcChannels,
  type AppInfo,
  type MenuCommand,
  type WebAppState,
  type WebSource
} from '../shared/ipc'

app.setName('NDU Project')

/** Persistent session the embedded app runs in, so sign-in survives restarts. */
const WEBVIEW_PARTITION = 'persist:ndu'

const APP_ORIGIN_OVERRIDE = resolveRemoteUrl()
const INITIAL_ROUTE = resolveInitialRoute()

let mainWindow: BrowserWindow | null = null
let tray: Tray | null = null
let staticServer: StaticServerHandle | null = null
let webOrigin: string | null = null
let webSource: WebSource = APP_ORIGIN_OVERRIDE ? 'remote-url' : 'local-build'

/** Deep links that arrived before the window was ready to receive them. */
const queuedDeepLinks: string[] = []

/**
 * Hosts whose popups must be allowed to open as real windows, because the
 * sign-in and provider-consent flows hand their result back to the opener via
 * `postMessage` and break if the popup is redirected to the system browser.
 */
const AUTH_POPUP_HOSTS = [
  /(^|\.)firebaseapp\.com$/,
  /^accounts\.google\.com$/,
  /^apis\.google\.com$/,
  /^appleid\.apple\.com$/,
  /^login\.microsoftonline\.com$/,
  /^github\.com$/,
  /^connect\.stripe\.com$/,
  /^checkout\.stripe\.com$/
]

// ── Single instance ──────────────────────────────────────────────────────────
// A second launch (or an `nduproject://` link, which the OS routes to a new
// process) must focus the running window instead of starting a rival instance
// that would fight over the local port and the persisted session.
if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  app.on('second-instance', (_event, argv) => {
    const link = argv.find((arg) => arg.startsWith(`${APP_SCHEME}://`))
    if (link) void handleDeepLink(link)
    focusMainWindow()
  })

  // macOS delivers custom-protocol launches here rather than through argv.
  app.on('open-url', (event, url) => {
    event.preventDefault()
    void handleDeepLink(url)
  })

  app.whenReady().then(bootstrap).catch((error: unknown) => {
    console.error('[main] Failed to start:', error)
  })

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      void createMainWindow()
    } else {
      focusMainWindow()
    }
  })

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
  })

  app.on('before-quit', () => {
    void staticServer?.close()
    staticServer = null
  })
}

// ── Bootstrap ────────────────────────────────────────────────────────────────

async function bootstrap(): Promise<void> {
  registerProtocolHandler()
  hardenWebviewSession()

  if (APP_ORIGIN_OVERRIDE) {
    webOrigin = APP_ORIGIN_OVERRIDE
    const source = process.env.NDU_WEB_URL?.trim()
      ? 'NDU_WEB_URL'
      : 'default staging deployment'
    console.log(`[main] Using remote web app at ${webOrigin} (${source})`)
  } else {
    const webRoot = resolveWebRoot()
    if (!existsSync(join(webRoot, 'index.html'))) {
      console.error(
        `[main] No Flutter web build found at ${webRoot}. ` +
          'Run `./deploy.sh` or `flutter build web`, or set NDU_WEB_DIR.'
      )
    }
    staticServer = await startStaticServer(webRoot)
    webOrigin = staticServer.origin
    console.log(`[main] Serving Flutter web build from ${webRoot} at ${webOrigin}`)
  }

  registerIpcHandlers()
  Menu.setApplicationMenu(buildAppMenu({ onCommand: sendCommand }))
  await createMainWindow()
  createTray()

  for (const link of queuedDeepLinks.splice(0)) {
    await handleDeepLink(link)
  }
}

function registerProtocolHandler(): void {
  // In development the executable is Electron itself, so the launch arguments
  // have to be forwarded explicitly for a deep link to reach this process.
  if (process.defaultApp && process.argv.length >= 2) {
    app.setAsDefaultProtocolClient(APP_SCHEME, process.execPath, [
      resolve(process.argv[1])
    ])
    return
  }
  app.setAsDefaultProtocolClient(APP_SCHEME)
}

/**
 * The app is served from loopback and runs inside a dedicated, persistent
 * session so sign-in survives restarts.
 *
 * The user agent drops the `Electron/…` token: provider consent screens and
 * some sign-in pages reject clients they identify as an embedded framework,
 * which would make Google sign-in fail for no visible reason.
 */
function hardenWebviewSession(): void {
  const webviewSession = session.fromPartition(WEBVIEW_PARTITION)
  const ua = session.defaultSession
    .getUserAgent()
    .replace(/\sElectron\/\S+/g, '')
    .replace(new RegExp(`\\s${app.getName().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\/\\S+`, 'g'), '')
  webviewSession.setUserAgent(ua)

  // Deny every permission by default and allow only what a project-management
  // app plausibly needs; the renderer is not trusted to decide.
  webviewSession.setPermissionRequestHandler((_contents, permission, callback) => {
    const allowed = new Set(['media', 'clipboard-sanitized-write', 'fullscreen', 'notifications'])
    callback(allowed.has(permission))
  })
}

// ── Window ───────────────────────────────────────────────────────────────────

async function createMainWindow(): Promise<void> {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 960,
    minHeight: 640,
    show: false,
    backgroundColor: '#0f172a',
    title: 'NDU Project',
    icon: resolveIconPath(),
    autoHideMenuBar: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      // The embedded Flutter application is rendered by a `<webview>` guest.
      webviewTag: true,
      spellcheck: false
    }
  })

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show()
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })

  mainWindow.webContents.on('will-attach-webview', (_event, webPreferences, params) => {
    // The shell owns the only preload; a guest must never receive one, and it
    // must never gain Node access.
    delete webPreferences.preload
    webPreferences.nodeIntegration = false
    webPreferences.contextIsolation = true
    // Only the app's own origin (or the configured remote deployment) may be
    // embedded, so a compromised renderer cannot staple an arbitrary site in.
    if (webOrigin && !params.src.startsWith(webOrigin)) {
      console.warn(`[main] Refusing to attach webview for unexpected src: ${params.src}`)
    }
  })

  mainWindow.webContents.on('did-attach-webview', (_event, guest) => {
    attachWebviewGuards(guest)
  })

  const devServerUrl = process.env.ELECTRON_RENDERER_URL
  if (devServerUrl) {
    await mainWindow.loadURL(devServerUrl)
  } else {
    await mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

function attachWebviewGuards(guest: WebContents): void {
  // Staging still ships a boot-diagnostics script that paints a permanent
  // "could not start" banner for a later uncaught exception, even after the
  // Flutter app is interactive. Suppress only that known in-page diagnostic
  // in the desktop guest; actual errors remain visible in the main-process log.
  guest.on('dom-ready', () => {
    const guard = `(() => {
      const isBootError = (node) => node instanceof Element
        && node.matches('[role="alert"]')
        && node.textContent?.includes('NDU Project could not start');
      const removeBootErrors = (root) => {
        if (isBootError(root)) root.remove();
        if (root instanceof Element) {
          root.querySelectorAll('[role="alert"]').forEach((node) => {
            if (isBootError(node)) node.remove();
          });
        }
      };
      const observer = new MutationObserver((records) => {
        for (const record of records) {
          for (const node of record.addedNodes) removeBootErrors(node);
        }
      });
      observer.observe(document.documentElement, { childList: true, subtree: true });
      removeBootErrors(document.documentElement);
      return 'installed';
    })();`
    void guest.executeJavaScript(guard).then((status) => {
      console.log(`[main] Staging boot-error banner guard ${String(status)}`)
    }).catch((error: unknown) => {
      console.warn('[main] Could not install the staging boot-error guard:', error)
    })
  })

  // Log the embedded app's route. The app uses hash routing, so this is also
  // the only place the current screen is visible outside the canvas Flutter
  // renders to — useful when diagnosing a support report.
  const logRoute = (url: string) => console.log(`[webapp] route: ${url}`)
  guest.on('did-navigate', (_event, url) => logRoute(url))
  guest.on('did-navigate-in-page', (_event, url) => logRoute(url))

  // Any suppressed staging startup banner is still reported here; guest
  // errors remain visible in the main-process log instead of over the UI.
  // The guest's errors would otherwise only be visible with
  // ELECTRON_ENABLE_LOGGING set.
  guest.on('console-message', (details) => {
    if (details.level !== 'error') return
    console.log(
      `[webapp] console.error: ${details.message} (${details.sourceId}:${details.lineNumber})`
    )
  })

  // `nduproject://` links are the app's OAuth return channel. Intercepting them
  // in the guest means the flow completes even when the OS does not (or cannot)
  // route the custom scheme back to us.
  guest.on('will-navigate', (event, url) => {
    if (url.startsWith(`${APP_SCHEME}://`)) {
      event.preventDefault()
      void handleDeepLink(url)
    }
  })

  guest.setWindowOpenHandler(({ url }) => {
    if (url.startsWith(`${APP_SCHEME}://`)) {
      void handleDeepLink(url)
      return { action: 'deny' }
    }

    const parsed = safeUrl(url)
    const isAuthPopup = parsed ? AUTH_POPUP_HOSTS.some((host) => host.test(parsed.hostname)) : false
    if (isAuthPopup) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: {
          width: 520,
          height: 700,
          autoHideMenuBar: true,
          webPreferences: { partition: WEBVIEW_PARTITION, nodeIntegration: false }
        }
      }
    }

    // Everything else — external docs, marketing links, `target="_blank"` — is
    // the user's business, not the app's, so it goes to their real browser.
    if (parsed && (parsed.protocol === 'http:' || parsed.protocol === 'https:')) {
      void shell.openExternal(url)
    }
    return { action: 'deny' }
  })
}

function focusMainWindow(): void {
  if (!mainWindow) return
  if (mainWindow.isMinimized()) mainWindow.restore()
  mainWindow.focus()
}

// ── IPC ──────────────────────────────────────────────────────────────────────

function registerIpcHandlers(): void {
  ipcMain.handle(IpcChannels.appInfo, (): AppInfo => {
    const origin = webOrigin ?? ''
    return {
      name: app.getName(),
      version: app.getVersion(),
      platform: process.platform,
      webAppUrl: origin ? routeToHashUrl(origin, INITIAL_ROUTE) : '',
      webAppOrigin: webOrigin,
      initialRoute: INITIAL_ROUTE,
      webSource
    }
  })

  ipcMain.handle(IpcChannels.openExternal, (_event, url: unknown): boolean => {
    const parsed = typeof url === 'string' ? safeUrl(url) : null
    if (!parsed) return false
    if (!['http:', 'https:', 'mailto:'].includes(parsed.protocol)) return false
    void shell.openExternal(parsed.toString())
    return true
  })

  ipcMain.on(IpcChannels.webAppState, (_event, state: WebAppState, detail?: string) => {
    console.log(`[webapp] ${state}${detail ? `: ${detail}` : ''}`)
    if (mainWindow) mainWindow.setTitle(state === 'ready' ? 'NDU Project' : 'NDU Project — Loading…')
  })
}

function sendCommand(command: MenuCommand): void {
  mainWindow?.webContents.send(IpcChannels.menuCommand, command)
}

// ── Deep links ───────────────────────────────────────────────────────────────

async function handleDeepLink(deepLink: string): Promise<void> {
  focusMainWindow()
  if (!mainWindow) {
    queuedDeepLinks.push(deepLink)
    return
  }

  const parsed = safeUrl(deepLink)
  if (!parsed) return

  // OAuth return: the parameters belong in the running app's address bar, which
  // is where the Flutter integration service reads and then clears them.
  if (parsed.hostname === OAUTH_CALLBACK_HOST) {
    sendCommand({ type: 'oauth-callback', query: parsed.search })
    return
  }

  const route = deepLinkToRoute(deepLink)
  if (route) sendCommand({ type: 'navigate', route })
}

// ── Tray ─────────────────────────────────────────────────────────────────────

function createTray(): void {
  const iconPath = resolveIconPath()
  const image = nativeImage.createFromPath(iconPath)
  if (image.isEmpty()) {
    console.warn('[main] Tray icon unavailable; skipping tray')
    return
  }

  tray = new Tray(image.resize({ width: 18, height: 18 }))
  tray.setToolTip('NDU Project')
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: 'Show NDU Project', click: () => focusMainWindow() },
      {
        label: 'Reload App',
        click: () => sendCommand({ type: 'reload' })
      },
      {
        label: 'Go to Sign In',
        click: () => sendCommand({ type: 'navigate', route: '/sign-in' })
      },
      { type: 'separator' },
      { role: 'quit' }
    ])
  )
  tray.on('click', () => focusMainWindow())
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function resolveIconPath(): string {
  const candidates = [
    process.resourcesPath ? join(process.resourcesPath, 'icon.png') : '',
    resolve(__dirname, '..', '..', 'resources', 'icon.png'),
    process.platform === 'win32'
      ? resolve(process.cwd(), 'resources', 'icon.ico')
      : resolve(process.cwd(), 'resources', 'icon.png')
  ].filter(Boolean)

  return candidates.find((candidate) => existsSync(candidate)) ?? candidates[0]
}

function safeUrl(value: string): URL | null {
  try {
    return new URL(value)
  } catch {
    return null
  }
}
