-- =====================================================================
--  03_reset_data_keep_superadmin.sql – OPTIONAL
--  Deletes ALL data but KEEPS every super_admin user and their organization(s).
--  Runs as one transaction: if anything fails, nothing is deleted.
-- =====================================================================
begin;
create temp table keep_users on commit drop as select id from public.users where role = 'super_admin';
create temp table keep_orgs on commit drop as
  with recursive up as (
    select o.id, o.parent_id from public.organizations o
     where o.id in (select organization_id from public.users where role = 'super_admin' and organization_id is not null) or o.type = 'root'
    union select p.id, p.parent_id from public.organizations p join up on p.id = up.parent_id)
  select distinct id from up;
delete from public.results; delete from public.activity_events; delete from public.exam_attempts; delete from public.exam_assignments;
delete from public.exam_questions; delete from public.question_media; delete from public.submission_files; delete from public.assignment_submissions;
delete from public.assignment_attachments; delete from public.assignment_batches; delete from public.assignments; delete from public.activities;
delete from public.exams; delete from public.notifications; delete from public.announcements; delete from public.audit_logs;
delete from public.engagement_status where user_id not in (select id from keep_users);
delete from public.app_sessions; delete from public.batch_members; delete from public.batches;
update public.questions set duplicate_of = null; delete from public.questions; delete from public.syllabus_imports;
delete from public.topics; delete from public.chapters; delete from public.subjects;
update public.exam_categories set created_by = null; delete from public.exam_categories;
delete from public.users where id not in (select id from keep_users);
update public.organizations set parent_id = null where id not in (select id from keep_orgs);
delete from public.organizations where id not in (select id from keep_orgs);
delete from private.file_tickets;
commit;
select (select count(*) from public.users) as users_left, (select count(*) from public.organizations) as organizations_left;
