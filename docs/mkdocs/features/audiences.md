# Audiences

**File:** `pages/audiences_combined/index.html`

An audience is a named group of users that can be targeted by a distribution.

## Audience types

| Type | Description |
|---|---|
| `FIXED` | Explicit membership — users are added individually |
| `CRITERIA` | Rule-based — users matched by department, location, job role, country, etc. |

## Key behaviour

- **Type-ahead criteria search** — selected items appear first (alphabetically), then unselected. UK (`GBR`) is pinned to the top of its group.
- **Type change warning** — changing from `FIXED` to `CRITERIA` or vice versa shows `App.confirm()` with an advisory note. On confirm, existing members/criteria are deleted and new ones are saved.
- `saveAudience()` detects type changes, confirms, deletes old data, inserts new data.
