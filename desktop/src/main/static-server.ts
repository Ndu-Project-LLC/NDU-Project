import { createReadStream, promises as fs } from 'node:fs'
import { createServer, type Server } from 'node:http'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { extname, join, resolve, sep } from 'node:path'

/**
 * Minimal static file server for the Flutter web build.
 *
 * Why serve at all: Flutter web needs an HTTP origin. Loading `index.html`
 * from `file://` breaks the engine's fetches for `main.dart.js`,
 * `canvaskit.wasm` and its assets, and disables the storage the app uses
 * (IndexedDB, service worker, localStorage). A loopback server gives the
 * embedded app an ordinary, secure-looking origin instead.
 *
 * The server binds to an ephemeral port on 127.0.0.1 so it is never reachable
 * from outside the machine and never collides with a running dev server.
 */

const MIME_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.pdf': 'application/pdf',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mp3': 'audio/mpeg',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8'
}

export interface StaticServerHandle {
  /** Origin the app can be loaded from, e.g. `http://127.0.0.1:52311`. */
  readonly origin: string
  readonly port: number
  close(): Promise<void>
}

/**
 * The Flutter build's "boot diagnostics" script: a comment, then an inline
 * script that paints a full-width red banner over the page whenever any
 * uncaught error fires.
 *
 * It is removed from the copy this server serves. On the web that banner is a
 * deliberate last resort, but in the desktop shell it is misleading: it covers
 * the app while the app underneath is still running and interactive, and it
 * never clears, so a transient background error looks like a dead app for the
 * rest of the session. The desktop shell owns failure reporting — it shows its
 * own screen when the app genuinely cannot load, and the main process logs the
 * guest's console errors — so the in-page banner is redundant here.
 *
 * Anchored on the comment so it cannot match an earlier `<!--` in the file,
 * and matched non-greedily up to the first `</script>` after it.
 */
const BOOT_DIAGNOSTICS_BLOCK = /<!--\s*Boot diagnostics[\s\S]*?<\/script>\s*/i

async function loadIndexHtml(indexPath: string): Promise<Buffer> {
  const html = await fs.readFile(indexPath, 'utf8')
  if (!BOOT_DIAGNOSTICS_BLOCK.test(html)) {
    // A different build layout. Serve it untouched rather than guessing.
    console.warn(
      '[server] Boot-diagnostics block not found in index.html; serving it unchanged.'
    )
    return Buffer.from(html, 'utf8')
  }
  return Buffer.from(html.replace(BOOT_DIAGNOSTICS_BLOCK, ''), 'utf8')
}

export async function startStaticServer(rootDir: string): Promise<StaticServerHandle> {
  const root = resolve(rootDir)
  const indexPath = join(root, 'index.html')
  const indexHtml = await loadIndexHtml(indexPath)

  const server: Server = createServer((req, res) => {
    void handleRequest(req, res, root, indexPath, indexHtml)
  })

  await new Promise<void>((resolveListen, rejectListen) => {
    server.once('error', rejectListen)
    server.listen(0, '127.0.0.1', () => {
      server.removeListener('error', rejectListen)
      resolveListen()
    })
  })

  const address = server.address()
  if (address === null || typeof address === 'string') {
    await closeServer(server)
    throw new Error('Static server did not report a port')
  }

  return {
    origin: `http://127.0.0.1:${address.port}`,
    port: address.port,
    close: () => closeServer(server)
  }
}

function closeServer(server: Server): Promise<void> {
  return new Promise((resolveClose) => {
    server.close(() => resolveClose())
  })
}

async function handleRequest(
  req: IncomingMessage,
  res: ServerResponse,
  root: string,
  indexPath: string,
  indexHtml: Buffer
): Promise<void> {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' })
    res.end()
    return
  }

  let pathname: string
  try {
    pathname = decodeURIComponent(new URL(req.url ?? '/', 'http://127.0.0.1').pathname)
  } catch {
    res.writeHead(400)
    res.end()
    return
  }

  const filePath = await resolveRequestPath(root, pathname)
  if (!filePath) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' })
    res.end('Not found')
    return
  }

  let stat: Awaited<ReturnType<typeof fs.stat>>
  try {
    stat = await fs.stat(filePath)
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' })
    res.end('Not found')
    return
  }

  const contentType = MIME_TYPES[extname(filePath).toLowerCase()] ?? 'application/octet-stream'
  const isIndex = filePath === indexPath
  const headers: Record<string, string> = {
    'Content-Type': contentType,
    // The app does its own build-stamp cache busting; a stale local cache would
    // fight it. Revalidation is cheap on loopback.
    'Cache-Control': isIndex ? 'no-store' : 'no-cache',
    'Accept-Ranges': 'bytes',
    // The build is ours; keep the embedded app from being framed by anyone.
    'X-Content-Type-Options': 'nosniff'
  }

  // The entry point is served from memory so the desktop transformation below
  // applies; every other file streams straight from disk.
  if (isIndex) {
    headers['Content-Length'] = String(indexHtml.byteLength)
    res.writeHead(200, headers)
    if (req.method === 'HEAD') {
      res.end()
      return
    }
    res.end(indexHtml)
    return
  }

  const range = parseRange(req.headers.range, stat.size)
  if (range) {
    const { start, end } = range
    headers['Content-Range'] = `bytes ${start}-${end}/${stat.size}`
    headers['Content-Length'] = String(end - start + 1)
    res.writeHead(206, headers)
    if (req.method === 'HEAD') {
      res.end()
      return
    }
    createReadStream(filePath, { start, end }).pipe(res)
    return
  }

  headers['Content-Length'] = String(stat.size)
  res.writeHead(200, headers)
  if (req.method === 'HEAD') {
    res.end()
    return
  }
  createReadStream(filePath).pipe(res)
}

/**
 * Resolves a request path to a file inside `root`.
 *
 * Hash routing means almost every request is for `/`; anything that is not an
 * existing file falls back to `index.html` so a deep link such as
 * `/?state=...#/dashboard` still boots the app. Paths that escape `root` are
 * rejected outright.
 */
async function resolveRequestPath(root: string, pathname: string): Promise<string | null> {
  const relative = pathname.replace(/^\/+/, '')
  if (!relative) return join(root, 'index.html')

  const candidate = resolve(root, relative)
  if (candidate !== root && !candidate.startsWith(root + sep)) return null

  try {
    const stat = await fs.stat(candidate)
    if (stat.isFile()) return candidate
  } catch {
    // Fall through to the SPA entry point.
  }

  // Only fall back for extension-less paths (route-style URLs). A missing
  // `main.dart.js` should 404 rather than silently return HTML.
  if (extname(relative) === '') return join(root, 'index.html')
  return null
}

function parseRange(
  header: string | undefined,
  size: number
): { start: number; end: number } | null {
  if (!header || !header.startsWith('bytes=')) return null
  const [spec] = header.slice('bytes='.length).split(',')
  const [rawStart, rawEnd] = spec.trim().split('-')
  if (rawStart === '' && rawEnd === '') return null

  let start: number
  let end: number
  if (rawStart === '') {
    // Suffix range: last N bytes.
    const suffixLength = Number(rawEnd)
    if (!Number.isFinite(suffixLength) || suffixLength <= 0) return null
    start = Math.max(0, size - suffixLength)
    end = size - 1
  } else {
    start = Number(rawStart)
    end = rawEnd === '' ? size - 1 : Number(rawEnd)
  }

  if (!Number.isFinite(start) || !Number.isFinite(end)) return null
  if (start > end || start >= size) return null
  return { start, end: Math.min(end, size - 1) }
}
