import { showScreen } from '../router.js';

/* Intentional placeholder - see ADR section 2a. When built, this scopes
   to "this admin and everyone under them" via ad_user.manager_id,
   reusing the org chart's existing recursive tree rather than new
   scoping logic. Aggregate metrics only - never per-user activity. */
export function mount(app) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;text-align:center;">
      <h2 style="margin:0 0 8px;">Metrics coming soon</h2>
      <p style="font-size:13px;color:var(--text-secondary);line-height:1.5;">
        Organisation-wide compliance metrics will appear here — aggregate completion rates, overdue counts, and trends over time.
      </p>
      <button id="back" style="margin-top:24px;border:none;background:none;color:var(--accent);font-size:13px;">Back to dashboard</button>
    </div>
  `;
  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
}
