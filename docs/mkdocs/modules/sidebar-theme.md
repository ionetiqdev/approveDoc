# sidebar.js / theme.js

## sidebar.js

Handles sidebar toggle, collapse, and mobile overlay behaviour.

Initialise with:
```js
Sidebar.init()
```

No configuration needed. Handles:
- Hamburger menu toggle (`#sidebarToggle` button)
- Overlay click to close on mobile
- Active link highlighting based on current URL

## theme.js

Handles the dark/light mode toggle and accent colour application.

The toggle button uses `[data-theme-toggle]` attribute. Theme is stored in `localStorage` under `'app_theme'` (unscoped — theme is shared across environments on the same origin).

Accent colour and sidebar colour are scoped per environment — see [localStorage Isolation](../architecture/localstorage.md).
