# status-widget.js

Renders a compliance status summary in the page header showing pending/overdue document counts for the current user.

## API

```js
StatusWidget.init()      // Initialise — call once in page init
StatusWidget.refresh()   // Refresh counts — call after any status change
```

## Usage

```js
(async () => {
  const session = await Auth.requireAuth();
  if (!session) return;
  SidebarHtml.inject(window._appRootUrl || '../../');
  Sidebar.init();
  Auth.refreshUI();
  StatusWidget.init();  // ← call here
})();

// After acknowledging a document:
await StatusWidget.refresh();
```

## What it displays

Queries `ad_distribution_item` for the current user and shows counts grouped by status. Displayed in the header navbar area.
