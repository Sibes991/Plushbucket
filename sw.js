// Offline support. Version changes whenever the app changes, so old caches are cleared.
const V="susp-88c7977586",CORE=["/","/index.html","/manifest.webmanifest","/icons/icon-192.png","/icons/icon-512.png","/icons/maskable-512.png","/icons/apple-touch-icon.png","/icons/favicon-32.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{const r=e.request,u=new URL(r.url);if(r.method!=="GET")return;
 // the page: network first so updates show up, cached copy when offline
 if(r.mode==="navigate"){e.respondWith(fetch(r).then(res=>{const cp=res.clone();caches.open(V).then(c=>c.put("/index.html",cp));return res}).catch(()=>caches.match("/index.html")));return}
 // fonts: cache first, saved the first time the app is opened online
 if(u.hostname==="fonts.googleapis.com"||u.hostname==="fonts.gstatic.com"){e.respondWith(caches.match(r).then(m=>m||fetch(r).then(res=>{const cp=res.clone();caches.open(V).then(c=>c.put(r,cp));return res})));return}
 // same-site files (icons, manifest): cache first
 if(u.origin===location.origin)e.respondWith(caches.match(r).then(m=>m||fetch(r)));
});
