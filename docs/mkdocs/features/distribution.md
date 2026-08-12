# Distribution

**File:** `pages/distribution/index.html`

Creates and manages document distributions — the mechanism by which documents reach users for acknowledgement.

## What a distribution is

A distribution links:
- A **document** to be acknowledged
- One or more **audiences** (groups of users)
- A **start date** and **due date** (or number of days)
- Optional **warning notifications** (first and second)
- **Instructions** shown to users when acknowledging

When saved, `build_distribution_items` (a Supabase function) generates one `ad_distribution_item` row per user per distribution.

## Create Distribution modal

The modal is 70vw wide, split 50/50:

=== "Left half"
    - Name *(required)*
    - Document *(required)*
    - Distribution type *(required)*
    - Start date *(required)*
    - Radio: **Due date** or **Days to acknowledge** + corresponding field *(required)*
    - Instructions (optional)

=== "Right half (tabbed)"
    **Audiences tab**

    - Unlimited audience rows
    - Type-ahead search — shows full list on focus, filters on input
    - Already-selected audiences are excluded from other rows' dropdowns
    - "Add audience" button appends a new row

    **Warnings tab**

    - First warning: Days + Before/After toggle *(required)*
    - Second warning: Days + Before/After toggle *(optional)*
    - Both warnings on one row, each `col-3`

## Validation

All of the following are required on Save:

- Name
- Document
- Distribution type
- Start date
- Due date **or** Days to acknowledge (depending on radio selection)
- At least one audience
- First warning — days and direction

Errors are shown as a single bulleted list: *"Please complete the following required fields: ..."*

## Due date computation

If "Days to acknowledge" mode: `due_date = start_date + N calendar days` (simple elapsed time).

!!! note "Working days"
    A working-days option is planned but not yet implemented.

## Dirty guard

A snapshot is taken when the modal opens. The guard uses a `_distSaved` boolean flag (module-level) rather than snapshot comparison alone:

```js
let _distSaved = false;  // Module-level — accessible from saveDistribution()

// Guard isDirty function:
() => !_distSaved && takeSnapshot() !== _snapshot
```

`_distSaved` is set to `true` immediately before `modal.hide()` after a successful save, bypassing the guard. It resets to `false` on `shown.bs.modal`.

!!! warning "Scope matters"
    `_distSaved` must be at module scope (top-level `let`), not inside the async IIFE. If declared inside the IIFE, `saveDistribution()` (a top-level function) cannot access it.

## build_distribution_items

A Supabase SQL function called after save. Uses `DISTINCT ON` + `ON CONFLICT DO NOTHING` so users who belong to multiple selected audiences get exactly one distribution item.
