import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Unauthorized')

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authErr } = await userClient.auth.getUser()
    if (authErr || !user) throw new Error('Unauthorized')

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('PROJECT_SERVICE_ROLE_KEY')!
    )

    const { storage_path, bucket } = await req.json()
    if (!storage_path) throw new Error('storage_path is required')

    const apiKey = Deno.env.get('CLOUDCONVERT_API_KEY')
    if (!apiKey) throw new Error('CLOUDCONVERT_API_KEY not configured')

    // Get signed URL for the Word file
    const { data: signed } = await adminClient.storage
      .from(bucket || 'documents')
      .createSignedUrl(storage_path, 300)
    if (!signed?.signedUrl) throw new Error('Could not get signed URL for source file')

    // Step 1: Create a CloudConvert job
    const jobRes = await fetch('https://api.cloudconvert.com/v2/jobs', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tasks: {
          'import-file': {
            operation: 'import/url',
            url: signed.signedUrl,
            filename: storage_path.split('/').pop(),
          },
          'convert-file': {
            operation: 'convert',
            input: 'import-file',
            output_format: 'pdf',
            engine: 'libreoffice',
          },
          'export-file': {
            operation: 'export/url',
            input: 'convert-file',
          },
        },
        tag: 'approvedoc-conversion',
      }),
    })

    if (!jobRes.ok) {
      const err = await jobRes.text()
      throw new Error(`CloudConvert job creation failed: ${err}`)
    }

    const job = await jobRes.json()
    const jobId = job.data?.id
    if (!jobId) throw new Error('No job ID returned from CloudConvert')

    // Step 2: Poll for completion (max 60s)
    let pdfUrl: string | null = null
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 2000))
      const statusRes = await fetch(`https://api.cloudconvert.com/v2/jobs/${jobId}`, {
        headers: { 'Authorization': `Bearer ${apiKey}` },
      })
      const status = await statusRes.json()
      const exportTask = status.data?.tasks?.find((t: any) => t.name === 'export-file')

      if (exportTask?.status === 'finished') {
        pdfUrl = exportTask.result?.files?.[0]?.url
        break
      }
      if (status.data?.status === 'error') {
        throw new Error('CloudConvert conversion failed')
      }
    }

    if (!pdfUrl) throw new Error('Conversion timed out')

    // Step 3: Download the PDF and upload to Supabase Storage
    const pdfRes = await fetch(pdfUrl)
    if (!pdfRes.ok) throw new Error('Could not download converted PDF')
    const pdfBuffer = await pdfRes.arrayBuffer()

    const pdfPath = storage_path.replace(/\.[^.]+$/, '.pdf')
    const { error: uploadErr } = await adminClient.storage
      .from(bucket || 'documents')
      .upload(pdfPath, pdfBuffer, {
        contentType: 'application/pdf',
        upsert: true,
      })
    if (uploadErr) throw new Error(`Upload failed: ${uploadErr.message}`)

    return new Response(JSON.stringify({ pdf_path: pdfPath }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
