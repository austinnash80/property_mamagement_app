// Nash Family service worker. Only job: show push notifications and open the
// right page when one is tapped. No caching, no offline — keep it that small.

self.addEventListener("install", function () { self.skipWaiting(); });
self.addEventListener("activate", function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener("push", function (event) {
  var data = {};
  try { data = event.data ? event.data.json() : {}; } catch (err) { data = { body: event.data && event.data.text() }; }
  var title = data.title || "Nash Family";
  var options = {
    body: data.body || "",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    tag: data.tag || undefined,       // same tag => replaces rather than stacks
    renotify: !!data.tag,
    data: { url: data.url || "/family" }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  var url = (event.notification.data && event.notification.data.url) || "/family";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (list) {
      // Reuse an open tab/window of the app if there is one.
      for (var i = 0; i < list.length; i++) {
        var c = list[i];
        if ("focus" in c && new URL(c.url).origin === self.location.origin) {
          return c.navigate ? c.navigate(url).then(function (w) { return w && w.focus(); }) : c.focus();
        }
      }
      return self.clients.openWindow(url);
    })
  );
});
