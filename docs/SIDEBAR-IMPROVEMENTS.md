# Sidebar Improvements — Implementation Guide

Covers two features added to `sidebar.js` v2.0 and `theme.css`.
Apply to any ionetiq project using the same sidebar pattern.

---

## Feature 1 — Tooltips in collapsed state

**What it does:** When the sidebar is collapsed, hovering over any nav icon shows
a Bootstrap tooltip on the right with the link's text label.

**Files changed:**
- `assets/js/sidebar.js` — `_initTooltips()`, `_enableTooltips()`, `_disableTooltips()`

**How it works:**
On `Sidebar.init()`, every `.nav-link` that has a `.nav-link-text` child gets
`data-bs-toggle="tooltip"`, `data-bs-placement="right"`, and `data-bs-title`
set to the link text. Tooltips are enabled when the sidebar collapses and
disabled when it expands (so they don't fire in the expanded state).

**No CSS changes needed** — uses Bootstrap's built-in tooltip system.

---

## Feature 2 — Floating submenu panel in collapsed state

**What it does:** When the sidebar is collapsed, clicking or hovering a submenu
icon opens a floating panel to the right of the sidebar showing the submenu
items. The panel disappears when you move away. Clicking a submenu icon in
collapsed state no longer expands the full sidebar.

**Files changed:**
- `assets/js/sidebar.js` — `_createFloatMenu()`, `_showFloat()`, `_hideFloat()`
- `assets/css/theme.css` — `.sidebar-float-menu` and child styles

**CSS to add to `theme.css`:**

```css
/* Floating submenu panel from collapsed sidebar */
.sidebar-float-menu {
  position: fixed;
  left: var(--sidebar-width-collapsed);
  background: var(--bg-sidebar);
  color: var(--sidebar-fg);
  border-radius: .375rem;
  box-shadow: 0 4px 24px rgba(0,0,0,.18);
  min-width: 180px;
  padding: .4rem 0;
  z-index: 1080;
  opacity: 0;
  pointer-events: none;
  transform: translateX(-6px);
  transition: opacity .15s, transform .15s;
}
.sidebar-float-menu.visible {
  opacity: 1;
  pointer-events: auto;
  transform: translateX(0);
}
.sidebar-float-menu .float-menu-title {
  font-size: .7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  padding: .3rem .9rem .2rem;
  opacity: .5;
}
.sidebar-float-menu .nav-link {
  display: flex;
  align-items: center;
  padding: .4rem .9rem;
  color: var(--sidebar-fg);
  text-decoration: none;
  font-size: .85rem;
  white-space: nowrap;
  gap: .5rem;
}
.sidebar-float-menu .nav-link:hover {
  background: rgba(var(--sidebar-fg-rgb), .08);
}
.sidebar-float-menu .nav-link.active {
  color: var(--tblr-primary);
  font-weight: 600;
}
```

**How it works:**
A single `div.sidebar-float-menu` is created on first use and appended to
`document.body`. On hover or click of a collapsed submenu icon, the panel is
populated with the submenu's links (read from the hidden DOM) and positioned
vertically aligned to the hovered icon. A 120ms delay on mouseleave allows
the user to move the cursor into the panel without it disappearing.

---

## Applying to another project

1. Replace `assets/js/sidebar.js` with the v2.0 version
2. Add the `.sidebar-float-menu` CSS block to `assets/css/theme.css`
3. No changes needed to `sidebar-html.js` or any HTML pages
4. Bootstrap must be loaded (it is in all ionetiq projects) for tooltips

