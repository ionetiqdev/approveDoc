-- ============================================================================
-- approveDoc -- build_distribution_items(distribution_id uuid)
--
-- Called after a distribution is created (or when its audiences/settings
-- change). Finds all unique users across all audiences linked to the
-- distribution, then creates one ad_distribution_item row per user with:
--
--   start_date / due_date  - copied from the distribution
--   warning1               - due_date minus/plus first_warning_days
--                            depending on first_warning_direction
--                            ('B' = before = subtract, 'A' = after = add)
--   warning2               - same logic for second warning
--   status                 - 'PENDING'
--
-- Existing items for users already in the distribution are left untouched
-- (ON CONFLICT DO NOTHING), so it's safe to call again if audiences change -
-- new users get rows, existing ones keep their current state.
--
-- Returns the number of NEW rows inserted.
-- ============================================================================

create or replace function public.build_distribution_items(p_distribution_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_dist          public.ad_distribution%rowtype;
  v_warning1      date;
  v_warning2      date;
  v_rows_inserted integer := 0;
begin
  -- Load the distribution row
  select * into v_dist
  from public.ad_distribution
  where distribution_id = p_distribution_id;

  if not found then
    raise exception 'Distribution % not found', p_distribution_id;
  end if;

  -- Compute warning dates
  -- Direction 'B' (before due date): due_date - N days
  -- Direction 'A' (after due date):  due_date + N days
  -- If due_date or days/direction are null, warning stays null.
  if v_dist.due_date is not null and v_dist.first_warning_days is not null and v_dist.first_warning_direction is not null then
    v_warning1 := case v_dist.first_warning_direction
      when 'B' then v_dist.due_date - v_dist.first_warning_days
      when 'A' then v_dist.due_date + v_dist.first_warning_days
      else null
    end;
  end if;

  if v_dist.due_date is not null and v_dist.second_warning_days is not null and v_dist.second_warning_direction is not null then
    v_warning2 := case v_dist.second_warning_direction
      when 'B' then v_dist.due_date - v_dist.second_warning_days
      when 'A' then v_dist.due_date + v_dist.second_warning_days
      else null
    end;
  end if;

  -- Insert one item per unique user across all audiences linked to this
  -- distribution. DISTINCT ensures a user appearing in multiple audiences
  -- only gets one row. ON CONFLICT DO NOTHING makes this idempotent.
  with target_users as (
    select distinct am.user_id
    from public.ad_distribution_audience da
    join public.ad_audience_member am
      on am.audience_id = da.audience_id
     and am.organisation_id = da.organisation_id
    where da.distribution_id = p_distribution_id
  )
  insert into public.ad_distribution_item (
    organisation_id,
    distribution_id,
    user_id,
    start_date,
    due_date,
    warning1,
    warning2,
    acknowledged,
    rejected,
    status
  )
  select
    v_dist.organisation_id,
    p_distribution_id,
    tu.user_id,
    v_dist.start_date,
    v_dist.due_date,
    v_warning1,
    v_warning2,
    false,
    false,
    'PENDING'
  from target_users tu
  on conflict (distribution_id, user_id) do nothing;

  get diagnostics v_rows_inserted = row_count;
  return v_rows_inserted;
end;
$$;

comment on function public.build_distribution_items(uuid) is
  'Creates ad_distribution_item rows for all users in all audiences linked to a distribution. Computes warning dates from the distribution''s warning settings. Safe to call multiple times - existing items are not overwritten.';
