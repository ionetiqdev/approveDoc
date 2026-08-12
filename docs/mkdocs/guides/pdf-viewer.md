# PDF Viewer

approveDoc uses a self-hosted copy of **pdf.js** loaded in an `<iframe>`.

## Why self-hosted

Self-hosting allows CSS injection into the iframe's document to customise the toolbar without CORS restrictions. A CDN-hosted pdf.js would block cross-origin style injection.

## Location

`assets/pdfjs/` — excluded from deployment zips, managed separately on the server.

## URL pattern

```
{pdfViewerUrl}?file={encodeURIComponent(blobUrl)}#{hash}
```

Example hash:
```
page=1&zoom=page-fit&pagemode=thumbs&toolbar=1&navpanes=1&locale=en-US
```

## Blob URL approach

PDFs are always fetched to a blob URL before being passed to pdf.js:

```js
const resp    = await fetch(signedUrl);
const blob    = await resp.blob();
const named   = new File([blob], 'document.pdf', { type: 'application/pdf' });
const blobUrl = URL.createObjectURL(named);
```

**Why:** pdf.js validates the file URL and blocks external hosts (CORS, CSP). A `blob:` URL bypasses this check entirely.

## CSS injection

After the iframe's `load` event fires, `injectPdfStyles()` injects a `<style>` element into the iframe's document to hide unwanted controls:

```js
function injectPdfStyles(frame) {
  const doc = frame.contentDocument;
  const style = doc.createElement('style');
  style.id = 'ionetiq-doc-patch';
  style.textContent = `
    #secondaryToolbarToggle,
    #printButton, #secondaryPrintButton,
    #downloadButton, #secondaryDownloadButton,
    #editorFreeTextButton, #editorInkButton, #editorStampButton, #editorHighlightButton,
    #rotateCcwButton, #rotateCwButton,
    #openFileButton, #viewBookmarkButton, #documentPropertiesButton, #presentationModeButton,
    .verticalToolbarSeparator, .splitToolbarButtonSeparator, #editorModeSeparator {
      display: none !important;
    }`;
  doc.head.appendChild(style);
}
```

**Visible:** Thumbnails panel, page navigation, zoom controls, search.  
**Hidden:** Print, download, annotation editors, overflow menu, rotate, separators.

## Flash prevention

The iframe is set to `visibility: hidden` before `src` is assigned. After `load` fires and styles are injected, `visibility` is restored after 150ms:

```js
frame.style.visibility = 'hidden';
frame.onload = () => {
  injectPdfStyles(frame);
  setTimeout(() => { frame.style.visibility = ''; }, 150);
};
frame.src = `${PDF_VIEWER_URL}?file=${encodeURIComponent(blobUrl)}#${hash}`;
```
