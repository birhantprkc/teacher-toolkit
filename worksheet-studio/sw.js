// 오프라인 사용 — 네트워크 우선, 실패하면 캐시 (온라인이면 항상 최신, 인터넷 없으면 캐시본)
const CACHE = 'worksheet-studio-v1'
const ASSETS = ['./', './index.html', './hero.png', './manifest.webmanifest']

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches
      .open(CACHE)
      .then((c) => c.addAll(ASSETS).catch(() => undefined))
      .then(() => self.skipWaiting()),
  )
})

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (e) => {
  const req = e.request
  if (req.method !== 'GET' || !req.url.startsWith(self.location.origin)) return
  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone()
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => undefined)
        return res
      })
      .catch(() => caches.match(req).then((r) => r || caches.match('./index.html'))),
  )
})
