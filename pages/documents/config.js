// ════════════════════════════════════════════════════════════════════
// Documents module - configuration
//
// Adapted from ionetiq Risk's real, production Documents module.
// Column names below are mapped to THIS template's actual schema
// (see supabase/02-documents.sql) - they differ from Risk's own
// column names in a few places (e.g. id vs document_id), which is
// exactly why this mapping layer exists: change the values here,
// not the rest of documents.js, if your schema ever differs.
// ════════════════════════════════════════════════════════════════════
const DOC_CONFIG = {

  // Storage - PRIVATE bucket (unlike Risk's public bucket choice -
  // see 01-core-schema.sql/02-documents.sql comments for why this
  // template defaults to private). Access goes through
  // createSignedUrl(), not getPublicUrl() - see _getFileUrl() in
  // documents.js for the one real adaptation this required.
  bucket: 'documents',
  signedUrlExpirySeconds: 60,

  // Database tables & columns
  tableDocs:    'ad_document',
  tableFiles:   'ad_document_file',
  colDocId:     'doc_id',
  colDocDesc:   'name',
  colDocCatId:  'category_id',

  tableCategoryLookup: 'ad_category',
  colCategoryId:       'category_id',
  colCategoryName:     'name',
  colCategoryOrder:    'sort_order',
  defaultCategoryName: 'Other',

  colOrgId:     'organisation_id',

  // pdf.js viewer path - relative to THIS page (pages/documents/index.html),
  // pdfjs lives in the shared assets/pdfjs vendor folder, not bundled
  // alongside this one page.
  pdfViewerUrl: '../../assets/pdfjs/web/viewer.html',

};

// Feature flags (formerly viewer-features.json) - edit defaults here.
// Per-user overrides are saved to Auth preferences (docViewerPrefs key).
const DOC_DEFAULT_FEATURES = {
  upload:     { enabled: true, dropZone: true, modalButton: true, promptOnDrop: true },
  delete:     { enabled: true },
  pdfViewer:  { defaultZoom: 'page-fit', defaultPanel: 'thumbs', showToolbar: true, showNavPanes: true },
  pdfButtons: {
    rotate: false, annotationEditor: false, print: true, download: true,
    openFile: false, viewBookmark: false, documentProperties: false,
    presentationMode: false, spreadOdd: true, spreadEven: true,
    scrollWrapped: true, scrollPage: true
  }
};
