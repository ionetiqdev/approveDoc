# Org Chart

**File:** `pages/testing/org-chart.html`

Recursive, unlimited-depth organisation hierarchy visualisation with drag-and-drop management.

## Data model

| Field | Purpose |
|---|---|
| `ad_user.manager_id` | Self-referencing FK — one manager per user |
| `ad_user.is_top_level` | Boolean — marks intentional hierarchy roots |

### Distinction between unassigned and top-level

| `manager_id` | `is_top_level` | Meaning |
|---|---|---|
| `null` | `false` | Not yet assigned — appears in right panel |
| `null` | `true` | Intentional top of hierarchy — appears as root in tree |
| UUID | `false` | Regular user with a manager |

## Layout

50/50 split:
- **Left** — recursive tree (unlimited depth)
- **Right** — "Not Yet Assigned" panel

## Connector lines

Lines are drawn using CSS `::before` and `::after` pseudo-elements on `.org-children > .org-node`:

| Pseudo-element | Purpose |
|---|---|
| `::before` | Vertical line — full height on non-last children, truncated to avatar centre on last child (└ corner) |
| `::after` | Horizontal tick — 15px wide, aligned to avatar centre (18px from top of node) |

**Alignment calculation:**
```
avatar centre = row top padding (5px) + half avatar height (13px) = 18px from top
```

## Drag and drop

Drag any user row and drop onto another user to set `manager_id`. The dragged user is updated immediately and the tree re-renders.

**Circular reference prevention:** `isDescendant(ancestorId, potentialDescendantId)` is checked before saving. If the drop target is a descendant of the dragged user, the drop is rejected with a toast.

## Editing

Click any row (or the pencil icon) to open the edit modal:
- Display name, job title, role
- Manager picker (type-ahead)
- "Top-level manager" toggle — when checked, clears and hides the manager field
