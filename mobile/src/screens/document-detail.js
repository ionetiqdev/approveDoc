import { showScreen } from '../router.js';

/* TODO: real PDF rendering (blob URL per ADR section 5, pdf.js reused
   from assets/js the same way the web app embeds it) + full-screen
   zoom mode.

   Action bar behaviour already decided (see ADR section 8):
   - Acknowledge + Reject: equal-width, same row
   - Add to reference: full-width below, disabled until Acknowledge
     is tapped, at which point Acknowledge/Reject grey out
   - Reject opens a bottom sheet (free-text reason, validated on
     submit) rather than a separate screen - writes to
     ad_distribution_item.rejected_reason */
export function mount(app, params = {}) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:4px;margin-bottom:16px;">&larr;</button>
      <h2 style="margin:0 0 8px;">${params.title || 'Document'}</h2>
      <p style="font-size:13px;color:var(--text-secondary);">TODO: PDF viewer + Acknowledge/Reject/Reference actions (see mockup).</p>
    </div>
  `;
  app.querySelector('#back').addEventListener('click', () => showScreen('documents'));
}
