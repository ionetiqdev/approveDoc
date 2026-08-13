-- ============================================================================
-- approveDoc — Dev project seed data
-- Run this on a fresh Supabase project AFTER running all migrations (01-24)
-- ============================================================================

-- Organisation
INSERT INTO organisations (id, name, created_at) 
VALUES ('0b116913-5b27-4c19-8eb9-bf5c4787e780', 'gardenSOL', '2026-06-27 14:21:41.674144+00')
ON CONFLICT DO NOTHING;

-- Categories
INSERT INTO ad_category (category_id, organisation_id, name) VALUES
  ('49ee0dd3-14e1-4632-8fb2-a61ab68f69af', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Policy'),
  ('01775a74-720d-4017-afdc-f250c9cca3dc', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Procedure'),
  ('1207477e-d4b3-49b8-a837-29279a9a699c', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guidance'),
  ('071428cd-5284-4cc3-917b-c977021aa66e', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Form'),
  ('4ff0c365-f469-4dce-9ff6-7c3b861e9c31', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Other')
ON CONFLICT DO NOTHING;

-- Departments
INSERT INTO ad_department (department_id, organisation_id, name) VALUES
  ('f5924b89-273b-4197-b04e-7e7c5d290884', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sales'),
  ('98b8805c-b95d-499e-9906-2c37aa79b804', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Engineering'),
  ('09dfd755-b2c7-4cb7-a49b-3de7d9bc68ba', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Finance'),
  ('100907ca-3acb-4734-968c-7626437b0c93', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'HR'),
  ('059df2b8-2d33-4778-a234-dc4e841f33b6', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Marketing'),
  ('11c0c2c9-4313-43d8-9589-9ca1b755fe16', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Professional Services')
ON CONFLICT DO NOTHING;

-- Job roles
INSERT INTO ad_job_role (job_role_id, organisation_id, name) VALUES
  ('5958f9c1-8b7d-4cdc-998a-641ca29ae251', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Account Manager'),
  ('3786908b-decf-42a5-babd-25ae5c6204ce', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sales Engineering'),
  ('10038fe1-a163-4779-abf4-c4b36910f6a3', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Consultant')
ON CONFLICT DO NOTHING;

-- Locations
INSERT INTO ad_location (location_id, organisation_id, name) VALUES
  ('3e17feda-6461-439c-8cc7-93f2cd34751a', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'London'),
  ('2f3af1a2-acc2-4209-b501-73ca6e3dc25b', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Manchester'),
  ('db322996-e67d-461d-a301-60e6c5d2534a', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Paris'),
  ('f17d75cd-55b0-4f97-bd47-b25185440dcc', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Dublin'),
  ('b9e1ebbe-96e6-4ab5-a2ac-2703c93612b2', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'New York'),
  ('09fff245-6658-4cc6-8332-671e951b4693', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Remote / Hybrid')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- After running this, invite users via the app (Admin → Users → Invite)
-- Auth users cannot be copied between Supabase projects.
-- ============================================================================
