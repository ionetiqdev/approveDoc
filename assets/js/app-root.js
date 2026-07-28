/* app-root.js — must be the FIRST script loaded, before any other assets.
   Computes the absolute URL to the app root and sets it on <html data-app-root>.
   This makes all relative paths work regardless of where the app is hosted.

   Logic: pages are either:
     - the root index.html  (data-app-root="./")
     - pages/{section}/{file}.html  (data-app-root="../../")

   We resolve the existing relative data-app-root against the current URL
   to get a stable absolute base URL, then rewrite it. All other modules
   read window._appRootUrl or use the resolved absolute path.
*/
(function() {
  try {
    const rel = document.documentElement.getAttribute('data-app-root') || './';
    const abs = new URL(rel, window.location.href).href;
    // Ensure trailing slash
    const base = abs.endsWith('/') ? abs : abs + '/';
    document.documentElement.setAttribute('data-app-root', base);
    window._appRootUrl = base;
  } catch(e) {}
})();
