# RLS Patterns

All approveDoc tables use Supabase Row Level Security (RLS) to enforce organisation-scoped data access.

## Helper functions

Defined in `01-core-schema.sql`:

```sql
-- Returns the organisation_id of the authenticated user
create function _my_organisation_id() returns uuid as $$
  select organisation_id from profiles where id = auth.uid()
$$ language sql security definer stable;

-- Returns the role of the authenticated user
create function _my_role() returns text as $$
  select role from profiles where id = auth.uid()
$$ language sql security definer stable;
```

## Standard pattern

```sql
-- Enable RLS
alter table public.ad_foo enable row level security;

-- Organisation-scoped access
create policy "Organisation scope"
  on public.ad_foo for all
  using (organisation_id = _my_organisation_id());

-- Super admin bypass
create policy "Super admins: full access"
  on public.ad_foo for all
  using (_my_role() = 'super_admin');
```

## Lookup table pattern

Reference tables like `ad_country` and `ad_language` are readable by any authenticated user, writable only by admins:

```sql
create policy "Authenticated users: read"
  on public.ad_country for select
  using (auth.role() = 'authenticated');

create policy "Admins: manage"
  on public.ad_country for all
  using (_my_role() in ('admin', 'super_admin'));
```

## profiles table

The `profiles` table has a special policy to allow any user to read their own row, bypassing the organisation-scoped policy (super admins have `organisation_id = null`):

```sql
create policy "Users: view own profile"
  on public.profiles for select
  using (auth.uid() = id);
```

!!! warning "Circular dependency"
    `_my_role()` and `_my_organisation_id()` both query `profiles`. This creates a circular dependency if `profiles` RLS doesn't allow `auth.uid() = id`. The `"Users: view own profile"` policy is critical — without it, `_my_role()` cannot read the role to check if the user is a super_admin, and `_my_organisation_id()` cannot determine their org.
