'use strict';

// =============================================================================
// NDU Project — Custom Flutter Service Worker
// =============================================================================
//
// This file is COPIED to the build output root by scripts/stamp_build_version.py
// after `flutter build web` completes. Flutter's default service worker is
// intentionally NOT used because it caches too aggressively and breaks the
// instant-deploy workflow we need for the NDU Project staging site.
//
// CACHE STRATEGY
// --------------
// - Network-first for everything. Falls back to cache only when offline.
// - Cache name is versioned by build stamp (NDU_BUILD_STAMP below), so every
//   new deployment gets a fresh cache namespace.
// - On `activate`, ALL old caches (different version) are deleted, freeing
//   disk space and preventing stale assets from being served.
// - On `install`, `skipWaiting()` makes the new SW take over immediately
//   instead of waiting for all tabs to close.
//
// WHY NOT JUST UNREGISTER (like Flutter's default does)?
// ------------------------------------------------------
// Unregistering on every boot means PWA install / offline support never
// works — the SW is gone before it can cache anything. This versioned
// approach gives us: instant updates + working offline mode + clean cache
// rotation.
// =============================================================================

// NDU_BUILD_STAMP is replaced at build time by scripts/stamp_build_version.py.
// Fallback 'dev-local' for `flutter run` so the SW still installs cleanly.
const _NDU_RAW_STAMP = 'NDU_BUILD_STAMP';
const NDU_BUILD_STAMP =
  (_NDU_RAW_STAMP && _NDU_RAW_STAMP !== 'NDU_BUILD_STAMP')
    ? _NDU_RAW_STAMP
    : 'dev-local';

const CACHE_NAME = 'ndu-flutter-app-v' + NDU_BUILD_STAMP;

// Skip waiting so the new SW activates as soon as it installs.
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

// On activate: delete every cache that doesn't match the current version,
// then claim all open clients so they pick up the new SW immediately.
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[NDU SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
          return Promise.resolve();
        })
      ))
      .then(() => self.clients.claim())
  );
});

// Network-first fetch with cache fallback for offline support.
// Navigation requests (HTML) always go to network so users get the latest
// index.html with the newest build stamp.
self.addEventListener('fetch', (event) => {
  // Only handle GET — let the browser handle POST/PUT/etc directly.
  if (event.request.method !== 'GET') return;

  const isNavigation = event.request.mode === 'navigate';

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Cache successful same-origin responses for offline fallback.
        if (response && response.status === 200 && response.type === 'basic') {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone).catch((e) => {
              // Some responses (opaque, non-cacheable) will reject — ignore.
              console.warn('[NDU SW] Cache put failed for', event.request.url, e);
            });
          });
        }
        return response;
      })
      .catch(() => {
        // Network failed — try cache. For navigations, fall back to cached
        // index.html so the app shell still loads offline.
        if (isNavigation) {
          return caches.match('index.html').then((r) => r || caches.match(event.request));
        }
        return caches.match(event.request);
      })
  );
});

// Allow the page to trigger an immediate update via postMessage.
self.addEventListener('message', (event) => {
  if (event.data === 'ndu-skip-waiting') {
    self.skipWaiting();
  }
});
