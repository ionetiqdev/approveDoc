-- ============================================================================
-- approveDoc — Data migration from production to dev
-- Run this on the dev project AFTER 00-FULL-SCHEMA.sql
-- Note: auth.users and profiles cannot be copied — invite users via the app
-- Generated: 13/08/2026
-- ============================================================================

-- ── Categories ───────────────────────────────────────────────────────────────
INSERT INTO ad_category (category_id, organisation_id, name) VALUES ('071428cd-5284-4cc3-917b-c977021aa66e','0b116913-5b27-4c19-8eb9-bf5c4787e780','Form') ON CONFLICT DO NOTHING;
INSERT INTO ad_category (category_id, organisation_id, name) VALUES ('1207477e-d4b3-49b8-a837-29279a9a699c','0b116913-5b27-4c19-8eb9-bf5c4787e780','Guidance') ON CONFLICT DO NOTHING;
INSERT INTO ad_category (category_id, organisation_id, name) VALUES ('4ff0c365-f469-4dce-9ff6-7c3b861e9c31','0b116913-5b27-4c19-8eb9-bf5c4787e780','Other') ON CONFLICT DO NOTHING;
INSERT INTO ad_category (category_id, organisation_id, name) VALUES ('49ee0dd3-14e1-4632-8fb2-a61ab68f69af','0b116913-5b27-4c19-8eb9-bf5c4787e780','Policy') ON CONFLICT DO NOTHING;
INSERT INTO ad_category (category_id, organisation_id, name) VALUES ('01775a74-720d-4017-afdc-f250c9cca3dc','0b116913-5b27-4c19-8eb9-bf5c4787e780','Procedure') ON CONFLICT DO NOTHING;

-- ── Departments ───────────────────────────────────────────────────────────────
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('98b8805c-b95d-499e-9906-2c37aa79b804','0b116913-5b27-4c19-8eb9-bf5c4787e780','Engineering') ON CONFLICT DO NOTHING;
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('09dfd755-b2c7-4cb7-a49b-3de7d9bc68ba','0b116913-5b27-4c19-8eb9-bf5c4787e780','Finance') ON CONFLICT DO NOTHING;
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('100907ca-3acb-4734-968c-7626437b0c93','0b116913-5b27-4c19-8eb9-bf5c4787e780','HR') ON CONFLICT DO NOTHING;
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('059df2b8-2d33-4778-a234-dc4e841f33b6','0b116913-5b27-4c19-8eb9-bf5c4787e780','Marketing') ON CONFLICT DO NOTHING;
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('11c0c2c9-4313-43d8-9589-9ca1b755fe16','0b116913-5b27-4c19-8eb9-bf5c4787e780','Professional Services') ON CONFLICT DO NOTHING;
INSERT INTO ad_department (department_id, organisation_id, name) VALUES ('f5924b89-273b-4197-b04e-7e7c5d290884','0b116913-5b27-4c19-8eb9-bf5c4787e780','Sales') ON CONFLICT DO NOTHING;

-- ── Job Roles ────────────────────────────────────────────────────────────────
INSERT INTO ad_job_role (job_role_id, organisation_id, name) VALUES ('5958f9c1-8b7d-4cdc-998a-641ca29ae251','0b116913-5b27-4c19-8eb9-bf5c4787e780','Account Manager') ON CONFLICT DO NOTHING;
INSERT INTO ad_job_role (job_role_id, organisation_id, name) VALUES ('10038fe1-a163-4779-abf4-c4b36910f6a3','0b116913-5b27-4c19-8eb9-bf5c4787e780','Consultant') ON CONFLICT DO NOTHING;
INSERT INTO ad_job_role (job_role_id, organisation_id, name) VALUES ('3786908b-decf-42a5-babd-25ae5c6204ce','0b116913-5b27-4c19-8eb9-bf5c4787e780','Sales Engineering') ON CONFLICT DO NOTHING;

-- ── Locations ────────────────────────────────────────────────────────────────
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('f17d75cd-55b0-4f97-bd47-b25185440dcc','0b116913-5b27-4c19-8eb9-bf5c4787e780','Dublin') ON CONFLICT DO NOTHING;
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('3e17feda-6461-439c-8cc7-93f2cd34751a','0b116913-5b27-4c19-8eb9-bf5c4787e780','London') ON CONFLICT DO NOTHING;
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('2f3af1a2-acc2-4209-b501-73ca6e3dc25b','0b116913-5b27-4c19-8eb9-bf5c4787e780','Manchester') ON CONFLICT DO NOTHING;
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('b9e1ebbe-96e6-4ab5-a2ac-2703c93612b2','0b116913-5b27-4c19-8eb9-bf5c4787e780','New York') ON CONFLICT DO NOTHING;
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('db322996-e67d-461d-a301-60e6c5d2534a','0b116913-5b27-4c19-8eb9-bf5c4787e780','Paris') ON CONFLICT DO NOTHING;
INSERT INTO ad_location (location_id, organisation_id, name) VALUES ('09fff245-6658-4cc6-8332-671e951b4693','0b116913-5b27-4c19-8eb9-bf5c4787e780','Remote / Hybrid') ON CONFLICT DO NOTHING;

-- ── Audiences ────────────────────────────────────────────────────────────────
INSERT INTO ad_audience (audience_id, organisation_id, name, description, is_criteria_built) VALUES ('2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','UK & French Sales team','',true) ON CONFLICT DO NOTHING;
INSERT INTO ad_audience (audience_id, organisation_id, name, description, is_criteria_built) VALUES ('c4084a11-deff-45a5-9f5f-ccd5cf5ac1cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','Demo to Jacob','Blah blah blah',true) ON CONFLICT DO NOTHING;
INSERT INTO ad_audience (audience_id, organisation_id, name, description, is_criteria_built) VALUES ('654a2379-06ea-4e90-b980-28d2516a9139','0b116913-5b27-4c19-8eb9-bf5c4787e780','French & UK Sales','',true) ON CONFLICT DO NOTHING;

-- ── Audience Criteria ────────────────────────────────────────────────────────
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('7705c029-4098-4856-81f9-2b3bf85cbd9e','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','GBR') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('02dd5b64-a8e1-4f98-a8f9-b3976ef07d4a','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','FRA') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('554f758f-b1d1-4573-884c-e99d0b42624e','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','department','f5924b89-273b-4197-b04e-7e7c5d290884') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('45665659-36b4-4afd-835c-6f536d15fe99','c4084a11-deff-45a5-9f5f-ccd5cf5ac1cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','GBR') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('74ebc00c-aa47-4866-ae6c-4d2c0afdd70f','c4084a11-deff-45a5-9f5f-ccd5cf5ac1cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','USA') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('0b5b2c82-4d24-41de-8149-a1a8a2cec787','c4084a11-deff-45a5-9f5f-ccd5cf5ac1cb','0b116913-5b27-4c19-8eb9-bf5c4787e780','department','f5924b89-273b-4197-b04e-7e7c5d290884') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('9732684c-7414-4bb6-b7f3-44201b28f589','654a2379-06ea-4e90-b980-28d2516a9139','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','GBR') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('79456a6f-f154-4b6c-a373-7facf303a256','654a2379-06ea-4e90-b980-28d2516a9139','0b116913-5b27-4c19-8eb9-bf5c4787e780','country','FRA') ON CONFLICT DO NOTHING;
INSERT INTO ad_audience_criteria (criteria_id, audience_id, organisation_id, criteria_type, criteria_value) VALUES ('2eedae2c-5098-4f75-9b37-c9908b1653b5','654a2379-06ea-4e90-b980-28d2516a9139','0b116913-5b27-4c19-8eb9-bf5c4787e780','department','f5924b89-273b-4197-b04e-7e7c5d290884') ON CONFLICT DO NOTHING;

-- ── Documents ────────────────────────────────────────────────────────────────
INSERT INTO ad_document (doc_id, organisation_id, name, description, category_id) VALUES ('dcb67d43-8cd5-4972-ad06-af4552540093','0b116913-5b27-4c19-8eb9-bf5c4787e780','Test doc in Google','','1207477e-d4b3-49b8-a837-29279a9a699c') ON CONFLICT DO NOTHING;
INSERT INTO ad_document (doc_id, organisation_id, name, description, category_id) VALUES ('0ac929aa-dd2c-422b-bb28-a9aeeb012e7b','0b116913-5b27-4c19-8eb9-bf5c4787e780','Large Google Doc','','1207477e-d4b3-49b8-a837-29279a9a699c') ON CONFLICT DO NOTHING;
INSERT INTO ad_document (doc_id, organisation_id, name, description, category_id) VALUES ('4c1591bd-0787-47e6-a96a-562bedf63c61','0b116913-5b27-4c19-8eb9-bf5c4787e780','Costa ECM Executive Summary','','49ee0dd3-14e1-4632-8fb2-a61ab68f69af') ON CONFLICT DO NOTHING;

-- ── Document Files ───────────────────────────────────────────────────────────
INSERT INTO ad_document_file (id, doc_id, organisation_id, file_name, download_file_name, storage_path, mime_type, source_type, external_url, created_at) VALUES ('1df15ce9-8ada-4ef4-b766-9ae2102103fd','dcb67d43-8cd5-4972-ad06-af4552540093','0b116913-5b27-4c19-8eb9-bf5c4787e780','view?usp=sharing','view?usp=sharing','external','application/pdf','URL','https://drive.google.com/uc?export=download&id=1DVlYg71fXwwiIsrCo8hbpVagXJKwUV6a','2026-08-05 08:58:12.636446+00') ON CONFLICT DO NOTHING;
INSERT INTO ad_document_file (id, doc_id, organisation_id, file_name, download_file_name, storage_path, mime_type, source_type, external_url, created_at) VALUES ('59f37b9d-581c-432c-93e4-6d3b642da8a4','0ac929aa-dd2c-422b-bb28-a9aeeb012e7b','0b116913-5b27-4c19-8eb9-bf5c4787e780','uc?export=download&id=1WNQSAnMHLE3iYXxYkwFEJVDVSanwjPlf','uc?export=download&id=1WNQSAnMHLE3iYXxYkwFEJVDVSanwjPlf','external','application/pdf','URL','https://drive.google.com/uc?export=download&id=1WNQSAnMHLE3iYXxYkwFEJVDVSanwjPlf','2026-08-05 09:11:41.486329+00') ON CONFLICT DO NOTHING;
INSERT INTO ad_document_file (id, doc_id, organisation_id, file_name, download_file_name, storage_path, mime_type, source_type, created_at) VALUES ('a99904a0-402a-4921-9403-24a5e8121457','4c1591bd-0787-47e6-a96a-562bedf63c61','0b116913-5b27-4c19-8eb9-bf5c4787e780','Costa_ECM_Executive_Summary.pdf','Costa_Exec_summary.pdf','0b116913-5b27-4c19-8eb9-bf5c4787e780/1786099754473_Costa_ECM_Executive_Summary.pdf','application/pdf','SUPABASE','2026-08-07 10:49:18.109488+00') ON CONFLICT DO NOTHING;

-- ── Distributions ────────────────────────────────────────────────────────────
INSERT INTO ad_distribution (distribution_id, organisation_id, name, doc_id, instructions, distribution_type, start_date, due_date, days_to_acknowledge, first_warning_days, first_warning_direction, second_warning_days, second_warning_direction, req_acknowledgement, req_password, owner) VALUES ('df1e101b-c142-4e2c-ad0b-841ad75e90da','0b116913-5b27-4c19-8eb9-bf5c4787e780','x','0ac929aa-dd2c-422b-bb28-a9aeeb012e7b','','FIXED_VAL','2026-08-05','2026-08-19',null,7,'B',3,'B',true,false,null) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution (distribution_id, organisation_id, name, doc_id, instructions, distribution_type, start_date, due_date, days_to_acknowledge, first_warning_days, first_warning_direction, second_warning_days, second_warning_direction, req_acknowledgement, req_password, owner) VALUES ('82299546-9e55-4b3d-84bb-25ecb2656f40','0b116913-5b27-4c19-8eb9-bf5c4787e780','z','0ac929aa-dd2c-422b-bb28-a9aeeb012e7b','','ONEOFF','2026-08-05','2026-08-19',null,7,'B',3,'B',true,false,null) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution (distribution_id, organisation_id, name, doc_id, instructions, distribution_type, start_date, due_date, days_to_acknowledge, first_warning_days, first_warning_direction, second_warning_days, second_warning_direction, req_acknowledgement, req_password, owner) VALUES ('d05673fa-f270-4389-a419-277843cf1aa5','0b116913-5b27-4c19-8eb9-bf5c4787e780','Demo to Jacob','4c1591bd-0787-47e6-a96a-562bedf63c61','','ONEOFF','2026-08-10','2026-08-20',10,7,'B',2,'B',true,false,null) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution (distribution_id, organisation_id, name, doc_id, instructions, distribution_type, start_date, due_date, days_to_acknowledge, first_warning_days, first_warning_direction, second_warning_days, second_warning_direction, req_acknowledgement, req_password, owner) VALUES ('14c864a5-f09f-48c9-bcaf-a8e1c397a108','0b116913-5b27-4c19-8eb9-bf5c4787e780','test','dcb67d43-8cd5-4972-ad06-af4552540093','','ONEOFF','2026-08-17','2026-07-29',null,7,'B',2,'B',true,false,null) ON CONFLICT DO NOTHING;

-- ── Distribution Audiences ───────────────────────────────────────────────────
INSERT INTO ad_distribution_audience (distribution_id, audience_id, organisation_id, sort_order) VALUES ('df1e101b-c142-4e2c-ad0b-841ad75e90da','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780',0) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution_audience (distribution_id, audience_id, organisation_id, sort_order) VALUES ('82299546-9e55-4b3d-84bb-25ecb2656f40','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780',0) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution_audience (distribution_id, audience_id, organisation_id, sort_order) VALUES ('d05673fa-f270-4389-a419-277843cf1aa5','c4084a11-deff-45a5-9f5f-ccd5cf5ac1cb','0b116913-5b27-4c19-8eb9-bf5c4787e780',0) ON CONFLICT DO NOTHING;
INSERT INTO ad_distribution_audience (distribution_id, audience_id, organisation_id, sort_order) VALUES ('14c864a5-f09f-48c9-bcaf-a8e1c397a108','2316152b-376c-4c99-93dc-ed3b98c870cb','0b116913-5b27-4c19-8eb9-bf5c4787e780',0) ON CONFLICT DO NOTHING;

-- ── Distribution Items ───────────────────────────────────────────────────────
-- Note: user_id values reference auth.users in the NEW project.
-- These will only work if users are invited with the same UUIDs, which is not
-- possible. Insert these AFTER inviting users and update user_ids accordingly,
-- OR skip this section and re-run build_distribution_items after setup.
-- Included here for reference only.

/*
INSERT INTO ad_distribution_item (distrib_item_id, organisation_id, distribution_id, user_id, start_date, due_date, acknowledged, acknowledged_date, rejected, rejected_date, status, rejected_reason) VALUES ('23e72b30-528d-4f7c-8c52-b58942719f66','0b116913-5b27-4c19-8eb9-bf5c4787e780','df1e101b-c142-4e2c-ad0b-841ad75e90da','01847604-69b8-4109-8b19-bcb763e74ed8','2026-08-05','2026-08-19',false,'',false,'','PENDING','') ON CONFLICT DO NOTHING;
-- ... (remaining items reference old user UUIDs — re-generate via build_distribution_items)
*/

-- ============================================================================
-- IMPORTANT: Distribution items reference auth.user UUIDs which are different
-- in each Supabase project. After inviting users, re-generate distribution
-- items by calling build_distribution_items for each distribution.
-- ============================================================================
