const EYE_OPEN = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>`;
const EYE_OFF = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a18.5 18.5 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>`;

/* Renders a password input with an eye-toggle button positioned inside it.
   Call wirePasswordEye(app, id) after the markup is in the DOM to wire it up. */
export function passwordFieldHtml(id, placeholder, autocomplete) {
  return `
    <div style="position:relative;">
      <input id="${id}" type="password" autocomplete="${autocomplete}" placeholder="${placeholder}"
        style="width:100%;padding:10px;padding-right:36px;border:1px solid var(--border);border-radius:8px;background:var(--bg-0);color:var(--text-primary);" />
      <button type="button" id="${id}-eye" aria-label="Show password"
        style="position:absolute;right:6px;top:50%;transform:translateY(-50%);border:none;background:none;padding:4px;cursor:pointer;color:var(--text-secondary);display:flex;">${EYE_OPEN}</button>
    </div>
  `;
}

export function wirePasswordEye(app, id) {
  const input = app.querySelector('#' + id);
  const btn = app.querySelector('#' + id + '-eye');
  btn.addEventListener('click', () => {
    if (input.type === 'password') {
      input.type = 'text';
      btn.innerHTML = EYE_OFF;
      btn.setAttribute('aria-label', 'Hide password');
    } else {
      input.type = 'password';
      btn.innerHTML = EYE_OPEN;
      btn.setAttribute('aria-label', 'Show password');
    }
  });
}
