const CACHE_NAME = 'examenes-app-v7';
const ASSETS = [
    '/',
    '/index.html',
    '/firebase-config.js',
    '/manifest.json'
];

self.addEventListener('install', e => {
    self.skipWaiting();
    e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(ASSETS)));
});

self.addEventListener('activate', e => {
    e.waitUntil(
        caches.keys().then(keys =>
            Promise.all(keys.map(k => caches.delete(k)))
        ).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', e => {
    if (e.request.url.includes('app.html')) {
        e.respondWith(fetch(e.request));
        return;
    }
    e.respondWith(
        fetch(e.request).catch(() => caches.match(e.request))
    );
});
