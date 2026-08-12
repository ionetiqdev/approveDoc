# app.js

General-purpose utilities shared across all pages.

## App.toast()

```js
App.toast(message, type = 'success', duration = 3500)
```

Shows a Bootstrap toast notification in the bottom-right corner.

| Parameter | Values |
|---|---|
| `type` | `'success'`, `'danger'`, `'warning'`, `'info'` |
| `duration` | Milliseconds before auto-dismiss |

```js
App.toast('Distribution created');
App.toast('Save failed: ' + err.message, 'danger');
App.toast('Please fill in all required fields', 'warning', 5000);
```

## App.confirm()

```js
const ok = await App.confirm(options)
```

Shows a confirmation modal. Returns `Promise<boolean>`.

```js
const ok = await App.confirm({
  title: 'Delete distribution?',
  message: 'This cannot be undone.',
  confirmText: 'Delete',
  confirmClass: 'btn-danger'
});
if (ok) { /* proceed */ }
```

## App.formatDate() / App.formatDateTime()

```js
App.formatDate('2026-07-29')           // → '29 Jul 2026'
App.formatDateTime('2026-07-29T14:30') // → '29 Jul 2026, 14:30'
```

UK locale (en-GB). Returns `'-'` for null/undefined input.

## App.escHtml()

```js
App.escHtml('<script>alert("xss")</script>')
// → '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'
```

Escapes `&`, `<`, `>`, `"` for safe HTML insertion. Always use this when inserting user-supplied data into HTML strings.

## App.showLoader() / App.hideLoader()

Full-page loading overlay. Use sparingly — prefer inline spinners for local loading states.

## App.guardModalClose()

```js
App.guardModalClose(modalEl, bsModalInstance, isDirtyFn)
```

Wires a dirty-guard onto a Bootstrap modal. When the user tries to close (X button, backdrop, Escape, or programmatic `.hide()`), calls `isDirtyFn()`. If it returns `true`, shows "Discard changes?" confirmation before allowing close.

### Usage pattern

```js
let _saved    = false;  // (1) — module-level, not inside IIFE
let _snapshot = null;
let _guarded  = false;

modalEl.addEventListener('shown.bs.modal', () => {
  _saved    = false;
  _snapshot = takeSnapshot();
  if (!_guarded) {
    _guarded = true;
    App.guardModalClose(modalEl, bsModal,
      () => !_saved && takeSnapshot() !== _snapshot  // (2)
    );
  }
});

modalEl.addEventListener('hidden.bs.modal', () => {
  _snapshot = null;
  _saved    = false;
  resetModal();
});

async function save() {
  // ... validate and save to DB ...
  _saved = true;   // (3) — set BEFORE calling hide()
  bsModal.hide();
}
```

1. `_saved` must be at module scope — not inside the async IIFE — so `save()` can access it
2. Check `!_saved` first; if true, skip snapshot comparison entirely
3. Set `_saved = true` before `hide()` so the guard sees it during the `hide.bs.modal` event
