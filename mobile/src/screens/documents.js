import { showScreen } from '../router.js';

/* TODO: real query against ad_distribution_item joined to ad_document,
   with the Pending/All filter and overdue red-left-accent treatment
   from the mockup. See dashboard.js for the query pattern to extend. */
export function mount(app) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:4px;margin-bottom:16px;">&larr;</button>
      <h2 style="margin:0 0 8px;">Documents</h2>
      <p style="font-size:13px;color:var(--text-secondary);">TODO: Pending/All filter + document list (see mockup).</p>
    </div>
  `;
  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
}
