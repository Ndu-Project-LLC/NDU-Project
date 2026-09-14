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
#   python3 scripts/serve_lite.py [build_dir] [port]
#
# Called by scripts/build_web_lite.sh --serve / --serve-only.
# =============================================================================

import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

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


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "build/web-lite"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    os.chdir(root)
    print("Serving %s at http://localhost:%d  (Ctrl+C to stop)" % (root, port))
    print()
    ThreadingHTTPServer(("127.0.0.1", port), SpaHandler).serve_forever()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
