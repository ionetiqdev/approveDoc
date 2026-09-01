// send-notification-direct
//
// In-house notification sender - calls Slack, Resend (email) and ClickSend
// (SMS) directly. Originally built as a prototype alternative to a Make.com
// webhook scenario; now the primary sending mechanism, called by
// send-due-notifications for every due notification (see that function and
// 28-notification-sending.sql). The Make scenario and its test page still
// exist and are untouched, kept in the background in case needed again.
//
// Required secrets (Dashboard -> Edge Functions -> Manage secrets):
//   SLACK_BOT_TOKEN     - xoxb-... bot token, scopes: chat:write, users:read,
//                         users:read.email
//   CLICKSEND_USERNAME  - ClickSend account username
//   CLICKSEND_API_KEY   - ClickSend API key
//   RESEND_API_KEY      - Resend API key
//   RESEND_FROM_EMAIL   - verified Resend sender, e.g.
//                         "approveDoc <notifications@yourdomain.com>"
//
// Payload:
//   { type: "SLACK"|"EMAIL"|"SMS", firstname, lastname, email, phone,
//     slack_id, message_title, message_text }
// Response: { success, status: "success"|"failure"|"error", message?/error? }

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function substituteTokens(text: string, firstname: string, lastname: string) {
  return (text || '').replaceAll('{firstname}', firstname || '').replaceAll('{lastname}', lastname || '')
}

// <br> -> newline, <b>/<strong> -> Slack *bold*
function htmlToSlack(text: string) {
  return text
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(b|strong)>/gi, '*')
    .replace(/<(b|strong)>/gi, '*')
}

// <br> -> newline, <b>/<strong> stripped (no SMS equivalent)
function htmlToPlain(text: string) {
  return text
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/?(b|strong)>/gi, '')
}

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  let payload: Record<string, string>
  try {
    payload = await req.json()
  } catch {
    return respond(400, { success: false, status: 'error', error: 'Invalid JSON body' })
  }

  const {
    type,
    firstname = '',
    lastname = '',
    email,
    phone,
    slack_id,
    message_title = '',
    message_text = '',
  } = payload

  try {
    // ---------------- SLACK ----------------
    if (type === 'SLACK') {
      const token = Deno.env.get('SLACK_BOT_TOKEN')
      if (!token) {
        return respond(500, { success: false, status: 'error', error: 'SLACK_BOT_TOKEN is not configured' })
      }

      let targetUser: string

      if (slack_id) {
        const r = await fetch(`https://slack.com/api/users.info?user=${encodeURIComponent(slack_id)}`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        const j = await r.json()
        if (!j.ok) {
          return respond(404, { success: false, status: 'failure', error: 'slack_id is not a valid Slack user' })
        }
        targetUser = slack_id
      } else {
        if (!email) {
          return respond(400, { success: false, status: 'failure', error: 'email is required when slack_id is not provided' })
        }
        const r = await fetch(`https://slack.com/api/users.lookupByEmail?email=${encodeURIComponent(email)}`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        const j = await r.json()
        if (!j.ok) {
          return respond(404, { success: false, status: 'failure', error: `No Slack user found for that email: ${j.error}` })
        }
        targetUser = j.user.id
      }

      const body = htmlToSlack(substituteTokens(message_text, firstname, lastname))
      const text = `*${message_title}*\n${body}`

      const sendRes = await fetch('https://slack.com/api/chat.postMessage', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify({ channel: targetUser, text, mrkdwn: true }),
      })
      const sendJson = await sendRes.json()
      if (!sendJson.ok) {
        return respond(500, { success: false, status: 'error', error: `Failed to send Slack message: ${sendJson.error}` })
      }

      return respond(200, { success: true, status: 'success', message: 'Notification sent' })
    }

    // ---------------- EMAIL (Resend) ----------------
    if (type === 'EMAIL') {
      const apiKey = Deno.env.get('RESEND_API_KEY')
      const from = Deno.env.get('RESEND_FROM_EMAIL')
      if (!apiKey || !from) {
        return respond(500, { success: false, status: 'error', error: 'RESEND_API_KEY / RESEND_FROM_EMAIL is not configured' })
      }
      if (!email) {
        return respond(400, { success: false, status: 'failure', error: 'email is required' })
      }

      const html = substituteTokens(message_text, firstname, lastname)

      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from, to: [email], subject: message_title, html }),
      })
      if (!r.ok) {
        return respond(500, { success: false, status: 'error', error: 'Failed to send email' })
      }

      return respond(200, { success: true, status: 'success', message: 'Notification sent' })
    }

    // ---------------- SMS (ClickSend) ----------------
    if (type === 'SMS') {
      const username = Deno.env.get('CLICKSEND_USERNAME')
      const apiKey = Deno.env.get('CLICKSEND_API_KEY')
      if (!username || !apiKey) {
        return respond(500, { success: false, status: 'error', error: 'CLICKSEND_USERNAME / CLICKSEND_API_KEY is not configured' })
      }
      if (!phone) {
        return respond(400, { success: false, status: 'failure', error: 'phone is required' })
      }

      const body = htmlToPlain(substituteTokens(message_text, firstname, lastname))
      const auth = btoa(`${username}:${apiKey}`)

      const r = await fetch('https://rest.clicksend.com/v3/sms/send', {
        method: 'POST',
        headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: [{ source: 'approveDoc', body, to: `+${phone}` }] }),
      })
      const j = await r.json()
      const smsStatus = j?.data?.messages?.[0]?.status
      if (!r.ok || smsStatus !== 'SUCCESS') {
        return respond(500, { success: false, status: 'error', error: `Failed to send SMS: ${JSON.stringify(j)}` })
      }

      return respond(200, { success: true, status: 'success', message: 'Notification sent' })
    }

    return respond(400, { success: false, status: 'failure', error: `Unsupported type: ${type}` })
  } catch (err) {
    return respond(500, { success: false, status: 'error', error: err.message })
  }
})
