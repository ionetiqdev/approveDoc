import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Role model (must match RLS policies and auth.js exactly):
//   super_admin - all organisations, ionetiq team only
//   admin       - one organisation, includes admin functionality
//   user        - one organisation, editing capability
//   view        - one organisation, read-only
//
// This function may be called by either super_admin OR admin.
// super_admin: full access, any organisation, any role including
//   super_admin/admin.
// admin: restricted to users within their OWN organisation only, and
//   may only assign role 'user', 'view', or 'admin' - never
//   'super_admin'. An admin can promote another user in their own org
//   to admin (delegation), but can never create a super_admin and can
//   never touch a user in a different organisation.

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No authorization header')

    const anonClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await anonClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const { data: callerProfile } = await anonClient
      .from('profiles')
      .select('role, organisation_id')
      .eq('id', user.id)
      .single()

    const callerRole = callerProfile?.role
    const callerOrgId = callerProfile?.organisation_id

    if (callerRole !== 'super_admin' && callerRole !== 'admin') {
      throw new Error('Insufficient permissions')
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      // NOTE: cannot be named SUPABASE_SERVICE_ROLE_KEY - the Supabase
      // CLI reserves the SUPABASE_ prefix for its own auto-injected
      // variables and refuses `supabase secrets set` on any name
      // starting with it ("Env name cannot start with SUPABASE_,
      // skipping"). This is set manually via the CLI (see
      // docs/NEW-PROJECT.md), so it needs a non-reserved name.
      Deno.env.get('PROJECT_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json()
    const { action } = body

    // Shared guard for create/update_password/delete on an EXISTING user -
    // an org admin may only ever touch a user already in their own org.
    // (Not used for 'create', which has its own organisation-assignment
    // check below, since the target user doesn't exist yet.)
    async function assertCallerCanManage(targetUserId: string) {
      if (callerRole === 'super_admin') return
      const { data: target } = await adminClient
        .from('profiles')
        .select('organisation_id')
        .eq('id', targetUserId)
        .single()
      if (!target || target.organisation_id !== callerOrgId) {
        throw new Error('You can only manage users within your own organisation')
      }
    }

    if (action === 'create') {
      const { email, display_name, role, job_title, redirect_to, organisation_id } = body

      if (callerRole === 'admin') {
        if (role === 'super_admin') throw new Error('Only a super admin can create a super admin')
        if (organisation_id !== callerOrgId) throw new Error('You can only add users to your own organisation')
      }

      const { data, error } = await adminClient.auth.admin.inviteUserByEmail(email, {
        data: { full_name: display_name },
        redirectTo: redirect_to
      })
      if (error) throw error

      await adminClient.from('profiles').upsert({
        id:              data.user.id,
        display_name,
        email,
        role:            role || 'user',
        job_title:       job_title || null,
        organisation_id: role === 'super_admin' ? null : organisation_id,
        updated_at:      new Date().toISOString()
      })

      // Also create ad_user row so the user appears in audience/distribution pickers
      const nameParts = (display_name || '').trim().split(/\s+/)
      const firstName = nameParts[0] || ''
      const lastName  = nameParts.slice(1).join(' ') || ''
      await adminClient.from('ad_user').upsert({
        user_id:         data.user.id,
        email,
        first_name:      firstName,
        last_name:       lastName,
        organisation_id: role === 'super_admin' ? null : organisation_id,
        role_user:       (role || 'user') === 'user',
        role_admin:      role === 'admin',
      }, { onConflict: 'user_id' })

      return new Response(JSON.stringify({ user_id: data.user.id }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'update_password') {
      const { user_id, password } = body
      await assertCallerCanManage(user_id)
      const { error } = await adminClient.auth.admin.updateUserById(user_id, { password })
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'delete') {
      const { user_id } = body
      await assertCallerCanManage(user_id)
      const { error } = await adminClient.auth.admin.deleteUser(user_id)
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    throw new Error('Unknown action: ' + action)

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
