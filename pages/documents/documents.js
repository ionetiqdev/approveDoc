// ════════════════════════════════════════════════════════════════════
// Documents module - main logic
// Ported from ionetiq Risk's real, production Documents module.
// Uses this template's existing sb client, Auth preferences, App.toast.
//
// The one substantive change from Risk's version: this template's
// documents storage bucket is PRIVATE (Risk's is public), so file
// access goes through createSignedUrl() instead of getPublicUrl().
// Everything downstream of that (fetch-as-blob, wrap in a named
// File, feed to pdf.js as an object URL) is unchanged - pdf.js only
// ever sees a local blob URL either way.
// ════════════════════════════════════════════════════════════════════

let DOC_FEATURES   = {};
let allDocs         = [];
let currentDocId    = null;
let currentFileUrl  = null;

// ── Elements ──────────────────────────────────────────────────────────
const docSidebarCol    = document.getElementById('docSidebarCol');
const docList          = document.getElementById('docList');
const docSearch        = document.getElementById('docSearch');
const docSearchWrap    = document.getElementById('docSearchWrap');
const docEmptyState    = document.getElementById('docEmptyState');
const docViewerToolbar = document.getElementById('docViewerToolbar');
const docViewerName    = document.getElementById('docViewerName');
const docPdfFrame      = document.getElementById('docPdfFrame');
const docDropZone      = document.getElementById('docDropZone');
const docDropZoneWrap  = document.getElementById('docDropZoneWrap');
const docFileInput     = document.getElementById('docFileInput');
const newDocBtn         = document.getElementById('newDocBtn');

(async () => {
  const session = await Auth.requireAuth();
  if (!session) return;
  SidebarHtml.inject(window._appRootUrl || '../../');
  Sidebar.init();
  Auth.refreshUI();

  bindPrefsModal();
  bindEditModal();
  bindUpload();
  bindCategoriesModal();
  await initApp();
  loadDocFeatures();
})();

// ── Feature flags (per-user override via Auth preferences) ───────────
function loadDocFeatures() {
  const override = Auth.getPreference('docViewerPrefs', null);
  DOC_FEATURES = JSON.parse(JSON.stringify(DOC_DEFAULT_FEATURES));

  // Only allow user prefs to override upload and delete — never pdfViewer or pdfButtons
  // (viewer appearance is an app-level config decision, not a user preference)
  if (override) {
    if (override.upload) Object.assign(DOC_FEATURES.upload, override.upload);
    if (override.delete) Object.assign(DOC_FEATURES.delete, override.delete);
  }
  applyDocFeatures();
}

function applyDocFeatures() {
  const f = DOC_FEATURES;

  // New document button
  if (newDocBtn) {
    newDocBtn.classList.toggle('d-none', f.upload?.enabled === false || f.upload?.modalButton === false);
  }

  // Drop zone
  if (docDropZoneWrap) {
    docDropZoneWrap.classList.toggle('d-none', f.upload?.enabled === false || f.upload?.dropZone === false);
  }

  // Download button in viewer toolbar
  const dlBtn = document.getElementById('docDownloadBtn');
  if (dlBtn) {
    dlBtn.classList.toggle('d-none', f.pdfButtons?.download === false);
  }

  // Delete — re-render list so rows reflect current setting
  if (typeof renderDocList === 'function' && typeof filterDocs === 'function') {
    renderDocList(filterDocs());
  }
}

// ── Preferences modal ──────────────────────────────────────────────────
function bindPrefsModal() {
  const modalEl = document.getElementById('docPrefsModal');
  if (!modalEl) return;

  // CRITICAL: create exactly ONE bootstrap.Modal instance for this
  // element, once, here - and use this same instance for every open
  // and close operation below. The button's data-bs-toggle/
  // data-bs-target attributes have been removed from the HTML
  // specifically so nothing else can create a second, competing
  // instance via Bootstrap's own declarative trigger mechanism.
  //
  // Mixing declarative-open with JS-created-instance-close is a
  // documented Bootstrap failure mode: two separate Modal objects
  // end up bound to the same element, each independently creating/
  // tracking its own .modal-backdrop - one instance's hide() removes
  // its own backdrop while the OTHER instance's backdrop (from the
  // declarative open) is left orphaned, exactly producing the
  // page-frozen grey-screen bug this fixes. See e.g. the DataTables
  // forum thread on this exact symptom, root-caused to "creation of
  // a new modal object every time" rather than reusing one instance.
  const instance = bootstrap.Modal.getOrCreateInstance(modalEl);

  document.getElementById('docPrefsBtn')?.addEventListener('click', () => instance.show());

  modalEl.addEventListener('show.bs.modal', () => {
    document.getElementById('docPrefUploadButton').checked   = DOC_FEATURES.upload?.modalButton !== false;
    document.getElementById('docPrefDropZone').checked       = DOC_FEATURES.upload?.dropZone !== false;
    document.getElementById('docPrefPromptOnDrop').checked   = DOC_FEATURES.upload?.promptOnDrop !== false;
    document.getElementById('docPrefDeleteEnabled').checked  = DOC_FEATURES.delete?.enabled !== false;
  });

  document.getElementById('docPrefSaveBtn')?.addEventListener('click', async () => {
    await saveDocPrefs();
    modalEl.addEventListener('hidden.bs.modal', () => {
      loadDocFeatures();
      renderDocList(filterDocs());
    }, { once: true });
    instance.hide();
  });
}

async function saveDocPrefs() {
  const override = {
    upload: {
      modalButton:  document.getElementById('docPrefUploadButton')?.checked ?? true,
      dropZone:     document.getElementById('docPrefDropZone')?.checked     ?? true,
      promptOnDrop: document.getElementById('docPrefPromptOnDrop')?.checked ?? true,
    },
    delete: { enabled: document.getElementById('docPrefDeleteEnabled')?.checked ?? true },
  };
  await Auth.setPreference('docViewerPrefs', override);
  loadDocFeatures();
  renderDocList(filterDocs());
}

// ── Build pdf.js URL hash ─────────────────────────────────────────────
function buildPdfHash() {
  const v = DOC_FEATURES.pdfViewer || {};
  const pagemode = v.defaultPanel || 'thumbs';
  const zoom     = v.defaultZoom  || 'page-fit';
  const toolbar  = v.showToolbar  !== false ? 1 : 0;
  const navpanes = v.showNavPanes !== false ? 1 : 0;

  return [
    'page=1',
    `zoom=${zoom}`,
    `pagemode=${pagemode}`,
    `toolbar=${toolbar}`,
    `navpanes=${navpanes}`,
    'locale=en-US',
  ].join('&');
}

// ── Load document list ────────────────────────────────────────────────
let allCategories = [];

async function loadCategories() {
  const orgId = Auth.getOrganisationId();
  if (!orgId) { allCategories = []; return; }

  const { data, error } = await sb
    .from(DOC_CONFIG.tableCategoryLookup)
    .select(`${DOC_CONFIG.colCategoryId}, ${DOC_CONFIG.colCategoryName}`)
    .eq(DOC_CONFIG.colOrgId, orgId)
    .order(DOC_CONFIG.colCategoryOrder);

  if (error) { console.error('Failed to load document categories:', error.message); return; }
  allCategories = data || [];

  const selectIds = ['docModalCategory', 'docCategoryFilter', 'editDocCategory', 'dropPromptCategory'];
  selectIds.forEach(id => {
    const sel = document.getElementById(id);
    if (!sel) return;
    // Clear out any options from a previous load first - this function
    // gets called again after adding/deleting a category, and without
    // this, every select would accumulate duplicate <option> entries.
    while (sel.options.length > 1) sel.remove(1);
    allCategories.forEach(c => {
      const o = document.createElement('option');
      o.value = c[DOC_CONFIG.colCategoryId];
      o.textContent = c[DOC_CONFIG.colCategoryName];
      sel.appendChild(o);
    });
  });
}

function categoryName(id) {
  const c = allCategories.find(c => c[DOC_CONFIG.colCategoryId] === id);
  return c ? c[DOC_CONFIG.colCategoryName] : null;
}

// ── Categories management (admin/super_admin only - gated in the
// HTML via data-require-role, this JS doesn't re-check the role,
// RLS on document_category_lookup is the real enforcement) ──────────
function bindCategoriesModal() {
  document.getElementById('categoriesModal').addEventListener('show.bs.modal', renderCategoriesList);
  document.getElementById('addCategoryBtn').addEventListener('click', addCategory);
}

function renderCategoriesList() {
  const list = document.getElementById('categoriesList');
  if (!allCategories.length) {
    list.innerHTML = '<li class="list-group-item text-secondary small">No categories yet.</li>';
    return;
  }
  // allCategories is already ordered by document_category_order (see
  // loadCategories()'s .order() call) - render in that same order so
  // the list's visual order always matches the database order.
  list.innerHTML = allCategories.map(c => `
    <li class="list-group-item d-flex justify-content-between align-items-center category-drag-item" draggable="true" data-id="${c[DOC_CONFIG.colCategoryId]}">
      <span class="d-flex align-items-center gap-2">
        <i class="ti ti-grip-vertical text-secondary category-drag-handle" style="cursor:grab"></i>
        ${App.escHtml(c[DOC_CONFIG.colCategoryName])}
      </span>
      <button class="btn btn-icon btn-icon-lg text-danger delete-category-btn" data-id="${c[DOC_CONFIG.colCategoryId]}"><i class="ti ti-trash"></i></button>
    </li>`).join('');

  list.querySelectorAll('.delete-category-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const ok = await App.confirm({
        title: 'Delete category?',
        message: 'Documents in this category will become uncategorised, not deleted.',
        confirmText: 'Delete'
      });
      if (!ok) return;
      const { error } = await sb.from(DOC_CONFIG.tableCategoryLookup).delete().eq(DOC_CONFIG.colCategoryId, btn.dataset.id);
      if (error) { App.toast('Delete failed: ' + error.message, 'danger'); return; }
      await loadCategories();
      renderCategoriesList();
      renderDocList(filterDocs());
    });
  });

  _bindCategoryDragReorder(list);
}

async function addCategory() {
  const input = document.getElementById('newCategoryName');
  const name = input.value.trim();
  const errorEl = document.getElementById('categoriesModalError');
  errorEl.classList.add('d-none');

  if (!name) {
    errorEl.textContent = 'Category name is required.';
    errorEl.classList.remove('d-none');
    return;
  }

  const orgId = Auth.getOrganisationId();
  const { error } = await sb.from(DOC_CONFIG.tableCategoryLookup).insert({
    [DOC_CONFIG.colCategoryName]: name,
    [DOC_CONFIG.colOrgId]: orgId,
    [DOC_CONFIG.colCategoryOrder]: allCategories.length
  });

  if (error) { errorEl.textContent = error.message; errorEl.classList.remove('d-none'); return; }

  input.value = '';
  await loadCategories();
  renderCategoriesList();
}

// ── Drag-and-drop reordering of categories ───────────────────────────
// Native HTML5 drag-and-drop (no extra library) - dragging a row
// reorders the DOM list live as you drag over other rows, then on
// drop, every category's document_category_order is rewritten to
// match the new visual order and persisted in one batch.
function _bindCategoryDragReorder(list) {
  let draggedEl = null;

  list.querySelectorAll('.category-drag-item').forEach(item => {
    item.addEventListener('dragstart', () => {
      draggedEl = item;
      item.classList.add('opacity-50');
    });

    item.addEventListener('dragend', () => {
      item.classList.remove('opacity-50');
      draggedEl = null;
    });

    item.addEventListener('dragover', e => {
      e.preventDefault();
      if (!draggedEl || draggedEl === item) return;
      const rect = item.getBoundingClientRect();
      const isAfter = (e.clientY - rect.top) > rect.height / 2;
      item.parentNode.insertBefore(draggedEl, isAfter ? item.nextSibling : item);
    });

    item.addEventListener('drop', async e => {
      e.preventDefault();
      await _persistCategoryOrder(list);
    });
  });
}

// Reads the current DOM order of .category-drag-item elements and
// writes a fresh document_category_order (0, 1, 2, ...) to match,
// for every category whose order actually changed - not a blind
// rewrite of every row regardless of whether it moved.
async function _persistCategoryOrder(list) {
  const orderedIds = [...list.querySelectorAll('.category-drag-item')].map(el => el.dataset.id);

  const updates = orderedIds
    .map((id, index) => ({ id, index }))
    .filter(({ id, index }) => {
      const current = allCategories.find(c => c[DOC_CONFIG.colCategoryId] === id);
      return current && current[DOC_CONFIG.colCategoryOrder] !== index;
    });

  if (!updates.length) return; // dropped back in the same position - nothing to persist

  await Promise.all(
    updates.map(({ id, index }) =>
      sb.from(DOC_CONFIG.tableCategoryLookup).update({ [DOC_CONFIG.colCategoryOrder]: index }).eq(DOC_CONFIG.colCategoryId, id)
    )
  );

  await loadCategories();
  App.toast('Category order updated');
}

async function loadDocuments() {
  const orgId = Auth.getOrganisationId();
  if (!orgId) {
    allDocs = [];
    docList.innerHTML = `<div class="text-center text-secondary py-4 small">No organisation assigned to your account. Contact an administrator.</div>`;
    return;
  }

  const { data, error } = await sb
    .from(DOC_CONFIG.tableDocs)
    .select(`${DOC_CONFIG.colDocId}, ${DOC_CONFIG.colDocDesc}, description, ${DOC_CONFIG.colDocCatId}, ${DOC_CONFIG.tableFiles}(id, file_name, storage_path, source_type, external_url, external_ref, download_file_name, mime_type, created_at)`)
    .eq(DOC_CONFIG.colOrgId, orgId)
    .order(DOC_CONFIG.colDocId);

  if (error) { App.toast('Failed to load documents', 'danger'); return; }
  allDocs = data || [];
  renderDocList(filterDocs());
}

function filterDocs() {
  const q   = docSearch?.value.toLowerCase() || '';
  const cat = document.getElementById('docCategoryFilter')?.value || '';
  return allDocs.filter(d => {
    const matchesSearch = (d[DOC_CONFIG.colDocDesc] || '').toLowerCase().includes(q);
    const matchesCat     = !cat || d[DOC_CONFIG.colDocCatId] === cat;
    return matchesSearch && matchesCat;
  });
}

function renderDocList(docs) {
  if (!docs.length) {
    docList.innerHTML = `
      <div class="text-center text-secondary py-4 small">
        <i class="ti ti-folder-open" style="font-size:1.75rem;opacity:.3"></i>
        <p class="mt-2 mb-0">No documents yet.<br>Upload a PDF to get started.</p>
      </div>`;
    return;
  }
  const showDelete = DOC_FEATURES.delete?.enabled !== false && Auth.canEdit();
  docList.innerHTML = docs.map(d => {
    const catName = categoryName(d[DOC_CONFIG.colDocCatId]);
    const desc    = d.description || '';
    return `
    <div class="doc-list-item ${d[DOC_CONFIG.colDocId] === currentDocId ? 'active' : ''}" data-id="${d[DOC_CONFIG.colDocId]}">
      <div class="d-flex align-items-start gap-2">
        <div class="select-doc-trigger flex-grow-1" data-id="${d[DOC_CONFIG.colDocId]}" style="cursor:pointer;min-width:0">
          <div class="d-flex align-items-center justify-content-between gap-2">
            <div class="doc-list-title" style="min-width:0">${App.escHtml(d[DOC_CONFIG.colDocDesc] || 'Untitled document')}</div>
            ${catName ? `<span class="badge bg-blue-lt text-nowrap flex-shrink-0">${App.escHtml(catName)}</span>` : ''}
          </div>
          ${desc ? `<div class="text-secondary" style="font-size:.72rem;margin-top:20px">${App.escHtml(desc)}</div>` : ''}
        </div>
        <button class="btn btn-icon btn-icon-lg edit-doc-trigger flex-shrink-0" data-id="${d[DOC_CONFIG.colDocId]}" title="Edit"><i class="ti ti-edit"></i></button>
        ${showDelete ? `<button class="btn btn-icon btn-icon-lg text-danger delete-doc-trigger flex-shrink-0" data-id="${d[DOC_CONFIG.colDocId]}" title="Delete"><i class="ti ti-trash"></i></button>` : ''}
      </div>
    </div>`;
  }).join('');

  docList.querySelectorAll('.doc-list-item').forEach(el => {
    el.style.cursor = 'pointer';
    el.addEventListener('click', () => selectDoc(el.dataset.id));
  });
  docList.querySelectorAll('.edit-doc-trigger').forEach(el => {
    el.addEventListener('click', e => { e.stopPropagation(); openEditDocModal(el.dataset.id, e); });
  });
  docList.querySelectorAll('.delete-doc-trigger').forEach(el => {
    el.addEventListener('click', e => { e.stopPropagation(); deleteDoc(el.dataset.id, e); });
  });
}

if (docSearch) {
  docSearch.addEventListener('input', () => renderDocList(filterDocs()));
}


// ── Video viewer (Plyr) ───────────────────────────────────────────────────
let _plyrInstance = null;

function _youtubeId(url) {
  if (!url) return null;
  const m = url.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|embed\/|v\/))([a-zA-Z0-9_-]{11})/);
  return m ? m[1] : null;
}

async function loadVideo(file, docName) {
  docPdfFrame.style.display = 'none';
  docEmptyState.style.display = 'none';

  const videoWrap  = document.getElementById('docVideoWrap');
  const videoEl    = document.getElementById('docVideoPlayer');
  const youtubeEl  = document.getElementById('docYoutubePlayer');
  videoWrap.style.display = 'block';

  if (_plyrInstance) { _plyrInstance.destroy(); _plyrInstance = null; }

  const sourceType = file.source_type || 'SUPABASE';
  let src = '';

  if (sourceType === 'SUPABASE') {
    const { data: signed } = await sb.storage
      .from(DOC_CONFIG.bucket)
      .createSignedUrl(file.storage_path, 3600);
    if (!signed?.signedUrl) { App.toast('Could not access video file', 'danger'); return; }
    src = signed.signedUrl;
  } else if (file.external_url) {
    src = file.external_url;
  }

  const youtubeId = _youtubeId(src);

  if (youtubeId) {
    // YouTube — use Plyr embed div
    videoEl.style.display = 'none';
    youtubeEl.style.display = 'block';
    youtubeEl.innerHTML = `<div class="plyr__video-embed" id="plyrYoutubeInner" style="width:100%;height:100%">
      <iframe src="https://www.youtube.com/embed/${youtubeId}?origin=${encodeURIComponent(window.location.origin)}&iv_load_policy=3&modestbranding=1&playsinline=1&showinfo=0&rel=0&enablejsapi=1"
        allowfullscreen allowtransparency allow="autoplay" style="width:100%;height:100%;border:none"></iframe>
    </div>`;
    _plyrInstance = new Plyr('#plyrYoutubeInner', {
      controls: ['play-large','play','progress','current-time','mute','volume','fullscreen'],
    });
  } else {
    // Native video
    youtubeEl.style.display = 'none';
    videoEl.style.display = 'block';
    videoEl.src = src;
    videoEl.type = file.mime_type || 'video/mp4';
    _plyrInstance = new Plyr(videoEl, {
      controls: ['play-large','play','rewind','fast-forward','progress','current-time','duration','mute','volume','fullscreen'],
      resetOnEnd: false,
    });
  }
}

// ── Inject CSS into pdf.js iframe ────────────────────────────────────
function injectPdfStyles() {
  try {
    const doc = docPdfFrame.contentDocument || docPdfFrame.contentWindow.document;
    if (!doc || doc.getElementById('ionetiq-doc-patch')) return;

    const b = DOC_FEATURES.pdfButtons || {};

    const hideRules = [
      { key: 'rotate',             selectors: ['#rotateCcwButton', '#rotateCwButton'] },
      { key: 'annotationEditor',   selectors: ['#editorFreeTextButton', '#editorInkButton', '#editorStampButton', '#editorHighlightButton'] },
      { key: 'print',              selectors: ['#printButton'] },
      { key: 'download',           selectors: ['#downloadButton', '#secondaryDownloadButton'] },
      { key: 'openFile',           selectors: ['#openFileButton'] },
      { key: 'viewBookmark',       selectors: ['#viewBookmarkButton'] },
      { key: 'documentProperties', selectors: ['#documentPropertiesButton'] },
      { key: 'presentationMode',   selectors: ['#presentationModeButton'] },
      { key: 'spreadOdd',          selectors: ['#spreadOddButton'] },
      { key: 'spreadEven',         selectors: ['#spreadEvenButton'] },
      { key: 'scrollWrapped',      selectors: ['#scrollWrappedButton'] },
      { key: 'scrollPage',         selectors: ['#scrollPageButton'] },
    ];

    const hideCss = hideRules
      .filter(r => b[r.key] === false)
      .map(r => r.selectors.join(', ') + ' { display: none !important; }')
      .join('\n');

    const style = doc.createElement('style');
    style.id = 'ionetiq-doc-patch';
    style.textContent = `
      #scaleSelect, #scaleSelect option,
      .dropdownToolbarButton > select,
      .dropdownToolbarButton > select option {
        color: #000 !important;
        background-color: #fff !important;
      }
      /* Always hidden: overflow menu, print, download, separators */
      #secondaryToolbarToggle,
      #printButton, #secondaryPrintButton,
      #downloadButton, #secondaryDownloadButton,
      .verticalToolbarSeparator, .horizontalToolbarSeparator,
      .splitToolbarButtonSeparator,
      #editorModeSeparator,
      .verticalToolbarSeparator.hiddenMediumView {
        display: none !important;
      }
      #secondaryToolbar, .secondaryToolbar {
        background: #fff !important;
      }
      .secondaryToolbarButton,
      #secondaryToolbarButtonContainer button {
        color: #333 !important;
        background: transparent !important;
      }
      .secondaryToolbarButton:hover,
      #secondaryToolbarButtonContainer button:hover {
        background-color: #f0f0f0 !important;
      }
      .secondaryToolbarButton > span,
      #secondaryToolbarButtonContainer button > span {
        color: #333 !important;
      }
      #findbar { background: #f9f9f9 !important; color: #000 !important; }
      #findInput { color: #000 !important; background: #fff !important; }
      dialog, .dialog { color: #000 !important; }

      ${hideCss}
    `;
    doc.head.appendChild(style);
  } catch(e) {
    console.warn('Could not inject styles into pdf.js iframe:', e.message);
  }
}

// ── Select & view document ────────────────────────────────────────────
async function selectDoc(id) {
  currentDocId = id;
  renderDocList(allDocs.filter(d =>
    (d[DOC_CONFIG.colDocDesc] || '').toLowerCase().includes(docSearch?.value.toLowerCase() || '')
  ));

  const doc = allDocs.find(d => d[DOC_CONFIG.colDocId] === id);
  if (!doc) return;

  const files = doc[DOC_CONFIG.tableFiles] || [];
  const pdfFile = files[0];
  if (!pdfFile) { App.toast('No file attached to this document', 'warning'); return; }

  docViewerName.textContent = doc[DOC_CONFIG.colDocDesc] || pdfFile.file_name;
  docViewerToolbar.style.display = 'flex';

  // Hide video wrap when switching docs
  const videoWrap = document.getElementById('docVideoWrap');
  if (videoWrap) videoWrap.style.display = 'none';
  if (_plyrInstance) { _plyrInstance.destroy(); _plyrInstance = null; }

  // Route to video or PDF viewer based on MIME type
  const mime = pdfFile.mime_type || '';
  if (mime.startsWith('video/') || mime.startsWith('audio/') || mime === 'video/youtube' || mime === 'video/vimeo') {
    await loadVideo(pdfFile, doc[DOC_CONFIG.colDocDesc] || pdfFile.file_name);
    return;
  }

  // Fetch the PDF — route depends on source type
  let fetchUrl;
  const sourceType = pdfFile.source_type || 'SUPABASE';

  if (sourceType === 'SUPABASE') {
    // Private bucket — get a short-lived signed URL then fetch to blob
    const { data: signedData, error: signError } = await sb.storage
      .from(DOC_CONFIG.bucket)
      .createSignedUrl(pdfFile.storage_path, DOC_CONFIG.signedUrlExpirySeconds);

    if (signError || !signedData) {
      App.toast('Could not access file: ' + (signError?.message || 'Unknown error'), 'danger');
      return;
    }
    fetchUrl = signedData.signedUrl;
    currentFileUrl = fetchUrl;

  } else {
    // External source — proxy through edge function with auth token
    const saved = AppSession.load();
    const token = saved?.access_token;
    fetchUrl = `${SUPABASE_URL}/functions/v1/fetch-document`;
    currentFileUrl = fetchUrl;

    // Show loading spinner while the edge function fetches the external doc
    const emptyStateOriginal = docEmptyState.innerHTML;
    docEmptyState.innerHTML = `
      <div class="spinner-border text-secondary mb-3" style="width:2rem;height:2rem"></div>
      <div class="text-secondary small">Fetching document…</div>`;
    docEmptyState.style.display = 'flex';
    docPdfFrame.style.display = 'none';

    // We'll use a special fetch below for the edge function
    let pdfBlobUrl;
    try {
      const resp = await fetch(fetchUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + token,
          'apikey': SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({ file_id: pdfFile.id }),
      });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const blob = await resp.blob();
      if (window._currentDocBlob) URL.revokeObjectURL(window._currentDocBlob);

      const downloadName = pdfFile.download_file_name || sanitizeFileName(doc[DOC_CONFIG.colDocDesc] || pdfFile.file_name);
      const namedFile = new File([blob], downloadName, { type: pdfFile?.mime_type || 'application/pdf' });
      pdfBlobUrl = URL.createObjectURL(namedFile);
      window._currentDocBlob = pdfBlobUrl;

      const downloadBtn = document.getElementById('docDownloadBtn');
      if (downloadBtn) {
        downloadBtn.onclick = () => {
          const a = document.createElement('a');
          a.href = pdfBlobUrl;
          a.download = downloadName;
          document.body.appendChild(a);
          a.click();
          a.remove();
        };
      }
    } catch(e) {
      docEmptyState.innerHTML = emptyStateOriginal;
      App.toast('Could not fetch external document: ' + e.message, 'danger');
      return;
    }

    const hash = buildPdfHash();
    docEmptyState.style.display = 'none';
    docPdfFrame.style.visibility = 'hidden';
    docPdfFrame.style.display = 'block';
    docPdfFrame.onload = () => {
      injectPdfStyles();
      setTimeout(() => { docPdfFrame.style.visibility = ''; }, 150);
    };
    docPdfFrame.src = `${DOC_CONFIG.pdfViewerUrl}?file=${encodeURIComponent(pdfBlobUrl)}#${hash}`;
    return; // early return — frame is already set
  }

  currentFileUrl = fetchUrl;

  // Fetch as blob so pdf.js's validateFileURL never blocks it
  let pdfBlobUrl;
  try {
    const resp = await fetch(fetchUrl);
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const blob = await resp.blob();
    if (window._currentDocBlob) URL.revokeObjectURL(window._currentDocBlob);

    const downloadName = pdfFile.download_file_name || sanitizeFileName(doc[DOC_CONFIG.colDocDesc] || pdfFile.file_name);
    const namedFile = new File([blob], downloadName, { type: pdfFile?.mime_type || 'application/pdf' });

    pdfBlobUrl = URL.createObjectURL(namedFile);
    window._currentDocBlob = pdfBlobUrl;

    const downloadBtn = document.getElementById('docDownloadBtn');
    if (downloadBtn) {
      downloadBtn.onclick = () => {
        const a = document.createElement('a');
        a.href = pdfBlobUrl;
        a.download = downloadName;
        document.body.appendChild(a);
        a.click();
        a.remove();
      };
    }
  } catch(e) {
    App.toast('Could not fetch PDF: ' + e.message, 'danger');
    return;
  }

  const hash = buildPdfHash();
  docEmptyState.style.display = 'none';
  docPdfFrame.style.visibility = 'hidden';
  docPdfFrame.style.display = 'block';
  docPdfFrame.onload = () => {
    injectPdfStyles();
    setTimeout(() => { docPdfFrame.style.visibility = ''; }, 150);
  };
  docPdfFrame.src = `${DOC_CONFIG.pdfViewerUrl}?file=${encodeURIComponent(pdfBlobUrl)}#${hash}`;
}

function sanitizeFileName(name) {
  let base = (name || 'document').replace(/\.pdf$/i, '').trim();
  base = base.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_\-]/g, '');
  if (!base) base = 'document';
  return base + '.pdf';
}

// ── Edit document (name & category) ────────────────────────────────────
function openEditDocModal(id, e) {
  if (e) e.stopPropagation();
  const doc = allDocs.find(d => d[DOC_CONFIG.colDocId] === id);
  if (!doc) return;

  document.getElementById('editDocId').value               = id;
  document.getElementById('editDocDescription').value      = doc[DOC_CONFIG.colDocDesc] || '';
  document.getElementById('editDocDescriptionText').value  = doc.description || '';
  document.getElementById('editDocCategory').value         = doc[DOC_CONFIG.colDocCatId] || '';

  new bootstrap.Modal(document.getElementById('editDocModal')).show();
}

function bindEditModal() {
  document.getElementById('editDocSaveBtn').addEventListener('click', async () => {
    const id   = document.getElementById('editDocId').value;
    const desc        = document.getElementById('editDocDescription').value.trim();
    const descText    = document.getElementById('editDocDescriptionText').value.trim();
    const cat         = document.getElementById('editDocCategory').value || null;

    if (!desc) { App.toast('Name is required', 'warning'); return; }

    const payload = { [DOC_CONFIG.colDocDesc]: desc, description: descText || null, [DOC_CONFIG.colDocCatId]: cat };
    const { error } = await sb.from(DOC_CONFIG.tableDocs).update(payload).eq(DOC_CONFIG.colDocId, id);

    if (error) { App.toast('Update failed: ' + error.message, 'danger'); return; }

    const newDownloadName = sanitizeFileName(desc);
    await sb.from(DOC_CONFIG.tableFiles)
      .update({ download_file_name: newDownloadName })
      .eq(DOC_CONFIG.colDocId, id);

    App.toast('Document updated');
    bootstrap.Modal.getInstance(document.getElementById('editDocModal')).hide();

    if (id === currentDocId) docViewerName.textContent = desc;
    await loadDocuments();
  });
}

async function deleteDoc(id, e) {
  if (e) e.stopPropagation();
  const ok = await App.confirm({
    title: 'Delete document?',
    message: 'This will permanently delete the document and its file.',
    confirmText: 'Delete',
    confirmClass: 'btn-danger'
  });
  if (!ok) return;

  const doc = allDocs.find(d => d[DOC_CONFIG.colDocId] === id);
  const files = doc?.[DOC_CONFIG.tableFiles] || [];

  if (files.length) {
    await sb.storage.from(DOC_CONFIG.bucket).remove(files.map(f => f.storage_path));
  }

  const { error } = await sb.from(DOC_CONFIG.tableDocs).delete().eq(DOC_CONFIG.colDocId, id);
  if (error) { App.toast('Delete failed: ' + error.message, 'danger'); return; }

  App.toast('Document deleted');

  if (currentDocId === id) {
    currentDocId   = null;
    currentFileUrl = null;
    docPdfFrame.style.display = 'none';
    docPdfFrame.src = '';
    docEmptyState.style.display = 'flex';
    docViewerToolbar.style.display = 'none';
    docViewerName.textContent = '';
  }

  await loadDocuments();
}

// ── Upload ────────────────────────────────────────────────────────────
async function uploadAndSave(description, file, progressBar, statusEl, categoryId, descriptionText) {
  if (!file) { App.toast('Please select a file', 'warning'); return false; }

  const isWord = /\.(docx?|doc)$/i.test(file.name) ||
    file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
    file.type === 'application/msword';

  const orgId = Auth.getOrganisationId();
  if (!orgId) { App.toast('No organisation assigned to your account', 'danger'); return false; }

  const safeName = `${orgId}/${Date.now()}_${file.name.replace(/[^a-z0-9._-]/gi, '_')}`;

  if (statusEl) statusEl.textContent = 'Creating document record…';
  if (progressBar) progressBar.style.width = '10%';

  const docPayload = { [DOC_CONFIG.colDocDesc]: description || file.name, [DOC_CONFIG.colOrgId]: orgId };
  if (categoryId) docPayload[DOC_CONFIG.colDocCatId] = categoryId;
  if (descriptionText) docPayload.description = descriptionText;

  const { data: docData, error: docErr } = await sb
    .from(DOC_CONFIG.tableDocs)
    .insert(docPayload)
    .select()
    .single();

  if (docErr) { App.toast('Failed to create record: ' + (docErr.message || docErr.code), 'danger'); return false; }
  if (progressBar) progressBar.style.width = '25%';

  if (statusEl) statusEl.textContent = 'Uploading file…';
  const { error: upErr } = await sb.storage
    .from(DOC_CONFIG.bucket)
    .upload(safeName, file, { contentType: file.type || 'application/pdf', upsert: false });

  if (upErr) {
    App.toast('Upload failed: ' + upErr.message, 'danger');
    await sb.from(DOC_CONFIG.tableDocs).delete().eq(DOC_CONFIG.colDocId, docData[DOC_CONFIG.colDocId]);
    return false;
  }
  if (progressBar) progressBar.style.width = '50%';

  let finalPath = safeName;
  let finalMime = file.type || 'application/pdf';

  if (isWord) {
    if (statusEl) statusEl.textContent = 'Converting to PDF…';
    try {
      const saved = AppSession.load();
      const convRes = await fetch(`${SUPABASE_URL}/functions/v1/convert-document`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + saved?.access_token,
          'apikey': SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({ storage_path: safeName, bucket: DOC_CONFIG.bucket }),
      });
      const convData = await convRes.json();
      if (!convRes.ok || convData.error) throw new Error(convData.error || 'Conversion failed');
      finalPath = convData.pdf_path;
      finalMime = 'application/pdf';
      if (progressBar) progressBar.style.width = '80%';
    } catch(e) {
      App.toast('Word conversion failed: ' + e.message + '. Original file saved.', 'warning');
    }
  }

  if (progressBar) progressBar.style.width = '90%';
  if (statusEl) statusEl.textContent = 'Saving file reference…';
  const downloadFileName = sanitizeFileName(description || file.name).replace(/\.(docx?|doc)$/i, '.pdf');
  const { error: fileErr } = await sb.from(DOC_CONFIG.tableFiles).insert({
    [DOC_CONFIG.colDocId]: docData[DOC_CONFIG.colDocId],
    [DOC_CONFIG.colOrgId]: orgId,
    file_name: file.name,
    storage_path: finalPath,
    download_file_name: downloadFileName,
    file_size_bytes: file.size,
    mime_type: finalMime
  });

  if (fileErr) { App.toast('File reference failed: ' + fileErr.message, 'danger'); return false; }

  if (progressBar) progressBar.style.width = '100%';
  if (statusEl) statusEl.textContent = 'Done!';

  App.toast('Document uploaded successfully');
  await loadDocuments();
  selectDoc(docData[DOC_CONFIG.colDocId]);
  return true;
}

function bindUpload() {
  // Source type toggle
  document.querySelectorAll('input[name="docSource"]').forEach(radio => {
    radio.addEventListener('change', () => {
      const v = radio.value;
      document.getElementById('docSourceFileField').classList.toggle('d-none', v !== 'file');
      document.getElementById('docSourceGdriveField').classList.toggle('d-none', v !== 'gdrive');
      document.getElementById('docSourceUrlField').classList.toggle('d-none', v !== 'url');
      document.getElementById('docSourceRestField').classList.toggle('d-none', v !== 'rest');
      document.getElementById('docModalSaveBtn').textContent = v === 'file' ? 'Upload' : 'Save';
    });
  });

  // REST auth type shows/hides credential fields
  document.getElementById('docModalRestAuth')?.addEventListener('change', function() {
    const isToken = ['BEARER','API_KEY'].includes(this.value);
    const isBasic = this.value === 'BASIC';
    document.getElementById('docModalRestTokenField').classList.toggle('d-none', !isToken);
    document.getElementById('docModalRestBasicFields').classList.toggle('d-none', !isBasic);
  });

  document.getElementById('docModalSaveBtn').addEventListener('click', async () => {
    const desc     = document.getElementById('docModalDescription').value.trim();
    const descText = document.getElementById('docModalDescriptionText').value.trim();
    const catId    = document.getElementById('docModalCategory').value || null;
    const source   = document.querySelector('input[name="docSource"]:checked')?.value || 'file';
    const progWrap = document.getElementById('docModalProgress');
    const progBar  = document.getElementById('docUploadProgressBar');
    const status   = document.getElementById('docUploadStatus');
    const saveBtn  = document.getElementById('docModalSaveBtn');

    if (!desc) { App.toast('Name is required', 'warning'); return; }

    saveBtn.disabled = true;

    let success = false;

    if (source === 'file') {
      const file = document.getElementById('docModalFile').files[0];
      progWrap.style.display = 'block';
      progBar.style.width = '0%';
      success = await uploadAndSave(desc, file, progBar, status, catId, descText);
      saveBtn.disabled = false;

    } else {
      // External source — create doc record + file record, no upload
      const orgId = Auth.getOrganisationId();

      let externalUrl = '';
      let sourceTypeVal = '';

      if (source === 'gdrive') {
        const raw = document.getElementById('docModalGdriveUrl').value.trim();
        if (!raw) { App.toast('Google Drive URL is required', 'warning'); saveBtn.disabled = false; return; }
        // Convert share URL to direct download URL
        const idMatch = raw.match(/\/d\/([a-zA-Z0-9_-]+)/);
        const fileId = idMatch ? idMatch[1] : null;
        if (!fileId) { App.toast('Could not extract file ID from Google Drive URL', 'warning'); saveBtn.disabled = false; return; }
        externalUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;
        sourceTypeVal = 'URL';

      } else if (source === 'url') {
        externalUrl = document.getElementById('docModalUrl').value.trim();
        sourceTypeVal = 'URL';
        if (!externalUrl) { App.toast('URL is required', 'warning'); saveBtn.disabled = false; return; }

      } else if (source === 'rest') {
        externalUrl = document.getElementById('docModalRestUrl').value.trim();
        sourceTypeVal = 'REST';
        if (!externalUrl) { App.toast('API endpoint is required', 'warning'); saveBtn.disabled = false; return; }
      }

      const externalRef = document.getElementById('docModalRestRef')?.value.trim() || null;

      try {
        // Create document
        const { data: docData, error: docErr } = await sb.from('ad_document').insert({
          name: desc, description: descText || null, category_id: catId, organisation_id: orgId
        }).select('doc_id').single();
        if (docErr) throw docErr;

        // For REST with auth, we'd store credentials in vault — for now store source config inline
        const authType = source === 'rest'
          ? document.getElementById('docModalRestAuth').value
          : 'NONE';

        // Detect mime type from URL
        function _mimeFromUrl(url) {
          if (/youtube\.com|youtu\.be/.test(url)) return 'video/youtube';
          if (/vimeo\.com/.test(url)) return 'video/vimeo';
          if (/\.mp4(\?|$)/i.test(url)) return 'video/mp4';
          if (/\.webm(\?|$)/i.test(url)) return 'video/webm';
          if (/\.mov(\?|$)/i.test(url)) return 'video/quicktime';
          return 'application/pdf';
        }

        // Create file record pointing to external source
        const fileName = externalUrl.split('/').pop()?.split('?')[0] || desc + '.pdf';
        const { error: fileErr } = await sb.from('ad_document_file').insert({
          doc_id:        docData.doc_id,
          organisation_id: orgId,
          file_name:     fileName,
          storage_path:  'external', // satisfies NOT NULL — not used for external sources
          download_file_name: fileName,
          mime_type:     _mimeFromUrl(externalUrl),
          source_type:   sourceTypeVal,
          external_url:  externalUrl,
          external_ref:  externalRef,
        });
        if (fileErr) throw fileErr;

        App.toast('Document saved');
        success = true;
      } catch(e) {
        App.toast('Save failed: ' + e.message, 'danger');
        saveBtn.disabled = false;
        return;
      }
      saveBtn.disabled = false;
    }

    if (success) {
      setTimeout(() => {
        const modalEl = document.getElementById('addDocModal');
        const instance = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl);
        instance.hide();
        modalEl.addEventListener('hidden.bs.modal', () => {
          document.getElementById('docModalDescription').value = '';
          document.getElementById('docModalDescriptionText').value = '';
          document.getElementById('docModalCategory').value = '';
          document.getElementById('docModalFile').value = '';
          document.getElementById('docModalUrl').value = '';
          document.getElementById('docModalGdriveUrl').value = '';
          document.getElementById('docModalRestUrl').value = '';
          document.getElementById('docModalRestRef').value = '';
          document.getElementById('docSourceFile').checked = true;
          document.getElementById('docSourceFileField').classList.remove('d-none');
          document.getElementById('docSourceGdriveField').classList.add('d-none');
          document.getElementById('docSourceUrlField').classList.add('d-none');
          document.getElementById('docSourceRestField').classList.add('d-none');
          document.getElementById('docModalSaveBtn').textContent = 'Upload';
          progWrap.style.display = 'none';
          document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
          document.body.classList.remove('modal-open');
          document.body.style.removeProperty('overflow');
          document.body.style.removeProperty('padding-right');
          loadDocuments();
        }, { once: true });
      }, 600);
    } else {
      progWrap.style.display = 'none';
      progBar.style.width = '0%';
    }
  });

  if (docDropZone) {
    docDropZone.addEventListener('click', () => docFileInput.click());
    docDropZone.addEventListener('dragover', e => { e.preventDefault(); docDropZone.classList.add('drag-over'); });
    docDropZone.addEventListener('dragleave', () => docDropZone.classList.remove('drag-over'));
    docDropZone.addEventListener('drop', async e => {
      e.preventDefault();
      docDropZone.classList.remove('drag-over');
      const file = e.dataTransfer.files[0];
      if (file && file.type === 'application/pdf') {
        await handleDroppedFile(file);
      } else {
        App.toast('Only PDF files are supported', 'warning');
      }
    });
  }

  if (docFileInput) {
    docFileInput.addEventListener('change', async () => {
      const file = docFileInput.files[0];
      if (file) await handleDroppedFile(file);
    });
  }

  bindDropPromptModal();
}

// ── Drop / quick-upload handling ──────────────────────────────────────
let _pendingDropFile = null;

async function handleDroppedFile(file) {
  if (DOC_FEATURES.upload?.promptOnDrop === false) {
    const defaultCat = allCategories.find(c => c[DOC_CONFIG.colCategoryName] === DOC_CONFIG.defaultCategoryName);
    await uploadAndSave(file.name.replace(/\.pdf$/i, ''), file, null, null, defaultCat ? defaultCat[DOC_CONFIG.colCategoryId] : null);
    return;
  }

  _pendingDropFile = file;
  document.getElementById('dropPromptFileName').textContent  = file.name;
  document.getElementById('dropPromptDescription').value     = file.name.replace(/\.pdf$/i, '');
  document.getElementById('dropPromptDescriptionText').value = '';
  document.getElementById('dropPromptCategory').value        = '';
  new bootstrap.Modal(document.getElementById('dropPromptModal')).show();
}

function bindDropPromptModal() {
  document.getElementById('dropPromptSaveBtn').addEventListener('click', async () => {
    const desc     = document.getElementById('dropPromptDescription').value.trim();
    const descText = document.getElementById('dropPromptDescriptionText').value.trim();
    const catId    = document.getElementById('dropPromptCategory').value || null;
    const progWrap = document.getElementById('dropPromptProgress');
    const progBar  = document.getElementById('dropPromptProgressBar');
    const status   = document.getElementById('dropPromptStatus');
    const saveBtn  = document.getElementById('dropPromptSaveBtn');

    if (!_pendingDropFile) return;

    progWrap.style.display = 'block';
    progBar.style.width = '0%';
    saveBtn.disabled = true;

    const success = await uploadAndSave(desc, _pendingDropFile, progBar, status, catId, descText);

    saveBtn.disabled = false;

    if (success) {
      setTimeout(() => {
        const dpModalEl = document.getElementById('dropPromptModal');
        const dpInstance = bootstrap.Modal.getInstance(dpModalEl) || new bootstrap.Modal(dpModalEl);
        dpInstance.hide();
        dpModalEl.addEventListener('hidden.bs.modal', () => {
          document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
          document.body.classList.remove('modal-open');
          document.body.style.removeProperty('overflow');
          document.body.style.removeProperty('padding-right');
        }, { once: true });
        progWrap.style.display = 'none';
        _pendingDropFile = null;
        docFileInput.value = '';
      }, 600);
    } else {
      progWrap.style.display = 'none';
      progBar.style.width = '0%';
    }
  });
}

// ── Init ──────────────────────────────────────────────────────────────
async function initApp() {
  await loadCategories();
  await loadDocuments();

  const catFilter = document.getElementById('docCategoryFilter');
  if (catFilter) catFilter.addEventListener('change', () => renderDocList(filterDocs()));
}
