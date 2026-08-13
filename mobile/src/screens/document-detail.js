import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

const PDF_BUCKET = 'documents';
const SIGNED_URL_EXPIRY = 60;
const PDF_VIEWER_URL = '/pdfjs/web/viewer.html';

export async function mount(app, params = {}) {
  const backTarget = params.from || 'documents';

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:8px;font-size:22px;color:var(--text-primary);line-height:1;margin-bottom:8px;">&larr;</button>
      <p style="font-size:13px;color:var(--text-secondary);">Loading...</p>
    </div>
  `;
  app.querySelector('#back').addEventListener('click', () => showScreen(backTarget));

  const { data: { user } } = await sb.auth.getUser();

  const { data: item, error: itemError } = await sb
    .from('ad_distribution_item')
    .select('distrib_item_id, distribution_id, due_date, acknowledged, rejected')
    .eq('distrib_item_id', params.itemId)
    .single();

  if (itemError || !item) {
    renderError(app, backTarget, itemError?.message || 'Document not found.');
    return;
  }

  const { data: dist } = await sb
    .from('ad_distribution')
    .select('name, doc_id, instructions')
    .eq('distribution_id', item.distribution_id)
    .single();

  const { data: userRow } = await sb
    .from('ad_user')
    .select('organisation_id')
    .eq('user_id', user.id)
    .single();

  const ctx = {
    title: dist?.name || 'Document',
    instructions: dist?.instructions,
    item,
    backTarget,
    orgId: userRow?.organisation_id,
    docId: dist?.doc_id || null,
    alreadyReferenced: false
  };

  if (!dist?.doc_id) {
    renderStaticShell(app, ctx);
    app.querySelector('#pdf-status').textContent = 'No document attached to this distribution.';
    return;
  }

  const { data: doc } = await sb
    .from('ad_document')
    .select('name, doc_id')
    .eq('doc_id', dist.doc_id)
    .single();

  const { data: refRow } = await sb
    .from('ad_document_reference')
    .select('ad_docref_id')
    .eq('user_id', user.id)
    .eq('doc_id', dist.doc_id)
    .maybeSingle();

  ctx.title = doc?.name || dist.name;
  ctx.alreadyReferenced = !!refRow;

  renderStaticShell(app, ctx);

  const { data: files } = await sb
    .from('ad_document_file')
    .select('id, storage_path, source_type, external_url, external_ref, file_name, download_file_name')
    .eq('doc_id', dist.doc_id)
    .order('created_at', { ascending: false })
    .limit(1);

  const pdfFile = files?.[0];
  if (!pdfFile) {
    app.querySelector('#pdf-status').textContent = 'No file found for this document.';
    return;
  }

  await loadPdf(app, pdfFile, ctx.title);
}

function renderError(app, backTarget, message) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:8px;font-size:22px;color:var(--text-primary);line-height:1;margin-bottom:16px;">&larr;</button>
      <p style="font-size:13px;color:var(--danger);">${message}</p>
    </div>
  `;
  app.querySelector('#back').addEventListener('click', () => showScreen(backTarget));
}

/* Builds the parts of the screen that should NEVER be touched again after
   the PDF loads - header, PDF container, and the reject bottom sheet shell.
   Only #action-area gets re-rendered when acknowledge/reject/reference
   state changes, so the loaded PDF iframe is never destroyed. */
function renderStaticShell(app, ctx) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;position:relative;">
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
        <button id="back" style="border:none;background:none;padding:8px;font-size:22px;color:var(--text-primary);line-height:1;">&larr;</button>
        <h2 style="margin:0;font-size:16px;flex:1;">${ctx.title}</h2>
      </div>

      ${ctx.instructions ? `<p style="font-size:13px;color:var(--text-secondary);margin:0 0 8px 32px;">${ctx.instructions}</p>` : ''}

      <div style="flex:1;min-height:280px;background:var(--bg-1);border-radius:14px;margin-bottom:12px;display:flex;align-items:center;justify-content:center;position:relative;overflow:hidden;">
        <p id="pdf-status" style="font-size:13px;color:var(--text-secondary);">Loading document...</p>
        <iframe id="pdf-frame" style="display:none;position:absolute;inset:0;width:100%;height:100%;border:none;"></iframe>
      </div>

      <div id="action-area"></div>

      <div id="reject-overlay" style="display:none;position:absolute;inset:0;background:rgba(0,0,0,0.45);align-items:flex-end;">
        <div style="background:var(--bg-0);width:100%;border-radius:20px 20px 0 0;padding:18px 16px 20px;">
          <h3 style="margin:0 0 4px;font-size:16px;">Reason for rejection</h3>
          <p style="font-size:12px;color:var(--text-secondary);margin:0 0 12px;">Required — shared with the document admin.</p>
          <textarea id="reject-reason" rows="3" placeholder="e.g. Section 4 conflicts with our site procedure"
            style="width:100%;resize:none;font-size:13px;padding:8px;margin-bottom:8px;border:1px solid var(--border);border-radius:8px;background:var(--bg-0);color:var(--text-primary);"></textarea>
          <div id="reject-error" style="display:none;font-size:12px;color:var(--danger);margin-bottom:8px;">Enter a reason before submitting.</div>
          <div style="display:flex;gap:8px;">
            <button id="reject-cancel" style="flex:1;padding:10px;font-size:13px;border-radius:8px;border:1px solid var(--border);background:transparent;color:var(--text-primary);">Cancel</button>
            <button id="reject-submit" style="flex:1;padding:10px;font-size:13px;border:none;border-radius:8px;background:var(--danger);color:var(--on-danger);">Submit rejection</button>
          </div>
        </div>
      </div>
    </div>
  `;

  app.querySelector('#back').addEventListener('click', () => showScreen(ctx.backTarget));

  app.querySelector('#reject-cancel').addEventListener('click', () => {
    app.querySelector('#reject-overlay').style.display = 'none';
    app.querySelector('#reject-error').style.display = 'none';
  });

  renderActionArea(app, ctx);
}

function renderActionArea(app, ctx) {
  const { item, alreadyReferenced } = ctx;
  const today = new Date().toISOString().slice(0, 10);
  const overdue = !item.acknowledged && !item.rejected && item.due_date && item.due_date < today;
  const pending = !item.acknowledged && !item.rejected;
  // Reference only makes sense once acknowledged (matches desktop's
  // "greyed out until acknowledged" rule) and not already done - once
  // it's rejected, or acknowledged AND referenced, there's genuinely
  // nothing left to action, so we show no buttons at all rather than
  // disabled ones that don't do anything, freeing the space for the
  // PDF viewer instead.
  const showReferenceBtn = item.acknowledged && !alreadyReferenced;

  const area = app.querySelector('#action-area');
  area.innerHTML = `
    ${overdue ? `<p style="font-size:12px;color:var(--danger);margin:0 0 8px;">Overdue</p>` :
      item.due_date ? `<p style="font-size:12px;color:var(--text-secondary);margin:0 0 8px;">Due ${item.due_date}</p>` : ''}
    ${item.acknowledged ? `<p style="font-size:12px;color:var(--success);margin:0 0 8px;">Acknowledged${alreadyReferenced ? ' · Added to reference' : ''}</p>` : ''}
    ${item.rejected ? `<p style="font-size:12px;color:var(--danger);margin:0 0 8px;">Rejected</p>` : ''}

    ${pending ? `
      <div style="display:flex;gap:8px;margin-bottom:8px;">
        <button id="btn-ack" style="flex:1;padding:11px;font-size:13px;border-radius:8px;border:none;background:var(--success);color:var(--on-success);">Acknowledge</button>
        <button id="btn-reject" style="flex:1;padding:11px;font-size:13px;border-radius:8px;border:1px solid var(--danger);background:transparent;color:var(--danger);">Reject</button>
      </div>
    ` : ''}
    ${showReferenceBtn ? `
      <button id="btn-reference" style="width:100%;padding:10px;font-size:13px;border-radius:8px;border:1px solid var(--accent);background:transparent;color:var(--accent);">Add to reference</button>
    ` : ''}
  `;

  if (pending) {
    area.querySelector('#btn-ack').addEventListener('click', async () => {
      const btn = area.querySelector('#btn-ack');
      btn.disabled = true;
      btn.textContent = 'Saving...';
      const { error } = await sb
        .from('ad_distribution_item')
        .update({ acknowledged: true, acknowledged_date: today })
        .eq('distrib_item_id', item.distrib_item_id);
      if (error) {
        alert('Could not acknowledge: ' + error.message);
        btn.disabled = false;
        btn.textContent = 'Acknowledge';
        return;
      }
      item.acknowledged = true;
      renderActionArea(app, ctx);
    });

    area.querySelector('#btn-reject').addEventListener('click', () => {
      app.querySelector('#reject-overlay').style.display = 'flex';
    });
  }

  if (showReferenceBtn) {
    area.querySelector('#btn-reference').addEventListener('click', async () => {
      if (!ctx.docId || !ctx.orgId) return;
      const refBtn = area.querySelector('#btn-reference');
      refBtn.disabled = true;
      refBtn.textContent = 'Adding...';
      const { data: { user } } = await sb.auth.getUser();
      const { error } = await sb
        .from('ad_document_reference')
        .insert({ organisation_id: ctx.orgId, user_id: user.id, doc_id: ctx.docId });
      if (error) {
        alert('Could not add to reference: ' + error.message);
        refBtn.disabled = false;
        refBtn.textContent = 'Add to reference';
        return;
      }
      ctx.alreadyReferenced = true;
      renderActionArea(app, ctx);
    });
  }

  const rejectSubmit = app.querySelector('#reject-submit');
  rejectSubmit.onclick = async () => {
    const reasonEl = app.querySelector('#reject-reason');
    const reason = reasonEl.value.trim();
    if (!reason) {
      app.querySelector('#reject-error').style.display = 'block';
      return;
    }
    rejectSubmit.disabled = true;
    rejectSubmit.textContent = 'Submitting...';
    const { error } = await sb
      .from('ad_distribution_item')
      .update({ rejected: true, rejected_date: today, rejected_reason: reason })
      .eq('distrib_item_id', item.distrib_item_id);
    rejectSubmit.disabled = false;
    rejectSubmit.textContent = 'Submit rejection';
    if (error) {
      alert('Could not submit rejection: ' + error.message);
      return;
    }
    item.rejected = true;
    app.querySelector('#reject-overlay').style.display = 'none';
    renderActionArea(app, ctx);
  };
}

async function loadPdf(app, pdfFile, docName) {
  const statusEl = app.querySelector('#pdf-status');
  const frame = app.querySelector('#pdf-frame');
  const fileName = pdfFile.download_file_name || docName.replace(/[^a-z0-9._-]/gi, '_') + '.pdf';

  try {
    let blobUrl;
    const sourceType = pdfFile.source_type || 'SUPABASE';

    if (sourceType === 'SUPABASE') {
      const { data: signedData, error: signErr } = await sb.storage
        .from(PDF_BUCKET)
        .createSignedUrl(pdfFile.storage_path, SIGNED_URL_EXPIRY);
      if (signErr || !signedData) throw new Error(signErr?.message || 'Could not get file URL');
      const resp = await fetch(signedData.signedUrl);
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      blobUrl = URL.createObjectURL(new File([await resp.blob()], fileName, { type: 'application/pdf' }));
    } else {
      const { data: { session } } = await sb.auth.getSession();
      const resp = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/fetch-document`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + session?.access_token,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY
        },
        body: JSON.stringify({ file_id: pdfFile.id })
      });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      blobUrl = URL.createObjectURL(new File([await resp.blob()], fileName, { type: 'application/pdf' }));
    }

    const hash = 'page=1&zoom=page-fit&pagemode=none&toolbar=1&navpanes=0&locale=en-US';
    frame.style.visibility = 'hidden';
    frame.onload = () => {
      injectPdfStyles(frame);
      setTimeout(() => { frame.style.visibility = ''; }, 150);
    };
    frame.src = `${PDF_VIEWER_URL}?file=${encodeURIComponent(blobUrl)}#${hash}`;
    frame.style.display = 'block';
    statusEl.style.display = 'none';
  } catch (e) {
    statusEl.innerHTML = `Could not load document.<br><span style="font-size:11px;">${e.message}</span>`;
    statusEl.style.color = 'var(--danger)';
  }
}

/* Same button-hiding approach as assets/js code in the web app's
   acknowledge.html - pdf.js's own viewer, fully within our control,
   unlike a native browser PDF viewer which has no equivalent hook. */
function injectPdfStyles(frame) {
  try {
    const doc = frame.contentDocument || frame.contentWindow.document;
    if (!doc || doc.getElementById('approvedoc-mobile-patch')) return;
    const style = doc.createElement('style');
    style.id = 'approvedoc-mobile-patch';
    style.textContent = `
      #secondaryToolbarToggle,
      #printButton, #secondaryPrintButton,
      #downloadButton, #secondaryDownloadButton,
      #editorFreeTextButton, #editorInkButton, #editorStampButton, #editorHighlightButton,
      #rotateCcwButton, #rotateCwButton,
      #openFileButton, #viewBookmarkButton, #documentPropertiesButton, #presentationModeButton,
      .verticalToolbarSeparator, .horizontalToolbarSeparator,
      .splitToolbarButtonSeparator, #editorModeSeparator {
        display: none !important;
      }
      /* pdf.js hides the zoom picklist below 560px viewport width by
         default (assumes narrow screens pinch-zoom instead) - force it
         back so mobile matches the desktop toolbar. */
      #scaleSelectContainer {
        display: inline-block !important;
      }`;
    doc.head.appendChild(style);
  } catch (e) {}
}
