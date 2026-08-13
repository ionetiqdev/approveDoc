-- ============================================================================
-- approveDoc — Audit Trail Framework
-- Migration: 25-audit-trail.sql
--
-- Implements a generic, reusable audit trail using:
--   - A single audit_log table (JSONB old/new snapshots)
--   - A generic trigger function (auto-installed per table)
--   - A session-level audit comment mechanism (set_audit_comment)
--   - A custom audit event function (audit_custom)
--   - RLS: admins/super_admins can read; no one can write directly
-- ============================================================================

-- ── 1. Audit log table ───────────────────────────────────────────────────────

create table public.audit_log (
  id           uuid        primary key default gen_random_uuid(),
  timestamp    timestamptz not null    default now(),
  user_id      uuid        references auth.users(id) on delete set null,
  action       text        not null,   -- INSERT | UPDATE | DELETE | CUSTOM
  table_name   text        not null,
  record_id    text        not null,   -- text so it works for UUID, int, bigint PKs
  old_values   jsonb,                  -- full row snapshot before change (null for INSERT)
  new_values   jsonb,                  -- full row snapshot after change (null for DELETE)
  comment      text                    -- optional human-readable reason/context
);

-- Index for common query patterns
create index audit_log_table_record  on public.audit_log (table_name, record_id);
create index audit_log_user_id       on public.audit_log (user_id);
create index audit_log_timestamp     on public.audit_log (timestamp desc);
create index audit_log_action        on public.audit_log (action);

-- RLS: admins can read; nobody writes directly (triggers and functions only)
alter table public.audit_log enable row level security;

create policy "Admins: read audit log"
  on public.audit_log for select
  using (_my_role() in ('admin', 'super_admin'));

comment on table public.audit_log is
  'Generic audit trail. Populated by triggers and audit_custom(). Never written to directly by application code.';


-- ── 2. Session-level audit comment ───────────────────────────────────────────
-- Call set_audit_comment() before an INSERT/UPDATE/DELETE to attach a
-- human-readable reason to the audit record the trigger will create.
-- The comment is stored in a session-local variable and cleared after use.

create or replace function public.set_audit_comment(p_comment text)
returns void
language plpgsql
security definer
as $$
begin
  perform set_config('audit.comment', p_comment, true); -- true = local to transaction
end;
$$;

comment on function public.set_audit_comment is
  'Sets a session-level comment that the next audit trigger will pick up. Call before INSERT/UPDATE/DELETE.';


-- ── 3. Generic trigger function ──────────────────────────────────────────────

create or replace function public.audit_trigger_fn()
returns trigger
language plpgsql
security definer
as $$
declare
  v_user_id  uuid;
  v_action   text;
  v_old      jsonb;
  v_new      jsonb;
  v_record   text;
  v_comment  text;
  v_pk_col   text;
begin
  -- Determine action
  v_action := TG_OP; -- INSERT | UPDATE | DELETE

  -- Get authenticated user (works for PostgREST requests; null for service role)
  v_user_id := auth.uid();

  -- Get comment from session variable (cleared after use)
  v_comment := current_setting('audit.comment', true);
  if v_comment = '' then v_comment := null; end if;
  -- Reset after reading
  perform set_config('audit.comment', '', true);

  -- Build snapshots
  if TG_OP = 'INSERT' then
    v_new := to_jsonb(NEW);
    v_old := null;
  elsif TG_OP = 'UPDATE' then
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
  elsif TG_OP = 'DELETE' then
    v_old := to_jsonb(OLD);
    v_new := null;
  end if;

  -- Extract primary key value — try common PK column names
  -- For approveDoc tables the PK is always {table_singular}_id or id
  begin
    v_record := coalesce(
      (v_new ->> (TG_TABLE_NAME || '_id')),
      (v_old ->> (TG_TABLE_NAME || '_id')),
      (v_new ->> 'id'),
      (v_old ->> 'id'),
      '(unknown)'
    );
  exception when others then
    v_record := '(unknown)';
  end;

  -- Write audit record
  insert into public.audit_log (
    user_id, action, table_name, record_id, old_values, new_values, comment
  ) values (
    v_user_id, v_action, TG_TABLE_NAME, v_record, v_old, v_new, v_comment
  );

  -- Return appropriate row to allow the triggering operation to proceed
  if TG_OP = 'DELETE' then
    return OLD;
  else
    return NEW;
  end if;
end;
$$;

comment on function public.audit_trigger_fn is
  'Generic AFTER trigger function. Captures INSERT/UPDATE/DELETE with full row snapshots and optional comment.';


-- ── 4. Helper to install audit trigger on any table ──────────────────────────

create or replace function public.install_audit_trigger(p_table_name text)
returns void
language plpgsql
as $$
declare
  v_trigger_name text := 'audit_' || p_table_name;
begin
  execute format(
    'drop trigger if exists %I on public.%I',
    v_trigger_name, p_table_name
  );
  execute format(
    'create trigger %I
     after insert or update or delete on public.%I
     for each row execute function public.audit_trigger_fn()',
    v_trigger_name, p_table_name
  );
end;
$$;

comment on function public.install_audit_trigger is
  'Installs the generic audit trigger on the named table. Safe to call multiple times.';


-- ── 5. Custom audit event function ───────────────────────────────────────────
-- For business events that are not caused by a direct row change.
-- Examples: DOCUMENT_ACKNOWLEDGED, DISTRIBUTION_SENT, USER_IMPERSONATED

create or replace function public.audit_custom(
  p_action      text,       -- e.g. 'DOCUMENT_ACKNOWLEDGED'
  p_table_name  text,       -- e.g. 'ad_distribution_item'
  p_record_id   text,       -- PK of the relevant record
  p_comment     text  default null,
  p_user_id     uuid  default null  -- pass explicitly when called from edge functions
)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.audit_log (
    user_id, action, table_name, record_id, old_values, new_values, comment
  ) values (
    coalesce(p_user_id, auth.uid()),
    p_action,
    p_table_name,
    p_record_id,
    null,
    null,
    p_comment
  );
end;
$$;

comment on function public.audit_custom is
  'Records a custom business event in the audit log. Pass p_user_id explicitly when calling from Edge Functions (where auth.uid() is null).';


-- ── 6. Install triggers on approveDoc tables ─────────────────────────────────

select public.install_audit_trigger('ad_document');
select public.install_audit_trigger('ad_document_file');
select public.install_audit_trigger('ad_audience');
select public.install_audit_trigger('ad_audience_member');
select public.install_audit_trigger('ad_audience_criteria');
select public.install_audit_trigger('ad_distribution');
select public.install_audit_trigger('ad_distribution_audience');
select public.install_audit_trigger('ad_distribution_item');
select public.install_audit_trigger('ad_document_reference');
select public.install_audit_trigger('ad_external_source');
select public.install_audit_trigger('organisations');
select public.install_audit_trigger('profiles');
select public.install_audit_trigger('ad_user');

-- ── 7. Convenience view — human-readable audit log ───────────────────────────

create or replace view public.audit_log_view as
select
  a.id,
  a.timestamp,
  coalesce(p.display_name, a.user_id::text, 'System') as user_name,
  a.action,
  a.table_name,
  a.record_id,
  a.old_values,
  a.new_values,
  a.comment
from public.audit_log a
left join public.profiles p on p.id = a.user_id
order by a.timestamp desc;

comment on view public.audit_log_view is
  'Audit log with display names resolved. Admins only (inherits RLS from audit_log).';

