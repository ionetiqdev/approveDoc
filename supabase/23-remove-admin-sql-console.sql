-- 23-remove-admin-sql-console.sql
-- Removes everything added for the "Query" admin SQL console (abandoned).
-- Safe to run even if only some of these objects exist -- everything is
-- IF EXISTS.

drop function if exists admin_execute_sql(text);
drop function if exists admin_execute_sql_restricted(text);
drop function if exists admin_log_sql_call(text, boolean, integer, text, integer);

drop policy if exists "super admin reads sql log" on admin_sql_log;
drop table if exists admin_sql_log;

-- Only drops the role if nothing else still depends on its grants. If
-- this errors with "role ... cannot be dropped because some objects
-- depend on it", something else picked up a grant from it along the
-- way -- run:
--   select relname from pg_class c
--   join pg_shdepend d on d.objid = c.oid
--   where d.refobjid = 'admin_sql_readonly'::regrole;
-- to see what, then revoke it before retrying.
drop role if exists admin_sql_readonly;
