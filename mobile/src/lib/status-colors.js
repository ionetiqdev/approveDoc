/* Colors match the desktop app's exact literal hex values (pages/testing/
   user-view.html STATS array) - a fixed, desktop-matching palette, not
   theme-adaptive. Reference uses a grey text override (textColor) rather
   than its own blue, matching desktop's textCol field exactly.

   'awaiting' isn't one of desktop's original five - it's this app's
   grouping of on-time + overdue pending items into one bucket for the
   collapsible documents list (matching desktop's own "Awaiting Action"
   section), so it reuses the on-time green rather than introducing a
   sixth arbitrary color. */
export const STATUS_COLORS = {
  ontime:       { color: '#009432', bg: '#D9F2D0' },
  awaiting:     { color: '#009432', bg: '#D9F2D0' },
  overdue:      { color: '#EA2027', bg: '#FFD9D9' },
  acknowledged: { color: '#8BC34A', bg: '#E3FDE3' },
  rejected:     { color: '#B33771', bg: '#F2CFEE' },
  reference:    { color: '#0070C0', bg: '#DCEAF7', textColor: '#7F7F7F' }
};
