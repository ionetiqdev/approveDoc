-- ============================================================================
-- approveDoc - Notification Sending (Phase 2)
-- Migration: 28-notification-sending.sql
-- Run on DEV first, then production when ready to promote
--
-- Wires up the actual nightly send: a pg_cron job calls the
-- send-due-notifications Edge Function once a day, which finds every
-- ad_distribution_item_notification that is PENDING and due, sends each
-- to a Make.com webhook, and marks it SENT/FAILED.
--
-- SETUP STEPS REQUIRED AFTER RUNNING THIS MIGRATION (not done by this file
-- on purpose - secrets should never live in a git-tracked migration):
--   1. Edge Function secret MAKE_NOTIFICATIONS_WEBHOOK_URL - set via
--      Dashboard -> Edge Functions -> Manage secrets, once the Make.com
--      scenario/webhook exists.
--   2. A Vault secret named 'cron_edge_function_key' holding a service-role
--      key, so the nightly cron job can authenticate its call to the Edge
--      Function. Run once via SQL Editor (never commit the real value):
--        select vault.create_secret('<service-role-key>', 'cron_edge_function_key');
-- ============================================================================

-- ── 1. Increment helper (called by the Edge Function on each successful send) ──

create or replace function public.increment_notifications_sent(p_distribution_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.ad_distribution
  set notifications_sent = notifications_sent + 1
  where distribution_id = p_distribution_id;
end;
$$;

-- ── 2. Extensions needed for cron -> HTTP call ───────────────────────────

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- ── 3. Wrapper function: reads the service key from Vault, calls the ────
--       Edge Function via pg_net. pg_cron calls THIS, not the raw URL/key
--       directly, so no credential ever appears in the cron.job table.

create or replace function public.trigger_send_due_notifications()
returns void language plpgsql security definer as $$
declare
  v_key     text;
  v_project_url text := 'https://mimqaklxfmdjlkadjxoh.supabase.co'; -- dev; update for production promotion
begin
  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'cron_edge_function_key'
  limit 1;

  if v_key is null then
    raise notice 'trigger_send_due_notifications: cron_edge_function_key not set in Vault yet - skipping. See setup steps in 28-notification-sending.sql.';
    return;
  end if;

  perform net.http_post(
    url     := v_project_url || '/functions/v1/send-due-notifications',
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    body    := '{}'::jsonb
  );
end;
$$;

comment on function public.trigger_send_due_notifications() is
  'Called nightly by pg_cron. Invokes the send-due-notifications Edge Function via pg_net, authenticated with a service-role key stored in Vault (name: cron_edge_function_key) so no credential lives in the cron job definition itself.';

-- ── 4. Nightly schedule (06:00 UTC - adjust if a different time is wanted) ──

select cron.unschedule('send-due-notifications-nightly')
where exists (select 1 from cron.job where jobname = 'send-due-notifications-nightly');

select cron.schedule(
  'send-due-notifications-nightly',
  '0 6 * * *',
  $$select public.trigger_send_due_notifications();$$
);
