#!/usr/bin/env python3
"""
NDU Project — High-performance static file server for the Flutter web build.

Optimizations vs. the basic http.server:
  1. gzip compression for text-based assets (HTML/JS/JSON/CSS/SVG)
     → main.dart.js shrinks from 12 MB to ~3 MB (75% reduction)
  2. HTTP/1.1 keep-alive (default protocol version)
     → eliminates TCP handshake overhead per asset
  3. ThreadingHTTPServer
     → concurrent asset downloads (browser fetches 6+ at once)
  4. Proper MIME types (.wasm = application/wasm)
     → browser compiles WASM efficiently instead of re-fetching
  5. Smart caching:
     - Long-term (1 year) for binary assets with stable content
       (canvaskit.wasm, fonts, icons, MaterialIcons)
     - no-cache for index.html, env-config.js, flutter_bootstrap.js
       (these change between deploys and drive cache-busting)
  6. Range request support
     → browser can resume interrupted downloads of large assets

Usage:
    python3 /home/z/my-project/scripts/serve_flutter_web_fast.py start
    python3 /home/z/my-project/scripts/serve_flutter_web_fast.py stop
    python3 /home/z/my-project/scripts/serve_flutter_web_fast.py status
"""

from __future__ import annotations

import os
import sys
import time
import signal
import gzip
import io
import mimetypes
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

SERVE_DIR = "/home/z/my-project/serve"
PORT = 8080
PID_FILE = "/home/z/my-project/server.pid"
LOG_FILE = "/home/z/my-project/server.log"

# Pre-compress text assets at startup so we don't re-compress per request.
# Threshold: pre-compress anything > 16 KB (smaller files compress on-the-fly).
PRECOMPRESS_THRESHOLD = 16 * 1024
PRECOMPRESSIBLE_EXTS = {".js", ".json", ".css", ".svg", ".html", ".frag"}

# Cache control rules. Key = file extension (with dot), value = max-age in seconds.
# - HTML, env-config, bootstrap: no-cache (they drive cache-busting)
# - JS, WASM, fonts, images: 1 year (immutable, content-addressed or stable)
CACHE_RULES = {
    ".html": "no-cache, no-store, must-revalidate",
    ".js": "public, max-age=31536000, immutable",
    ".wasm": "public, max-age=31536000, immutable",
    ".otf": "public, max-age=31536000, immutable",
    ".ttf": "public, max-age=31536000, immutable",
    ".png": "public, max-age=31536000, immutable",
    ".jpg": "public, max-age=31536000, immutable",
    ".jpeg": "public, max-age=31536000, immutable",
    ".gif": "public, max-age=31536000, immutable",
    ".svg": "public, max-age=31536000, immutable",
    ".ico": "public, max-age=31536000, immutable",
    ".json": "no-cache, must-revalidate",  # version.json, manifest.json change
    ".frag": "public, max-age=31536000, immutable",
}

# In-memory cache of pre-compressed file bytes: {filepath: gzip_bytes}
_precompressed: dict[Path, bytes] = {}


def _precompress_assets() -> None:
    """Walk SERVE_DIR and pre-compress large text assets at startup.
    This avoids re-compressing main.dart.js (12 MB) on every request."""
    serve_path = Path(SERVE_DIR)
    count = 0
    total_saved = 0
    for filepath in serve_path.rglob("*"):
        if not filepath.is_file():
            continue
        if filepath.suffix.lower() not in PRECOMPRESSIBLE_EXTS:
            continue
        try:
            size = filepath.stat().st_size
        except OSError:
            continue
        if size < PRECOMPRESS_THRESHOLD:
            continue
        try:
            raw = filepath.read_bytes()
            compressed = gzip.compress(raw, compresslevel=9)
            if len(compressed) < size:  # only cache if compression helps
                _precompressed[filepath] = compressed
                count += 1
                total_saved += size - len(compressed)
        except (OSError, gzip.BadGzipFile):
            continue
    print(
        f"Pre-compressed {count} file(s), saving {total_saved / 1024 / 1024:.1f} MB per request cycle.",
        file=sys.stderr,
    )


class FastFlutterHandler(SimpleHTTPRequestHandler):
    """HTTP handler with gzip, keep-alive, proper MIME types, and smart caching."""

    # Use HTTP/1.1 for keep-alive support (default is HTTP/1.0 in base class)
    protocol_version = "HTTP/1.1"

    # Suppress default logging (too noisy for 12 MB transfers)
    def log_message(self, format, *args):
        # Only log errors and non-200s, skip routine 200s for assets
        try:
            status = args[1] if len(args) > 1 else ""
            if str(status).startswith(("4", "5")):
                sys.stderr.write(
                    "%s - - [%s] %s\n"
                    % (self.client_address[0], self.log_date_time_string(), format % args)
                )
        except (IndexError, ValueError):
            pass

    def _get_cache_control(self, filepath: Path) -> str:
        """Return Cache-Control header value based on file extension."""
        ext = filepath.suffix.lower()
        # Special case: env-config.js and flutter_bootstrap.js must always be fresh
        name = filepath.name.lower()
        if name in ("env-config.js", "flutter_bootstrap.js", "version.json"):
            return "no-cache, no-store, must-revalidate"
        return CACHE_RULES.get(ext, "no-cache, must-revalidate")

    def _get_content_type(self, filepath: Path) -> str:
        """Return proper Content-Type, with special handling for .wasm and .js."""
        ext = filepath.suffix.lower()
        if ext == ".wasm":
            return "application/wasm"
        if ext == ".js":
            return "text/javascript; charset=utf-8"
        if ext == ".mjs":
            return "text/javascript; charset=utf-8"
        if ext == ".json":
            return "application/json; charset=utf-8"
        if ext == ".html":
            return "text/html; charset=utf-8"
        if ext == ".svg":
            return "image/svg+xml"
        # Fall back to mimetypes for the rest
        ctype, _ = mimetypes.guess_type(str(filepath))
        return ctype or "application/octet-stream"

    def _supports_gzip(self) -> bool:
        """Check if client accepts gzip encoding."""
        encoding = self.headers.get("Accept-Encoding", "")
        return "gzip" in encoding.lower()

    def _serve_precompressed_or_file(self, filepath: Path):
        """Serve a file, using pre-compressed bytes if available and client accepts gzip."""
        try:
            file_size = filepath.stat().st_size
        except OSError:
            self.send_error(404, "Not found")
            return

        content_type = self._get_content_type(filepath)
        cache_control = self._get_cache_control(filepath)

        # Check for pre-compressed version
        use_gzip = self._supports_gzip() and filepath in _precompressed
        if use_gzip:
            body = _precompressed[filepath]
            content_length = len(body)
        else:
            body = None
            content_length = file_size

        # Handle range requests (for resumable downloads of large assets)
        range_header = self.headers.get("Range")
        if range_header and body is None:
            # Parse "bytes=start-end"
            try:
                range_spec = range_header.replace("bytes=", "").split("-")
                start = int(range_spec[0]) if range_spec[0] else 0
                end = int(range_spec[1]) if range_spec[1] else file_size - 1
                end = min(end, file_size - 1)
                content_length = end - start + 1

                self.send_response(206)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(content_length))
                self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                self.send_header("Cache-Control", cache_control)
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()

                with open(filepath, "rb") as f:
                    f.seek(start)
                    remaining = content_length
                    while remaining > 0:
                        chunk = f.read(min(65536, remaining))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
                return
            except (ValueError, IndexError, OSError):
                pass  # Fall through to normal serving

        # On-the-fly gzip for small compressible files not in precompressed cache
        if (
            not use_gzip
            and self._supports_gzip()
            and filepath.suffix.lower() in PRECOMPRESSIBLE_EXTS
            and file_size > 512  # don't bother with tiny files
        ):
            try:
                raw = filepath.read_bytes()
                compressed = gzip.compress(raw, compresslevel=9)
                if len(compressed) < file_size:
                    body = compressed
                    content_length = len(compressed)
                    use_gzip = True
            except (OSError, gzip.BadGzipFile):
                pass  # Fall through to uncompressed serving

        # Normal full-content response
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(content_length))
        self.send_header("Cache-Control", cache_control)
        self.send_header("Accept-Ranges", "bytes")
        if use_gzip:
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
        self.end_headers()

        if body is not None:
            # Send pre-compressed bytes
            self.wfile.write(body)
        else:
            # Stream from disk in 64 KB chunks (don't load 12 MB into memory)
            with open(filepath, "rb") as f:
                while True:
                    chunk = f.read(65536)
                    if not chunk:
                        break
                    self.wfile.write(chunk)

    def do_GET(self):
        """Handle GET requests with path normalization."""
        # Strip query string (cache-busting ?v= params)
        path = self.path.split("?")[0]
        if path == "/":
            path = "/index.html"

        # Prevent directory traversal
        if ".." in path:
            self.send_error(400, "Bad request")
            return

        filepath = Path(SERVE_DIR) / path.lstrip("/")
        if not filepath.exists() or not filepath.is_file():
            self.send_error(404, "Not found")
            return

        self._serve_precompressed_or_file(filepath)

    def do_HEAD(self):
        """Handle HEAD requests (metadata only, no body) — used for caching checks."""
        path = self.path.split("?")[0]
        if path == "/":
            path = "/index.html"
        if ".." in path:
            self.send_error(400, "Bad request")
            return

        filepath = Path(SERVE_DIR) / path.lstrip("/")
        if not filepath.exists() or not filepath.is_file():
            self.send_error(404, "Not found")
            return

        try:
            file_size = filepath.stat().st_size
        except OSError:
            self.send_error(404, "Not found")
            return

        content_type = self._get_content_type(filepath)
        cache_control = self._get_cache_control(filepath)
        use_gzip = self._supports_gzip() and filepath in _precompressed
        content_length = len(_precompressed[filepath]) if use_gzip else file_size

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(content_length))
        self.send_header("Cache-Control", cache_control)
        self.send_header("Accept-Ranges", "bytes")
        if use_gzip:
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
        self.end_headers()


def _daemonize() -> None:
    """Classic double-fork daemonization."""
    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError as e:
        sys.stderr.write(f"First fork failed: {e}\n")
        sys.exit(1)

    os.setsid()
    os.umask(0)

    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError as e:
        sys.stderr.write(f"Second fork failed: {e}\n")
        sys.exit(1)

    sys.stdout.flush()
    sys.stderr.flush()
    with open(os.devnull, "rb") as devnull_in:
        os.dup2(devnull_in.fileno(), 0)
    with open(LOG_FILE, "ab") as log_out:
        os.dup2(log_out.fileno(), 1)
        os.dup2(log_out.fileno(), 2)


def _write_pid(pid: int) -> None:
    Path(PID_FILE).write_text(str(pid), encoding="utf-8")


def _read_pid() -> int | None:
    try:
        return int(Path(PID_FILE).read_text(encoding="utf-8").strip())
    except (FileNotFoundError, ValueError):
        return None


def _is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def start() -> int:
    existing = _read_pid()
    if existing and _is_running(existing):
        print(f"Server already running (PID {existing}) on port {PORT}.")
        return 0

    try:
        Path(PID_FILE).unlink()
    except FileNotFoundError:
        pass

    print(f"Starting optimized Flutter web server on port {PORT}...")
    print("  - gzip compression: ENABLED")
    print("  - HTTP/1.1 keep-alive: ENABLED")
    print("  - Threading: ENABLED")
    print("  - Pre-compressing large assets...")
    _daemonize()

    # Pre-compress large text assets before serving starts
    _precompress_assets()
    print(f"  - Serving from: {SERVE_DIR}", file=sys.stderr)
    print(f"  - Ready on http://0.0.0.0:{PORT}/", file=sys.stderr)

    # ThreadingHTTPServer handles concurrent requests in separate threads
    ThreadingHTTPServer.allow_reuse_address = True
    ThreadingHTTPServer.daemon_threads = True  # threads don't block shutdown

    _write_pid(os.getpid())
    with ThreadingHTTPServer(("0.0.0.0", PORT), FastFlutterHandler) as httpd:
        httpd.serve_forever()
    return 0


def stop() -> int:
    pid = _read_pid()
    if not pid:
        print("No PID file — server not running (or stale state).")
        return 0
    if not _is_running(pid):
        print(f"PID {pid} not running — cleaning stale PID file.")
        Path(PID_FILE).unlink(missing_ok=True)
        return 0
    try:
        os.kill(pid, signal.SIGTERM)
        time.sleep(1)
        if _is_running(pid):
            os.kill(pid, signal.SIGKILL)
        print(f"Server (PID {pid}) stopped.")
    except OSError as e:
        print(f"Error stopping PID {pid}: {e}")
    finally:
        Path(PID_FILE).unlink(missing_ok=True)
    return 0


def status() -> int:
    pid = _read_pid()
    if not pid:
        print("Server: NOT running (no PID file).")
        return 1
    if not _is_running(pid):
        print(f"Server: NOT running (stale PID file for {pid}).")
        return 1
    import urllib.request
    try:
        with urllib.request.urlopen(f"http://localhost:{PORT}/", timeout=2) as r:
            code = r.status
        print(f"Server: RUNNING (PID {pid}) — HTTP {code} on port {PORT}.")
        return 0
    except Exception as e:
        print(f"Server: PID {pid} alive but not responding on port {PORT} ({e}).")
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in {"start", "stop", "status", "restart"}:
        print("Usage: serve_flutter_web_fast.py {start|stop|status|restart}")
        sys.exit(2)

    cmd = sys.argv[1]
    if cmd == "start":
        sys.exit(start())
    elif cmd == "stop":
        sys.exit(stop())
    elif cmd == "status":
        sys.exit(status())
    elif cmd == "restart":
        stop()
        time.sleep(1)
        sys.exit(start())
