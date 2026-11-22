#!/usr/bin/env python3
"""Harden the exported Godot web build against stale PWA caches.

Godot's generated service worker caches index.html and index.pck. A player
who already has the old worker can keep seeing an older build even after a
redeploy. This patch makes a new worker activate immediately, drop the old
cache and reload the clients that were using it. It also adds a small page
hook that activates a waiting worker on future builds.

Run automatically by scripts/export-web.sh after the Godot export.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SW = ROOT / "build" / "web" / "index.service.worker.js"
HTML = ROOT / "build" / "web" / "index.html"

INSTALL_OLD = "self.addEventListener('install', (event) => {\n"
INSTALL_NEW = (
    "self.addEventListener('install', (event) => {\n"
    "\tself.skipWaiting(); // CCF immediate update\n"
)

ACTIVATE_OLD = """self.addEventListener('activate', (event) => {
\tevent.waitUntil(caches.keys().then(
\t\tfunction (keys) {
\t\t\t// Remove old caches.
\t\t\treturn Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));
\t\t}
\t).then(function () {
\t\t// Enable navigation preload if available.
\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
\t}));
});"""

ACTIVATE_NEW = """self.addEventListener('activate', (event) => {
\tevent.waitUntil(caches.keys().then(function (keys) {
\t\tconst stale = keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME);
\t\treturn Promise.all(stale.map((key) => caches.delete(key))).then(function () {
\t\t\treturn self.clients.claim();
\t\t}).then(function () {
\t\t\tif (stale.length === 0) return;
\t\t\treturn self.clients.matchAll().then(function (all) {
\t\t\t\tall.forEach(function (c) { c.navigate(c.url).catch(function () {}); });
\t\t\t});
\t\t});
\t}).then(function () {
\t\t// Enable navigation preload if available.
\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
\t}));
});"""

HTML_HOOK = """<!-- CCF_PWA_UPDATE -->
<script>
(function () {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.getRegistration().then(function (reg) {
    if (!reg) return;
    function arm(worker) {
      if (!worker || worker.state === 'redundant') return;
      if (worker.state === 'installed' && navigator.serviceWorker.controller) {
        worker.postMessage('update');
        return;
      }
      if (!worker.__ccfArmed) {
        worker.__ccfArmed = true;
        worker.addEventListener('statechange', function () { arm(worker); });
      }
    }
    if (reg.waiting) arm(reg.waiting);
    reg.addEventListener('updatefound', function () { arm(reg.installing); });
    reg.update();
  });
})();
</script>
"""


def main() -> None:
    if SW.exists():
        sw = SW.read_text(encoding="utf-8")
        if "CCF immediate update" not in sw and INSTALL_OLD in sw:
            sw = sw.replace(INSTALL_OLD, INSTALL_NEW, 1)
            if ACTIVATE_OLD in sw:
                sw = sw.replace(ACTIVATE_OLD, ACTIVATE_NEW, 1)
        # The patched worker must not reuse the cache name of the unpatched
        # build that may already be live, or it will not see any stale cache
        # to remove (and could keep serving the old index.pck).
        sw = re.sub(
            r"const CACHE_VERSION = '([^']*)';",
            lambda m: m.group(0) if "|ccf" in m.group(1)
            else "const CACHE_VERSION = '%s|ccf';" % m.group(1),
            sw,
            count=1,
        )
        SW.write_text(sw, encoding="utf-8")

    if HTML.exists():
        html = HTML.read_text(encoding="utf-8")
        if "CCF_PWA_UPDATE" not in html:
            html = html.replace("</body>", HTML_HOOK + "</body>", 1)
            HTML.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
