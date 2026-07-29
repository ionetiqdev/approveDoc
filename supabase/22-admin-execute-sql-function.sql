-- 22-admin-execute-sql-function.sql
-- Backs the "Query" admin page (pages/testing/query.html).
--
-- SECURITY NOTES:
--   1. Both functions are SECURITY DEFINER, restricted to the super admin
--      UID (e11f7567-fe8c-4916-8c1e-1f5e0c054988). Update if that account
--      is ever rotated.
--   2. Split into two functions deliberately:
--        admin_execute_sql()   - runs the guarded query, read-only
--        admin_log_sql_call()  - writes the audit log entry
--      This isn't stylistic -- it works around two real Postgres
--      restrictions that a single combined function hits:
--        - transaction_read_only cannot be un-set once any query has
--          run in the same transaction, so a function that sets it on
--          can't later write its own audit log in the same call.
--        - SET ROLE cannot be used inside a SECURITY DEFINER function
--          at all, so switching to a restricted role mid-function isn't
--          an option either.
--      Two separate RPC calls means two separate transactions, so
--      neither restriction applies. The client (query.html) calls
--      admin_execute_sql() first, then always calls admin_log_sql_call()
--      afterwards regardless of outcome.
--   3. Recommend dev/staging only.
--   4. Verified against a local Postgres 16 instance: valid SELECT and
--      WITH...SELECT queries succeed and are logged; a write smuggled
--      inside a CTE is blocked with zero data change; non-super-admin
--      callers are refused.

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

  -- Real enforcement: read-only for the rest of THIS transaction. This
  -- function never writes anything itself (logging is a separate call in
  -- a separate transaction, see admin_log_sql_call below), so we never
  -- need to turn this back off.
  set local transaction_read_only = on;

  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (%s) t',
    trimmed_no_semi
  ) into result;

  return result;
end;
$$;

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
