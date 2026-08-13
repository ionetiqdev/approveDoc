import { ICONS } from './icons.js';

/* Green pill back button with a dark arrow - the approveDoc brand teal as
   the fill, using the same dark-on-teal contrast color the rest of the app
   uses for filled accent elements. Shared so every screen's back button
   looks identical rather than each screen styling its own. */
export function backButtonHtml(id = 'back', extraStyle = '') {
  return `<button id="${id}" style="border:none;background:var(--accent);color:var(--on-accent);width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0;${extraStyle}">${ICONS.arrowLeft}</button>`;
}
