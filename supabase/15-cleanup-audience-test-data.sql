-- ============================================================================
-- approveDoc -- cleanup script for Audiences Advanced test data
--
-- Removes the 50 fake test users (and their auth rows) created to test
-- the criteria builder, plus the test locations/departments seeded
-- alongside them. Everything is scoped to the @testdata.invalid email
-- marker, so this can never touch real users.
--
-- Run this whenever you're done testing - it's safe to run multiple
-- times (each block only deletes what matches, so re-running after
-- the data's already gone is a no-op).
--
-- Order matters: child rows (ad_audience_member referencing these
-- users) must go before ad_user itself, and ad_user must go before
-- the auth.* rows underneath it, since ad_user.user_id has a foreign
-- key into auth.users.
-- ============================================================================

-- 1. Remove any audience memberships referencing the test users
--    (criteria-built audiences will simply show fewer/no matches on
--    next confirm; this doesn't touch the audiences themselves).
delete from public.ad_audience_member
where user_id in (select user_id from public.ad_user where email like '%@testdata.invalid');

-- 2. Remove the test ad_user rows.
delete from public.ad_user
where email like '%@testdata.invalid';

-- 3. Remove the underlying auth layer - identities first, then the
--    auth.users row itself (auth.identities has its own FK into
--    auth.users, same ordering reason as above).
delete from auth.identities
where identity_data->>'email' like '%@testdata.invalid';

delete from auth.users
where email like '%@testdata.invalid';

-- 4. Remove the test locations and departments seeded alongside the
--    test users. Only drops these specific seeded rows by name - if
--    you've since added a real "Sales" department or "London"
--    location of your own, check this section before running it, or
--    just skip this block and keep the lookups (harmless either way
--    since nothing else still references them once step 1-2 ran).
delete from public.ad_location
where organisation_id = '0b116913-5b27-4c19-8eb9-bf5c4787e780'
  and name in ('London', 'Manchester', 'Paris', 'Dublin', 'New York');

delete from public.ad_department
where organisation_id = '0b116913-5b27-4c19-8eb9-bf5c4787e780'
  and name in ('Sales', 'Engineering', 'Finance', 'HR', 'Marketing');

-- Verify everything's gone:
-- select count(*) from public.ad_user where email like '%@testdata.invalid';
-- select count(*) from auth.users where email like '%@testdata.invalid';
