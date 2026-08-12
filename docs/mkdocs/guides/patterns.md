# Patterns & Conventions

Common patterns used throughout the approveDoc codebase.

## Module-level vs scoped variables

Variables accessed by both async init code and top-level functions must be at **module scope** (top-level `let`), not inside async IIFEs.

```js
// ✅ CORRECT — accessible from saveDistribution()
let _distSaved = false;

(async () => {
  // init code
})();

async function saveDistribution() {
  _distSaved = true;  // works — module scope
}
```

```js
// ❌ WRONG — saveDistribution() cannot access _distSaved
(async () => {
  let _distSaved = false;
})();

async function saveDistribution() {
  _distSaved = true;  // silently creates a new global variable
}
```

## Dirty guard pattern

```js
let _saved    = false;  // module-level
let _snapshot = null;
let _guarded  = false;

modalEl.addEventListener('shown.bs.modal', () => {
  _saved    = false;
  _snapshot = takeSnapshot();
  if (!_guarded) {
    _guarded = true;
    App.guardModalClose(modalEl, bsModal,
      () => !_saved && takeSnapshot() !== _snapshot
    );
  }
});

modalEl.addEventListener('hidden.bs.modal', () => {
  _snapshot = null;
  _saved    = false;
  resetModal();
});

async function save() {
  // ... validate, save to DB ...
  _saved = true;   // ← before hide()
  bsModal.hide();
  App.toast('Saved');
}
```

## Type-ahead picker

Pattern for searchable select fields (audiences, manager picker, etc.):

- Text input for display
- Hidden `<input type="hidden">` for the UUID value
- Show full list on `focus`; filter on `input`
- Use `mousedown` on dropdown items (not `click`) — prevents `blur` closing the dropdown before the selection registers
- 150ms delay on `blur` to allow `mousedown` to fire

```js
input.addEventListener('focus', () => showDropdown(input.value.trim()));
input.addEventListener('blur',  () => setTimeout(() => { dropdown.style.display = 'none'; }, 150));

dropdown.querySelectorAll('.dropdown-item').forEach(btn => {
  btn.addEventListener('mousedown', e => {   // mousedown fires before blur
    e.preventDefault();
    hidden.value = btn.dataset.id;
    input.value  = btn.textContent;
    dropdown.style.display = 'none';
  });
});
```

## Supabase query pattern

Always filter by `Auth.getOrganisationId()`:

```js
const { data, error } = await sb
  .from('ad_foo')
  .select('*')
  .eq('organisation_id', Auth.getOrganisationId())
  .order('name');

if (error) {
  App.toast('Load failed: ' + error.message, 'danger');
  return;
}
```

## Role-gated elements

```html
<!-- Only visible to admin and super_admin -->
<li class="role-hidden" data-require-role="admin">...</li>
```

`role-hidden` is in `theme.css` as `display: none !important`.  
`Auth.refreshUI()` removes the class from matching elements.

!!! danger "d-none vs role-hidden"
    Use `d-none` for feature-controlled visibility (upload button, drop zone).  
    Use `role-hidden` for role-gated elements.  
    **Never mix them on the same element.**

## Escaping HTML

Always escape user-supplied data before inserting into HTML strings:

```js
`<td>${App.escHtml(item.name)}</td>`
```

Never use string interpolation with raw user data.

## Date handling

- Store: ISO strings (`YYYY-MM-DD` for dates, timestamptz for datetimes)
- Display: `App.formatDate(iso)` → `'29 Jul 2026'`
- Due date from days: `start + N calendar days` (simple elapsed time)

## Windows batch scripting

In `cmd.exe`, leading-zero numbers in date/time values are treated as octal in arithmetic expressions. Never use `%date%` or `%time%` directly in arithmetic. Use `for /f` with `tokens` to extract date parts safely.
