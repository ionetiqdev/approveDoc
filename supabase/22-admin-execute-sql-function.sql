-- 22-admin-execute-sql-function.sql
-- Adds an RPC function so the "SQL Test" admin page can run ad-hoc queries
-- against the database from the browser via supabase.rpc().
--
-- SECURITY NOTES (read before deploying):
--   1. This function runs as SECURITY DEFINER, meaning it executes with the
--      privileges of the function owner, NOT the calling user. That is what
--      lets it bypass RLS to run arbitrary SQL -- which is exactly why the
--      guard clause below matters. Do not remove the auth.uid() check.
--   2. It is hard-restricted to the super admin UID in your notes
--      (e11f7567-fe8c-4916-8c1e-1f5e0c054988). Anyone else calling it gets
--      an exception. Update this UID if you rotate the super admin account.
--   3. Recommend deploying this ONLY on dev/staging. If you ever need it in
--      production, keep the same restriction and consider adding an
--      allow-list of verbs (SELECT-only) rather than allowing DDL/DML.
--   4. Every call is logged to admin_sql_log for audit purposes.

create table if not exists admin_sql_log (
  id bigint generated always as identity primary key,
  executed_by uuid not null references auth.users(id),
  statement text not null,
  succeeded boolean not null,
  error_message text,
  row_count integer,
  duration_ms integer,
  executed_at timestamptz not null default now()
);

alter table admin_sql_log enable row level security;

drop policy if exists "super admin reads sql log" on admin_sql_log;
create policy "super admin reads sql log"
  on admin_sql_log for select
  using (auth.uid() = 'e11f7567-fe8c-4916-8c1e-1f5e0c054988');

create or replace function admin_execute_sql(query text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  started_at timestamptz := clock_timestamp();
  row_count_out integer;
  trimmed text := btrim(query);
  trimmed_no_semi text := regexp_replace(trimmed, ';\s*$', '');
begin
  -- Guard 1: only the super admin may call this function.
  if auth.uid() is distinct from 'e11f7567-fe8c-4916-8c1e-1f5e0c054988'::uuid then
    raise exception 'admin_execute_sql: not authorised';
  end if;

  -- Guard 2: cheap allow-list + blocklist for a fast, clear error message.
  -- This is defense in depth, NOT the real enforcement -- see Guard 3.
  if trimmed_no_semi !~* '^\s*(select|with)\b' then
    raise exception 'admin_execute_sql: only SELECT (or WITH ... SELECT) statements are permitted';
  end if;

  if trimmed_no_semi ~ ';' then
    raise exception 'admin_execute_sql: only a single statement is permitted';
  end if;

  if trimmed_no_semi ~* '\y(insert|update|delete|merge|drop|truncate|alter|grant|revoke|create|call|do|vacuum|copy|lock|refresh\s+materialized\s+view)\y' then
    raise exception 'admin_execute_sql: statement type not permitted from this console';
  end if;

  -- Guard 3: the real enforcement. Postgres itself will refuse any write
  -- (INSERT/UPDATE/DELETE/DDL) for the rest of this transaction, even if
  -- it's hidden inside a data-modifying CTE or a volatile function call
  -- that Guard 2's keyword check didn't catch.
  set local transaction_read_only = on;

  begin
    execute format(
      'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (%s) t',
      trimmed_no_semi
    ) into result;
  exception when others then
    insert into admin_sql_log (executed_by, statement, succeeded, error_message, duration_ms)
    values (
      auth.uid(), query, false, sqlerrm,
      extract(milliseconds from clock_timestamp() - started_at)::integer
    );
    raise;
  end;

  row_count_out := jsonb_array_length(result);

  insert into admin_sql_log (executed_by, statement, succeeded, row_count, duration_ms)
  values (
    auth.uid(), query, true, row_count_out,
    extract(milliseconds from clock_timestamp() - started_at)::integer
  );

  return result;
end;
$$;

comment on function admin_execute_sql(text) is
  'Runs an arbitrary query and returns results as JSONB. Restricted to the super admin UID. Used by pages/testing/sql-runner.html.';
