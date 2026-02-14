// Service Worker desactivado - sin caché
self.addEventListener('fetch', e => {
    e.respondWith(fetch(e.request));
});
