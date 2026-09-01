import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Runs nightly via pg_cron (see 28-notification-sending.sql). Finds every
// ad_distribution_item_notification that is PENDING and due (scheduled_date
// <= today), and sends each one via send-notification-direct (Slack/Resend/
// ClickSend, called directly - no Make.com involved). Also callable on
// demand for a single notification (see p_item_notification_id below).
//
// The Make.com webhook path this used previously has been retired from
// this function in favour of the direct approach, per the architecture
// decision - the Make scenario and its test page are untouched and still
// exist if ever needed again, they're just not called from here anymore.
//
// WHATSAPP/OTHER channels aren't implemented in send-notification-direct
// yet, so those are left PENDING (not silently marked FAILED) until that
// support is added.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CHANNEL_TO_TYPE: Record<string, string> = {
  EMAIL: 'EMAIL',
  SMS: 'SMS',
  SLACK: 'SLACK',
}

function buildMessage(direction: string, days: number, distributionName: string, documentName: string | null, dueDate: string) {
  const docLabel = documentName || distributionName
  const title = direction === 'A' ? `Overdue: ${docLabel}` : `Reminder: ${docLabel}`
  const text = direction === 'A'
    ? `Hi {firstname}, "${docLabel}" was due for acknowledgement on ${dueDate} and is now overdue. Please log in to approveDoc to acknowledge it as soon as possible.`
    : `Hi {firstname}, this is a reminder that "${docLabel}" is due for acknowledgement on ${dueDate} (in ${days} day${days === 1 ? '' : 's'}). Please log in to approveDoc to review and acknowledge it.`
  return { title, text }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey  = Deno.env.get('PROJECT_SERVICE_ROLE_KEY')!
    const adminClient = createClient(supabaseUrl, serviceKey)

    let onlyId: string | null = null
    try {
      const body = await req.json()
      onlyId = body?.p_item_notification_id || null
    } catch { /* no body / not JSON - normal for the cron call */ }

    let query = adminClient
      .from('ad_distribution_item_notification')
      .select(`
        item_notification_id, distrib_item_id, recipient_user_id,
        ad_distribution_notification!inner ( channel, days, direction, distribution_id ),
        ad_distribution_item!inner (
          distribution_id,
          ad_distribution!inner ( name, due_date, doc_id,
            ad_document ( name )
          )
        ),
        ad_user!ad_distribution_item_notification_recipient_user_id_fkey ( first_name, last_name, email, mobile_cc, mobile_number )
      `)
      .eq('status', 'PENDING')

    if (onlyId) {
      query = query.eq('item_notification_id', onlyId)
    } else {
      query = query.lte('scheduled_date', new Date().toISOString().slice(0, 10))
    }

    const { data: due, error: queryErr } = await query
    if (queryErr) throw queryErr

    let sent = 0, failed = 0, skipped = 0

    for (const row of due || []) {
      const notif = row.ad_distribution_notification
      const item = row.ad_distribution_item
      const dist = item?.ad_distribution
      const doc = dist?.ad_document
      const user = row.ad_user

      const type = CHANNEL_TO_TYPE[notif?.channel]
      if (!type) {
        // WHATSAPP/OTHER - not implemented in send-notification-direct yet.
        // Leave PENDING rather than marking FAILED for something that was
        // never attempted.
        skipped++
        continue
      }

      const { title, text } = buildMessage(notif.direction, notif.days, dist?.name, doc?.name || null, dist?.due_date)

      const payload = {
        type,
        firstname: user?.first_name || '',
        lastname:  user?.last_name || '',
        email:     user?.email || undefined,
        phone:     user?.mobile_number ? `${user?.mobile_cc || ''}${user.mobile_number}` : undefined,
        slack_id:  null, // no slack_id column on ad_user yet - falls back to email lookup
        message_title: title,
        message_text:  text,
      }

      try {
        const res = await fetch(`${supabaseUrl}/functions/v1/send-notification-direct`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${serviceKey}`,
            'apikey': serviceKey,
          },
          body: JSON.stringify(payload),
        })
        const result = await res.json()

        if (result?.success) {
          await adminClient.from('ad_distribution_item_notification')
            .update({ status: 'SENT', sent_at: new Date().toISOString() })
            .eq('item_notification_id', row.item_notification_id)
          if (dist) {
            await adminClient.rpc('increment_notifications_sent', { p_distribution_id: item.distribution_id })
          }
          sent++
        } else {
          await adminClient.from('ad_distribution_item_notification')
            .update({ status: 'FAILED' })
            .eq('item_notification_id', row.item_notification_id)
          failed++
        }
      } catch {
        await adminClient.from('ad_distribution_item_notification')
          .update({ status: 'FAILED' })
          .eq('item_notification_id', row.item_notification_id)
        failed++
      }
    }

    return new Response(JSON.stringify({ sent, failed, skipped, total: (due || []).length }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
