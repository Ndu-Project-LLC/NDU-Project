#!/usr/bin/env python3
# =============================================================================
# NDU Project — Lightweight Web Server
# =============================================================================
# Static file server for build/web-lite with:
#   • SPA fallback — unknown non-asset paths serve index.html (go_router
#     deep links work without a real file on disk)
#   • Correct mime types — .wasm → application/wasm (required for
#     streaming WebAssembly compilation), .js → text/javascript
#   • Sensible cache headers — entry points (index.html, bootstrap,
#     main.dart.js) are never cached; hashed assets are immutable
#
# Usage:
#   python3 scripts/serve_lite.py [build_dir] [port] [--strict]
#
# Called by scripts/build_web_lite.sh --serve / --serve-only.
#
# Port handling:
#   Port 8080 is contended — the local LLM gate (llm-server/start-local.sh),
#   scripts/serve_flutter_web_fast.py, and this server have all defaulted to
#   it. Previously a losing server printed "Serving ... at :8080" and THEN
#   crashed with a raw OSError traceback, so the browser showed a different
#   service and it looked like "localhost does not load".
#
#   Now the port is probed first. If it is taken, the holder is named and the
#   next free port is used automatically, with the real URL printed. Pass
#   --strict (or set NDU_STRICT_PORT=1) to fail instead of falling back — CI
#   uses that so a busy port is an error rather than a silent port change.
# =============================================================================

import os
import socket
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
DEFAULT_PORT = 8080
# How many consecutive ports to try before giving up.
PORT_SCAN_LIMIT = 20

EXTRA_TYPES = {
    ".wasm": "application/wasm",
    ".js": "text/javascript",
    ".mjs": "text/javascript",
    ".json": "application/json",
}

NO_CACHE_PATHS = {"/", "/index.html", "/flutter_bootstrap.js", "/main.dart.js"}


class SpaHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        # SPA fallback: unknown non-asset paths get index.html so deep links
        # into the app (go_router) work without a real file on disk.
        clean = self.path.split("?")[0].split("#")[0]
        if clean != "/" and not clean.startswith("/assets/"):
            path = self.translate_path(self.path)
            if not os.path.exists(path) or os.path.isdir(path):
                self.path = "/index.html"
        return super().send_head()

    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        if ext in EXTRA_TYPES:
            return EXTRA_TYPES[ext]
        return super().guess_type(path)

    def end_headers(self):
        # Entry points must never be cached; hashed assets can be forever.
        p = self.path.split("?")[0].split("#")[0]
        if p in NO_CACHE_PATHS:
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        elif p.startswith("/assets/"):
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write("  %s\n" % (fmt % args))
        sys.stdout.flush()


def port_is_free(port, host=HOST):
    """True if we can bind `port` right now."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            probe.bind((host, port))
        except OSError:
            return False
    return True


def port_holder(port):
    """Best-effort "node (pid 123)" description of whoever holds `port`."""
    try:
        result = subprocess.run(
            ["lsof", "-nP", "-iTCP:%d" % port, "-sTCP:LISTEN"],
            capture_output=True, text=True, timeout=4,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    names = []
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            entry = "%s (pid %s)" % (parts[0], parts[1])
            if entry not in names:
                names.append(entry)
    return ", ".join(names)


def resolve_port(requested, strict):
    """Return the port to serve on, or None if none could be found.

    A busy port is only fatal under --strict; otherwise we walk forward to the
    next free port so "serve the preview" always ends with a working URL.
    """
    if port_is_free(requested):
        return requested

    holder = port_holder(requested)
    print("! Port %d is already in use%s." % (requested, " by " + holder if holder else ""))

    if strict:
        print("  --strict is set, so this is an error. Free the port, or pass a different one.")
        return None

    for candidate in range(requested + 1, min(requested + PORT_SCAN_LIMIT, 65535) + 1):
        if port_is_free(candidate):
            print("  Serving on http://localhost:%d instead." % candidate)
            print("  (That is usually the local LLM gate or an old server still running.)")
            return candidate

    print("  No free port found in %d-%d." % (requested + 1, requested + PORT_SCAN_LIMIT))
    return None


def main():
    # Line-buffer stdout so the "which port am I actually on" notice is visible
    # even when output is redirected (nohup, CI logs, `> server.log`) — Python
    # block-buffers a non-tty stdout, which hid the fallback notice.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except (AttributeError, ValueError):
        pass

    flags = [a for a in sys.argv[1:] if a.startswith("-")]
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    strict = "--strict" in flags or os.environ.get("NDU_STRICT_PORT") == "1"

    unknown = [f for f in flags if f != "--strict"]
    if unknown:
        print("Unknown option(s): %s" % ", ".join(unknown), file=sys.stderr)
        print("Usage: python3 scripts/serve_lite.py [build_dir] [port] [--strict]", file=sys.stderr)
        return 2

    root = args[0] if len(args) > 0 else "build/web-lite"
    if not os.path.isdir(root):
        print("Build directory not found: %s" % root, file=sys.stderr)
        print("Run ./scripts/build_web_lite.sh first (or pass the right directory).", file=sys.stderr)
        return 1

    try:
        requested = int(args[1]) if len(args) > 1 else DEFAULT_PORT
    except ValueError:
        print("Port must be a number, got %r." % args[1], file=sys.stderr)
        return 2

    os.chdir(root)

    port = resolve_port(requested, strict)
    if port is None:
        return 1

    print()
    print("Serving %s at http://localhost:%d  (Ctrl+C to stop)" % (root, port))
    print()

    try:
        ThreadingHTTPServer((HOST, port), SpaHandler).serve_forever()
    except OSError as error:
        # Lost a race for the port between the probe above and this bind.
        print("Could not bind port %d: %s" % (port, error), file=sys.stderr)
        holder = port_holder(port)
        if holder:
            print("Port %d is held by %s." % (port, holder), file=sys.stderr)
        print("Re-run, or pass a different port: python3 scripts/serve_lite.py %s <port>"
              % root, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        pass
