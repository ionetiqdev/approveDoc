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

    const { file_id } = await req.json()
    if (!file_id) throw new Error('file_id is required')

    const { data: file, error: fileErr } = await adminClient
      .from('ad_document_file')
      .select('*, ad_external_source(source_type,base_url,auth_type,auth_secret_id,auth_username,auth_header_name,extra_headers)')
      .eq('id', file_id)
      .single()

    if (fileErr || !file) throw new Error('Document file not found')

    const { data: profile } = await adminClient
      .from('profiles').select('organisation_id,role').eq('id', user.id).single()

    if (file.organisation_id !== profile?.organisation_id && profile?.role !== 'super_admin')
      throw new Error('Access denied')

    switch (file.source_type) {

      case 'SUPABASE': {
        const { data: signed } = await adminClient.storage
          .from('documents').createSignedUrl(file.storage_path, 60)
        if (!signed?.signedUrl) throw new Error('Could not generate signed URL')
        return Response.redirect(signed.signedUrl, 302)
      }

      case 'URL': {
        const response = await fetch(file.external_url!)
        if (!response.ok) throw new Error(`Upstream returned ${response.status}`)
        return new Response(response.body, {
          headers: { ...corsHeaders, 'Content-Type': 'application/pdf' }
        })
      }

      case 'REST':
      case 'SHAREPOINT':
      case 'ONBASE': {
        const src = file.ad_external_source
        if (!src) throw new Error('No external source configured')

        const headers: Record<string, string> = {
          'Accept': 'application/pdf',
          ...(src.extra_headers || {}),
        }

        if (src.auth_type !== 'NONE' && src.auth_secret_id) {
          const { data: secret } = await adminClient
            .schema('vault').from('decrypted_secrets')
            .select('decrypted_secret').eq('id', src.auth_secret_id).single()
          const credential = secret?.decrypted_secret
          if (!credential) throw new Error('Could not retrieve credentials from vault')

          switch (src.auth_type) {
            case 'BEARER':
              headers[src.auth_header_name || 'Authorization'] = `Bearer ${credential}`; break
            case 'API_KEY':
              headers[src.auth_header_name || 'X-API-Key'] = credential; break
            case 'BASIC':
              headers['Authorization'] = `Basic ${btoa(`${src.auth_username}:${credential}`)}`; break
            case 'OAUTH2':
              headers['Authorization'] = `Bearer ${credential}`; break
          }
        }

        const url = src.base_url
          ? `${src.base_url.replace(/\/$/, '')}/${(file.external_url || file.external_ref || '').replace(/^\//, '')}`
          : (file.external_url || file.external_ref || '')

        const response = await fetch(url, { headers })
        if (!response.ok) throw new Error(`Upstream returned ${response.status}`)

        return new Response(response.body, {
          headers: { ...corsHeaders, 'Content-Type': 'application/pdf' }
        })
      }

      default:
        throw new Error(`Unknown source type: ${file.source_type}`)
    }

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
