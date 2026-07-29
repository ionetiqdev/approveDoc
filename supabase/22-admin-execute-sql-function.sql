-- 22-admin-execute-sql-function.sql
-- Backs the "Query" admin page (pages/testing/query.html).
--
-- SECURITY NOTES:
--   1. Both functions are SECURITY DEFINER, restricted to the super admin
--      UID (e11f7567-fe8c-4916-8c1e-1f5e0c054988). Update if that account
--      is ever rotated.
--   2. Enforcement is via FUNCTION OWNERSHIP, not transaction state or
--      SET ROLE. admin_execute_sql() is owned by a dedicated role,
--      admin_sql_readonly, which is granted ONLY select on all tables --
--      no insert/update/delete/ddl privileges at all. Because the
--      function is SECURITY DEFINER, it always runs as its owner, so any
--      write attempt fails on genuine permission-denied, however it's
--      smuggled in (CTE, or a called function with a write side effect --
--      tested against both).
--   3. Two earlier approaches were tried and both hit real Postgres
--      restrictions, which is why this looks the way it does:
--        - transaction_read_only cannot be set at all once ANY query has
--          run earlier in the same transaction. Supabase/PostgREST always
--          runs its own setup queries (JWT claims, role, etc.) before
--          calling your function, so this failed on the very first call,
--          every time, in production -- even though it worked fine in an
--          isolated psql session with no such preamble.
--        - SET ROLE cannot be used inside a SECURITY DEFINER function at
--          all -- Postgres disallows it outright.
--      Owning the function itself sidesteps both restrictions entirely.
--   4. admin_log_sql_call() is a SEPARATE function, deliberately left
--      owned by whichever role runs this migration (needs write access
--      to admin_sql_log). The client calls admin_execute_sql() first,
--      then always calls admin_log_sql_call() afterwards regardless of
--      outcome -- see pages/testing/query.html.
--   5. Recommend dev/staging only.
--   6. Verified against a local Postgres 16 instance, including: a query
--      preceded by other queries in the same transaction (reproducing
--      PostgREST's preamble); a write smuggled via CTE; a write hidden
--      inside a called function with no write keywords in the visible
--      query text; a legitimate WITH...SELECT; and a non-super-admin
--      caller. All behaved as intended.

drop function if exists admin_execute_sql(text);
drop function if exists admin_log_sql_call(text, boolean, integer, text, integer);

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'admin_sql_readonly') then
    create role admin_sql_readonly nologin bypassrls;
  end if;
end
$$;

grant usage on schema public to admin_sql_readonly;
grant usage on schema auth to admin_sql_readonly;
grant select on all tables in schema public to admin_sql_readonly;
alter default privileges in schema public grant select on tables to admin_sql_readonly;

create or replace function admin_execute_sql(query text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  trimmed text := btrim(query);
  trimmed_no_semi text := regexp_replace(trimmed, ';\s*$', '');
begin
  if auth.uid() is distinct from 'e11f7567-fe8c-4916-8c1e-1f5e0c054988'::uuid then
    raise exception 'admin_execute_sql: not authorised';
  end if;

  if trimmed_no_semi !~* '^\s*(select|with)\y' then
    raise exception 'admin_execute_sql: only SELECT (or WITH ... SELECT) statements are permitted';
  end if;

  if trimmed_no_semi ~ ';' then
    raise exception 'admin_execute_sql: only a single statement is permitted';
  end if;

  if trimmed_no_semi ~* '\y(insert|update|delete|merge|drop|truncate|alter|grant|revoke|create|call|do|vacuum|copy|lock|refresh\s+materialized\s+view)\y' then
    raise exception 'admin_execute_sql: statement type not permitted from this console';
  end if;

  -- Real enforcement: this function is OWNED by admin_sql_readonly (see
  -- ALTER FUNCTION below), which has only SELECT grants -- no INSERT/
  -- UPDATE/DELETE/DDL privileges on anything. SECURITY DEFINER means the
  -- function always runs as its owner, so any write attempt -- however
  -- it's smuggled in -- fails on genuine permission-denied, not on
  -- transaction state (which PostgREST's own preamble queries rule out
  -- anyway) or SET ROLE (which Postgres disallows inside SECURITY
  -- DEFINER functions).
  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (%s) t',
    trimmed_no_semi
  ) into result;

  return result;
end;
$$;

-- This is the actual enforcement mechanism.
alter function admin_execute_sql(text) owner to admin_sql_readonly;

-- admin_log_sql_call stays owned by whoever ran this script (needs write
-- access to admin_sql_log) -- do NOT alter its owner.
create or replace function admin_log_sql_call(
  p_statement text,
  p_succeeded boolean,
  p_row_count integer default null,
  p_error_message text default null,
  p_duration_ms integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is distinct from 'e11f7567-fe8c-4916-8c1e-1f5e0c054988'::uuid then
    raise exception 'admin_log_sql_call: not authorised';
  end if;

  insert into admin_sql_log (executed_by, statement, succeeded, row_count, error_message, duration_ms)
  values (auth.uid(), p_statement, p_succeeded, p_row_count, p_error_message, p_duration_ms);
end;
$$;
