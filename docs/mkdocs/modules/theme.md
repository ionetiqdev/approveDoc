# theme.js

Handles dark/light mode toggle.

Reads/writes `'app_theme'` in localStorage — this key is **not scoped** (theme is shared across environments for the same browser).

The toggle button must have `data-theme-toggle` attribute.
