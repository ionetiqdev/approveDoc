# User View

**File:** `pages/testing/user-view.html`

Shows a user's distribution items grouped by status. The end-user-facing document list.

## Status groups

| Group label | Statuses included |
|---|---|
| Awaiting Action | `PENDING`, `OVERDUE` |
| Acknowledged | `APPROVED` |
| Rejected | `REJECTED` |
| Reference | `REFERENCE` |

## Interaction

- **Double-click** a row → navigates to `acknowledge.html?item={distrib_item_id}`
- **Checklist icon button** → same as double-click

## Column widths

Set on `<colgroup>` directly on the `<table>` element (not in the per-section template string):

| Column | Width |
|---|---|
| Document | 20% |
| Due date | 8% |
| Status | 10% |
| Audience | 20% |
| Date added | 8% |
| Instructions | 32% |
| Buttons | 2% |

!!! warning "colgroup placement"
    `<colgroup>` must be a direct child of `<table>`. Placing it inside a JavaScript template string that generates `<tr>` elements will be ignored by the browser — widths won't apply.

## Section band colours

- Light mode: `#D3D3D3` (hardcoded)
- Dark mode: `var(--tblr-bg-surface-secondary)` (CSS variable)

Set via CSS class selector override:
```css
tr.section-header { background: #D3D3D3; color: #000; }
[data-bs-theme="dark"] tr.section-header { background: var(--tblr-bg-surface-secondary); }
```
