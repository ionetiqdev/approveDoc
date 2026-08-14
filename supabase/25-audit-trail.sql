-- ============================================================================
-- approveDoc — Audit Trail
-- Migration: 25-audit-trail.sql
-- Run on DEV first, then production when ready to promote
-- ============================================================================

-- ── 1. Table ─────────────────────────────────────────────────────────────────

create table public.audit_log (
  id           uuid        primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  user_id      uuid,
  action       text        not null,   -- INSERT | UPDATE | DELETE | CUSTOM
  table_name   text        not null,
  record_id    text        not null,
  old_values   jsonb,
  new_values   jsonb,
  comment      text
);

create index audit_log_created_at  on public.audit_log (created_at desc);
create index audit_log_table       on public.audit_log (table_name, record_id);
create index audit_log_user        on public.audit_log (user_id);

-- RLS — re-enable once app users have profiles in this project
-- alter table public.audit_log enable row level security;
-- create policy "Admins: read audit log"
--   on public.audit_log for select
--   using (_my_role() in ('admin', 'super_admin'));

-- ── 2. Trigger function ───────────────────────────────────────────────────────

create function public.audit_trigger_fn()
returns trigger language plpgsql security definer as $$
declare
  v_row    jsonb;
  v_old    jsonb;
  v_new    jsonb;
  v_record text;
begin
  if TG_OP = 'INSERT' then
    v_new := to_jsonb(NEW); v_old := null; v_row := v_new;
  elsif TG_OP = 'UPDATE' then
    v_old := to_jsonb(OLD); v_new := to_jsonb(NEW); v_row := v_new;
  else
    v_old := to_jsonb(OLD); v_new := null; v_row := v_old;
  end if;

  -- Extract PK — strips 'ad_' prefix to find e.g. location_id from ad_location
  v_record := coalesce(
    v_row ->> (substring(TG_TABLE_NAME from 4) || '_id'),
    v_row ->> 'id',
    '(unknown)'
  );

  insert into public.audit_log (user_id, action, table_name, record_id, old_values, new_values)
  values (auth.uid(), TG_OP, TG_TABLE_NAME, v_record, v_old, v_new);

  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end;
$$;

-- ── 3. Install triggers ───────────────────────────────────────────────────────

create trigger audit_ad_location          after insert or update or delete on public.ad_location          for each row execute function public.audit_trigger_fn();
create trigger audit_ad_department        after insert or update or delete on public.ad_department        for each row execute function public.audit_trigger_fn();
create trigger audit_ad_category          after insert or update or delete on public.ad_category          for each row execute function public.audit_trigger_fn();
create trigger audit_ad_job_role          after insert or update or delete on public.ad_job_role          for each row execute function public.audit_trigger_fn();
create trigger audit_ad_document          after insert or update or delete on public.ad_document          for each row execute function public.audit_trigger_fn();
create trigger audit_ad_document_file     after insert or update or delete on public.ad_document_file     for each row execute function public.audit_trigger_fn();
create trigger audit_ad_audience          after insert or update or delete on public.ad_audience          for each row execute function public.audit_trigger_fn();
create trigger audit_ad_audience_member   after insert or update or delete on public.ad_audience_member   for each row execute function public.audit_trigger_fn();
create trigger audit_ad_audience_criteria after insert or update or delete on public.ad_audience_criteria for each row execute function public.audit_trigger_fn();
create trigger audit_ad_distribution      after insert or update or delete on public.ad_distribution      for each row execute function public.audit_trigger_fn();
create trigger audit_ad_distribution_audience after insert or update or delete on public.ad_distribution_audience for each row execute function public.audit_trigger_fn();
create trigger audit_ad_distribution_item after insert or update or delete on public.ad_distribution_item for each row execute function public.audit_trigger_fn();
create trigger audit_ad_document_reference after insert or update or delete on public.ad_document_reference for each row execute function public.audit_trigger_fn();
create trigger audit_ad_user              after insert or update or delete on public.ad_user              for each row execute function public.audit_trigger_fn();
create trigger audit_profiles             after insert or update or delete on public.profiles             for each row execute function public.audit_trigger_fn();
create trigger audit_organisations        after insert or update or delete on public.organisations        for each row execute function public.audit_trigger_fn();
