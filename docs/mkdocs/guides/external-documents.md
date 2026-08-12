# External Documents

approveDoc supports documents stored outside Supabase storage.

## Supported sources

| Source | Status |
|---|---|
| Supabase storage bucket | ✅ Default |
| Google Drive (public share link) | ✅ Available |
| Direct URL (any public PDF) | ✅ Available |
| REST API with authentication | ✅ Available |
| SharePoint / OneDrive | 🔜 Planned |
| Hyland OnBase | 🔜 Planned |

## Adding an external document

In the **New Document** modal, select the source type:

=== "Google Drive"
    Paste the Google Drive sharing URL:
    ```
    https://drive.google.com/file/d/FILE_ID/view?usp=sharing
    ```
    approveDoc automatically converts this to the direct download URL:
    ```
    https://drive.google.com/uc?export=download&id=FILE_ID
    ```

    The file must be shared with **"Anyone with the link can view"**.

=== "Direct URL"
    Paste any publicly accessible PDF URL. No authentication.

=== "REST API"
    Enter the API endpoint URL and select the authentication type:

    - **None** — no authentication
    - **Bearer token** — `Authorization: Bearer {token}`
    - **API key** — configurable header name + key
    - **Basic** — username + password

## How external documents are fetched

External documents are never fetched directly by the browser. Instead, a `POST` request is sent to the `fetch-document` Edge Function with the user's JWT and the `file_id`:

```js
const resp = await fetch(`${SUPABASE_URL}/functions/v1/fetch-document`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + token,
    'apikey': SUPABASE_ANON_KEY,
  },
  body: JSON.stringify({ file_id: pdfFile.id }),
});
```

The edge function verifies the caller's access, fetches the document server-side, and streams the PDF back. Credentials never leave the server. See [fetch-document](../edge-functions/fetch-document.md).

## Loading indicator

While the edge function fetches an external document, the viewer area shows a spinner and "Fetching document…" message. For large files or slow external systems this may take several seconds.
