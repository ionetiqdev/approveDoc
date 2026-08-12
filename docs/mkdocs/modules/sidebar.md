# sidebar.js

Handles sidebar toggle, collapse, and mobile overlay behaviour.

## API

```js
Sidebar.init()   // Wire all sidebar toggle behaviour — call once after inject
```

No configuration. Handles:
- Hamburger menu toggle (`#sidebarToggle`)
- Mobile overlay (`#sidebarOverlay`)
- Sidebar collapse/expand state (persisted to `localStorage`)
