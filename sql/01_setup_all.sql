-- =====================================================================
--  ExamPortal – COMPLETE DATABASE BACKEND
--  Paste this whole file into Supabase > SQL Editor and click RUN.
--  Safe to run again after updates (everything is "create or replace").
--  It does NOT delete any of your data.
--
--  What it does:
--   * locks all tables (the public anon key can't read/write them)
--   * creates one secure function  public.api(...)  that the website calls
--   * creates a private "uploads" storage bucket with ticket-based access
--   * stores the Groq key in a private table the browser can never read
-- =====================================================================

-- ---------- 0. make sure every table and column exists (repairs older databases) ----------
set check_function_bodies = off;
create extension if not exists "uuid-ossp" with schema extensions;
create table if not exists public.organizations (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.users (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.batches (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.batch_members (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.exam_categories (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.subjects (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.chapters (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.topics (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.syllabus_imports (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.questions (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.question_media (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.exams (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.exam_questions (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.exam_assignments (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.exam_attempts (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.assignments (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.assignment_attachments (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.assignment_batches (assignment_id uuid not null, batch_id uuid not null, primary key (assignment_id, batch_id));
create table if not exists public.assignment_submissions (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.submission_files (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.activities (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.activity_events (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.engagement_status (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.results (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.announcements (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.notifications (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.audit_logs (id uuid primary key default extensions.uuid_generate_v4());
create table if not exists public.app_sessions (id uuid primary key default extensions.uuid_generate_v4());
alter table public.organizations add column if not exists name text;
alter table public.organizations add column if not exists code text;
alter table public.organizations add column if not exists type text;
alter table public.organizations add column if not exists parent_id uuid;
alter table public.organizations add column if not exists is_active boolean default true;
alter table public.organizations add column if not exists settings jsonb default '{}'::jsonb;
alter table public.organizations add column if not exists created_at timestamp with time zone default now();
alter table public.organizations add column if not exists updated_at timestamp with time zone default now();
alter table public.organizations add column if not exists city text;
alter table public.organizations add column if not exists contact_email text;
alter table public.organizations add column if not exists logo_url text;
alter table public.organizations add column if not exists address text;
alter table public.users add column if not exists email text;
alter table public.users add column if not exists password_hash text;
alter table public.users add column if not exists full_name text;
alter table public.users add column if not exists phone text;
alter table public.users add column if not exists role text;
alter table public.users add column if not exists organization_id uuid;
alter table public.users add column if not exists is_active boolean default true;
alter table public.users add column if not exists last_login_at timestamp with time zone;
alter table public.users add column if not exists metadata jsonb default '{}'::jsonb;
alter table public.users add column if not exists created_at timestamp with time zone default now();
alter table public.users add column if not exists updated_at timestamp with time zone default now();
alter table public.users add column if not exists roll_number text;
alter table public.users add column if not exists avatar_url text;
alter table public.users add column if not exists failed_logins integer default 0;
alter table public.users add column if not exists locked_until timestamp with time zone;
alter table public.batches add column if not exists organization_id uuid;
alter table public.batches add column if not exists name text;
alter table public.batches add column if not exists code text;
alter table public.batches add column if not exists academic_year text;
alter table public.batches add column if not exists start_date date;
alter table public.batches add column if not exists end_date date;
alter table public.batches add column if not exists is_active boolean default true;
alter table public.batches add column if not exists created_by uuid;
alter table public.batches add column if not exists created_at timestamp with time zone default now();
alter table public.batches add column if not exists updated_at timestamp with time zone default now();
alter table public.batches add column if not exists description text;
alter table public.batches add column if not exists exam_category_id uuid;
alter table public.batch_members add column if not exists batch_id uuid;
alter table public.batch_members add column if not exists user_id uuid;
alter table public.batch_members add column if not exists role_in_batch text default 'student'::text;
alter table public.batch_members add column if not exists joined_at timestamp with time zone default now();
alter table public.exam_categories add column if not exists name text;
alter table public.exam_categories add column if not exists code text;
alter table public.exam_categories add column if not exists description text;
alter table public.exam_categories add column if not exists is_active boolean default true;
alter table public.exam_categories add column if not exists created_by uuid;
alter table public.exam_categories add column if not exists created_at timestamp with time zone default now();
alter table public.exam_categories add column if not exists updated_at timestamp with time zone default now();
alter table public.exam_categories add column if not exists icon text default 'journal-bookmark'::text;
alter table public.exam_categories add column if not exists color text default '#4338ca'::text;
alter table public.subjects add column if not exists exam_category_id uuid;
alter table public.subjects add column if not exists name text;
alter table public.subjects add column if not exists code text;
alter table public.subjects add column if not exists order_index integer default 0;
alter table public.subjects add column if not exists is_active boolean default true;
alter table public.subjects add column if not exists created_at timestamp with time zone default now();
alter table public.chapters add column if not exists subject_id uuid;
alter table public.chapters add column if not exists name text;
alter table public.chapters add column if not exists code text;
alter table public.chapters add column if not exists order_index integer default 0;
alter table public.chapters add column if not exists is_active boolean default true;
alter table public.chapters add column if not exists created_at timestamp with time zone default now();
alter table public.chapters add column if not exists weightage numeric;
alter table public.chapters add column if not exists status text default 'published'::text;
alter table public.topics add column if not exists chapter_id uuid;
alter table public.topics add column if not exists name text;
alter table public.topics add column if not exists code text;
alter table public.topics add column if not exists order_index integer default 0;
alter table public.topics add column if not exists is_active boolean default true;
alter table public.topics add column if not exists created_at timestamp with time zone default now();
alter table public.syllabus_imports add column if not exists exam_category_id uuid;
alter table public.syllabus_imports add column if not exists file_url text;
alter table public.syllabus_imports add column if not exists file_type text;
alter table public.syllabus_imports add column if not exists status text default 'pending'::text;
alter table public.syllabus_imports add column if not exists imported_by uuid;
alter table public.syllabus_imports add column if not exists reviewed_by uuid;
alter table public.syllabus_imports add column if not exists review_notes text;
alter table public.syllabus_imports add column if not exists created_at timestamp with time zone default now();
alter table public.syllabus_imports add column if not exists updated_at timestamp with time zone default now();
alter table public.questions add column if not exists organization_id uuid;
alter table public.questions add column if not exists subject_id uuid;
alter table public.questions add column if not exists chapter_id uuid;
alter table public.questions add column if not exists topic_id uuid;
alter table public.questions add column if not exists question_text text;
alter table public.questions add column if not exists question_type text;
alter table public.questions add column if not exists difficulty text;
alter table public.questions add column if not exists language text default 'en'::text;
alter table public.questions add column if not exists options jsonb;
alter table public.questions add column if not exists correct_answer jsonb;
alter table public.questions add column if not exists explanation text;
alter table public.questions add column if not exists marks numeric default 1;
alter table public.questions add column if not exists negative_marks numeric default 0;
alter table public.questions add column if not exists tags text[];
alter table public.questions add column if not exists source text;
alter table public.questions add column if not exists status text default 'draft'::text;
alter table public.questions add column if not exists created_by uuid;
alter table public.questions add column if not exists reviewed_by uuid;
alter table public.questions add column if not exists approved_at timestamp with time zone;
alter table public.questions add column if not exists is_duplicate boolean default false;
alter table public.questions add column if not exists duplicate_of uuid;
alter table public.questions add column if not exists metadata jsonb default '{}'::jsonb;
alter table public.questions add column if not exists created_at timestamp with time zone default now();
alter table public.questions add column if not exists updated_at timestamp with time zone default now();
alter table public.questions add column if not exists review_note text;
alter table public.question_media add column if not exists question_id uuid;
alter table public.question_media add column if not exists media_type text;
alter table public.question_media add column if not exists file_path text;
alter table public.question_media add column if not exists order_index integer default 0;
alter table public.question_media add column if not exists created_at timestamp with time zone default now();
alter table public.exams add column if not exists organization_id uuid;
alter table public.exams add column if not exists exam_category_id uuid;
alter table public.exams add column if not exists title text;
alter table public.exams add column if not exists description text;
alter table public.exams add column if not exists total_marks numeric default 0;
alter table public.exams add column if not exists duration_minutes integer;
alter table public.exams add column if not exists total_questions integer default 0;
alter table public.exams add column if not exists attempt_limit integer default 1;
alter table public.exams add column if not exists shuffle_questions boolean default false;
alter table public.exams add column if not exists shuffle_options boolean default false;
alter table public.exams add column if not exists show_result_immediately boolean default false;
alter table public.exams add column if not exists negative_marking boolean default false;
alter table public.exams add column if not exists status text default 'draft'::text;
alter table public.exams add column if not exists start_time timestamp with time zone;
alter table public.exams add column if not exists end_time timestamp with time zone;
alter table public.exams add column if not exists created_by uuid;
alter table public.exams add column if not exists published_by uuid;
alter table public.exams add column if not exists published_at timestamp with time zone;
alter table public.exams add column if not exists settings jsonb default '{}'::jsonb;
alter table public.exams add column if not exists created_at timestamp with time zone default now();
alter table public.exams add column if not exists updated_at timestamp with time zone default now();
alter table public.exams add column if not exists instructions text;
alter table public.exams add column if not exists pass_percentage numeric default 33;
alter table public.exams add column if not exists blueprint jsonb;
alter table public.exam_questions add column if not exists exam_id uuid;
alter table public.exam_questions add column if not exists question_id uuid;
alter table public.exam_questions add column if not exists order_index integer;
alter table public.exam_questions add column if not exists marks numeric;
alter table public.exam_questions add column if not exists section text;
alter table public.exam_questions add column if not exists is_mandatory boolean default true;
alter table public.exam_assignments add column if not exists exam_id uuid;
alter table public.exam_assignments add column if not exists batch_id uuid;
alter table public.exam_assignments add column if not exists user_id uuid;
alter table public.exam_assignments add column if not exists assigned_by uuid;
alter table public.exam_assignments add column if not exists assigned_at timestamp with time zone default now();
alter table public.exam_assignments add column if not exists created_at timestamp with time zone default now();
alter table public.exam_attempts add column if not exists exam_id uuid;
alter table public.exam_attempts add column if not exists user_id uuid;
alter table public.exam_attempts add column if not exists attempt_number integer default 1;
alter table public.exam_attempts add column if not exists started_at timestamp with time zone default now();
alter table public.exam_attempts add column if not exists submitted_at timestamp with time zone;
alter table public.exam_attempts add column if not exists time_spent_seconds integer;
alter table public.exam_attempts add column if not exists status text default 'in_progress'::text;
alter table public.exam_attempts add column if not exists score numeric;
alter table public.exam_attempts add column if not exists max_score numeric;
alter table public.exam_attempts add column if not exists percentage numeric;
alter table public.exam_attempts add column if not exists rank integer;
alter table public.exam_attempts add column if not exists percentile numeric;
alter table public.exam_attempts add column if not exists answers jsonb default '{}'::jsonb;
alter table public.exam_attempts add column if not exists auto_save_data jsonb default '{}'::jsonb;
alter table public.exam_attempts add column if not exists ip_address inet;
alter table public.exam_attempts add column if not exists user_agent text;
alter table public.exam_attempts add column if not exists created_at timestamp with time zone default now();
alter table public.exam_attempts add column if not exists updated_at timestamp with time zone default now();
alter table public.exam_attempts add column if not exists tab_switches integer default 0;
alter table public.assignments add column if not exists organization_id uuid;
alter table public.assignments add column if not exists title text;
alter table public.assignments add column if not exists description text;
alter table public.assignments add column if not exists assignment_type text;
alter table public.assignments add column if not exists max_marks numeric;
alter table public.assignments add column if not exists deadline timestamp with time zone;
alter table public.assignments add column if not exists allow_resubmit boolean default true;
alter table public.assignments add column if not exists max_resubmits integer default 3;
alter table public.assignments add column if not exists status text default 'draft'::text;
alter table public.assignments add column if not exists created_by uuid;
alter table public.assignments add column if not exists published_at timestamp with time zone;
alter table public.assignments add column if not exists settings jsonb default '{}'::jsonb;
alter table public.assignments add column if not exists created_at timestamp with time zone default now();
alter table public.assignments add column if not exists updated_at timestamp with time zone default now();
alter table public.assignments add column if not exists allowed_types text default 'pdf,docx,jpg,jpeg,png,zip,txt'::text;
alter table public.assignments add column if not exists attachment_path text;
alter table public.assignment_attachments add column if not exists assignment_id uuid;
alter table public.assignment_attachments add column if not exists file_path text;
alter table public.assignment_attachments add column if not exists file_name text;
alter table public.assignment_attachments add column if not exists file_type text;
alter table public.assignment_attachments add column if not exists created_at timestamp with time zone default now();
alter table public.assignment_batches add column if not exists assignment_id uuid;
alter table public.assignment_batches add column if not exists batch_id uuid;
alter table public.assignment_submissions add column if not exists assignment_id uuid;
alter table public.assignment_submissions add column if not exists user_id uuid;
alter table public.assignment_submissions add column if not exists attempt_number integer default 1;
alter table public.assignment_submissions add column if not exists submitted_at timestamp with time zone default now();
alter table public.assignment_submissions add column if not exists status text default 'submitted'::text;
alter table public.assignment_submissions add column if not exists marks_obtained numeric;
alter table public.assignment_submissions add column if not exists feedback text;
alter table public.assignment_submissions add column if not exists evaluated_by uuid;
alter table public.assignment_submissions add column if not exists evaluated_at timestamp with time zone;
alter table public.assignment_submissions add column if not exists created_at timestamp with time zone default now();
alter table public.assignment_submissions add column if not exists updated_at timestamp with time zone default now();
alter table public.assignment_submissions add column if not exists content text;
alter table public.assignment_submissions add column if not exists link_url text;
alter table public.submission_files add column if not exists submission_id uuid;
alter table public.submission_files add column if not exists file_path text;
alter table public.submission_files add column if not exists file_name text;
alter table public.submission_files add column if not exists file_type text;
alter table public.submission_files add column if not exists created_at timestamp with time zone default now();
alter table public.submission_files add column if not exists file_size bigint;
alter table public.activities add column if not exists organization_id uuid;
alter table public.activities add column if not exists title text;
alter table public.activities add column if not exists activity_type text;
alter table public.activities add column if not exists duration_minutes integer;
alter table public.activities add column if not exists start_time timestamp with time zone;
alter table public.activities add column if not exists end_time timestamp with time zone;
alter table public.activities add column if not exists created_by uuid;
alter table public.activities add column if not exists created_at timestamp with time zone default now();
alter table public.activities add column if not exists description text;
alter table public.activities add column if not exists exam_id uuid;
alter table public.activities add column if not exists resource_url text;
alter table public.activities add column if not exists points integer default 10;
alter table public.activities add column if not exists is_active boolean default true;
alter table public.activity_events add column if not exists user_id uuid;
alter table public.activity_events add column if not exists activity_id uuid;
alter table public.activity_events add column if not exists exam_attempt_id uuid;
alter table public.activity_events add column if not exists event_type text;
alter table public.activity_events add column if not exists metadata jsonb default '{}'::jsonb;
alter table public.activity_events add column if not exists created_at timestamp with time zone default now();
alter table public.activity_events add column if not exists meta jsonb default '{}'::jsonb;
alter table public.engagement_status add column if not exists user_id uuid;
alter table public.engagement_status add column if not exists status text default 'active'::text;
alter table public.engagement_status add column if not exists last_activity_at timestamp with time zone;
alter table public.engagement_status add column if not exists inactivity_days integer default 0;
alter table public.engagement_status add column if not exists updated_at timestamp with time zone default now();
alter table public.results add column if not exists exam_attempt_id uuid;
alter table public.results add column if not exists user_id uuid;
alter table public.results add column if not exists exam_id uuid;
alter table public.results add column if not exists total_score numeric default 0;
alter table public.results add column if not exists max_score numeric default 0;
alter table public.results add column if not exists percentage numeric;
alter table public.results add column if not exists rank integer;
alter table public.results add column if not exists percentile numeric;
alter table public.results add column if not exists subject_wise jsonb;
alter table public.results add column if not exists chapter_wise jsonb;
alter table public.results add column if not exists topic_wise jsonb;
alter table public.results add column if not exists accuracy numeric;
alter table public.results add column if not exists is_visible boolean default false;
alter table public.results add column if not exists released_at timestamp with time zone;
alter table public.results add column if not exists scorecard_url text;
alter table public.results add column if not exists created_at timestamp with time zone default now();
alter table public.results add column if not exists updated_at timestamp with time zone default now();
alter table public.results add column if not exists time_spent_seconds integer;
alter table public.announcements add column if not exists organization_id uuid;
alter table public.announcements add column if not exists title text;
alter table public.announcements add column if not exists body text;
alter table public.announcements add column if not exists target_type text default 'all'::text;
alter table public.announcements add column if not exists target_ids uuid[];
alter table public.announcements add column if not exists created_by uuid;
alter table public.announcements add column if not exists published_at timestamp with time zone default now();
alter table public.announcements add column if not exists expires_at timestamp with time zone;
alter table public.announcements add column if not exists created_at timestamp with time zone default now();
alter table public.announcements add column if not exists priority text default 'normal'::text;
alter table public.announcements add column if not exists target_org uuid;
alter table public.announcements add column if not exists target_batch uuid;
alter table public.announcements add column if not exists target_role text;
alter table public.notifications add column if not exists user_id uuid;
alter table public.notifications add column if not exists title text;
alter table public.notifications add column if not exists body text;
alter table public.notifications add column if not exists type text;
alter table public.notifications add column if not exists reference_id uuid;
alter table public.notifications add column if not exists reference_type text;
alter table public.notifications add column if not exists is_read boolean default false;
alter table public.notifications add column if not exists read_at timestamp with time zone;
alter table public.notifications add column if not exists action_url text;
alter table public.notifications add column if not exists created_at timestamp with time zone default now();
alter table public.audit_logs add column if not exists user_id uuid;
alter table public.audit_logs add column if not exists action text;
alter table public.audit_logs add column if not exists entity_type text;
alter table public.audit_logs add column if not exists entity_id text;
alter table public.audit_logs add column if not exists old_data jsonb;
alter table public.audit_logs add column if not exists new_data jsonb;
alter table public.audit_logs add column if not exists ip_address inet;
alter table public.audit_logs add column if not exists user_agent text;
alter table public.audit_logs add column if not exists created_at timestamp with time zone default now();
alter table public.audit_logs add column if not exists actor_email text;
alter table public.app_sessions add column if not exists user_id uuid;
alter table public.app_sessions add column if not exists token_hash text;
alter table public.app_sessions add column if not exists user_agent text;
alter table public.app_sessions add column if not exists created_at timestamp with time zone default now();
alter table public.app_sessions add column if not exists last_seen_at timestamp with time zone default now();
alter table public.app_sessions add column if not exists expires_at timestamp with time zone;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.results'::regclass and contype = 'u' and pg_get_constraintdef(oid) like '%(exam_attempt_id)%') then
    alter table public.results add constraint results_exam_attempt_id_key unique (exam_attempt_id); end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.engagement_status'::regclass and contype = 'u' and pg_get_constraintdef(oid) like '%(user_id)%') then
    alter table public.engagement_status add constraint engagement_status_user_id_key unique (user_id); end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.app_sessions'::regclass and contype = 'u' and pg_get_constraintdef(oid) like '%(token_hash)%') then
    alter table public.app_sessions add constraint app_sessions_token_hash_key unique (token_hash); end if;
exception when others then raise notice 'Unique constraint skipped: %', sqlerrm; end $$;


-- ---------- v3 additions: units level, announcement attachments ----------
create table if not exists public.units (
  id uuid primary key default extensions.uuid_generate_v4(),
  subject_id uuid not null references public.subjects(id),
  name text not null, code text, order_index integer default 0, is_active boolean default true,
  created_at timestamp with time zone default now());
alter table public.chapters add column if not exists unit_id uuid references public.units(id);
alter table public.announcements add column if not exists attachment_url text;
alter table public.announcements add column if not exists attachment_name text;
create index if not exists idx_units_subject on public.units(subject_id);
create index if not exists idx_chapters_unit on public.chapters(unit_id);

-- ---------- extensions ----------
create extension if not exists pgcrypto with schema extensions;
do $$ begin
  create extension if not exists http with schema extensions;      -- used for Groq AI calls
exception when others then
  raise notice 'Could not enable the "http" extension (AI features will be off): %', sqlerrm;
end $$;

-- ---------- private schema (NOT exposed through the API) ----------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;   -- only needed so storage policies can call 2 helper functions
alter default privileges in schema private revoke execute on functions from public;

create table if not exists private.settings (key text primary key, value text, updated_at timestamptz default now());
create table if not exists private.file_tickets (
  path text not null, kind text not null check (kind in ('upload','read')),
  user_id uuid, expires_at timestamptz not null, meta jsonb default '{}'::jsonb,
  primary key (path, kind));
create table if not exists private.error_log (id bigserial primary key, at timestamptz default now(), action text, state text, message text, detail text);
revoke all on all tables in schema private from public, anon, authenticated;

-- ---------- lock every public table ----------
do $$
declare t text; pol record;
begin
  foreach t in array array[
    'organizations','users','batches','batch_members','exam_categories','subjects','chapters','topics',
    'syllabus_imports','questions','question_media','exams','exam_questions','exam_assignments','exam_attempts',
    'assignments','assignment_attachments','assignment_batches','assignment_submissions','submission_files',
    'activities','activity_events','engagement_status','results','announcements','notifications','audit_logs','app_sessions','units']
  loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security', t);
      for pol in select policyname from pg_policies where schemaname='public' and tablename=t loop
        execute format('drop policy if exists %I on public.%I', pol.policyname, t);
      end loop;
      execute format('revoke all on public.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;

-- ---------- indexes ----------
do $$ begin
  begin execute $i$create index if not exists idx_users_org on public.users(organization_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_users_role on public.users(role)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_sessions_user on public.app_sessions(user_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_batch_members_batch on public.batch_members(batch_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_batch_members_user on public.batch_members(user_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_subjects_cat on public.subjects(exam_category_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_chapters_subject on public.chapters(subject_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_topics_chapter on public.topics(chapter_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_questions_org on public.questions(organization_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_questions_subject on public.questions(subject_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_exams_org on public.exams(organization_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_exam_questions_exam on public.exam_questions(exam_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_exam_assign_exam on public.exam_assignments(exam_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_attempts_exam_user on public.exam_attempts(exam_id, user_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_results_exam on public.results(exam_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_results_user on public.results(user_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_asg_batches_batch on public.assignment_batches(batch_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_submissions_asg on public.assignment_submissions(assignment_id)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
  begin execute $i$create index if not exists idx_notifications_user on public.notifications(user_id, is_read)$i$; exception when others then raise notice 'index skipped: %', sqlerrm; end;
end $$;





















-- ---------- storage bucket (private) ----------
do $$ begin
  insert into storage.buckets (id, name, public, file_size_limit) values ('uploads','uploads', false, 10485760)
  on conflict (id) do update set public = false, file_size_limit = 10485760;
exception when others then raise notice 'Storage bucket not created: %', sqlerrm; end $$;

-- AI calls can take ~20 s; the default anon timeout on Supabase is 3 s
alter role anon set statement_timeout = '120s';
alter role authenticated set statement_timeout = '120s';

-- =====================================================================
--  CORE HELPERS
-- =====================================================================
create or replace function private.fail(msg text, code text default null) returns void language plpgsql as $$
begin raise exception using errcode = 'P0001', message = msg, hint = coalesce(code, ''); end $$;

create or replace function private.setting(k text) returns text language sql stable security definer set search_path = private as
$$ select value from private.settings where key = k $$;

create or replace function private.jt(p jsonb, k text) returns text language sql immutable as $$ select nullif(btrim(p->>k), '') $$;
create or replace function private.juuid(p jsonb, k text) returns uuid language sql immutable as
$$ select case when p->>k ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (p->>k)::uuid end $$;
create or replace function private.jnum(p jsonb, k text) returns numeric language plpgsql immutable as $$
begin if p->>k is null or btrim(p->>k) = '' then return null; end if; return (p->>k)::numeric; exception when others then return null; end $$;
create or replace function private.jint(p jsonb, k text) returns int language sql immutable as $$ select trunc(private.jnum(p,k))::int $$;
create or replace function private.jbool(p jsonb, k text) returns boolean language sql immutable as $$ select case when lower(p->>k) in ('true','1','yes','on') then true when lower(p->>k) in ('false','0','no','off') then false end $$;
create or replace function private.jarr(j jsonb) returns text[] language sql immutable as
$$ select coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(j)='array' then j else '[]'::jsonb end)), '{}') $$;
create or replace function private.uuids(j jsonb) returns uuid[] language sql immutable as
$$ select coalesce(array(select distinct x::uuid from jsonb_array_elements_text(case when jsonb_typeof(j)='array' then j else '[]'::jsonb end) x
   where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'), '{}') $$;
create or replace function private.req_uuid(p jsonb, k text, what text default 'item') returns uuid language plpgsql immutable as $$
declare v uuid := private.juuid(p, k); begin if v is null then perform private.fail(format('Please select a valid %s.', what)); end if; return v; end $$;
create or replace function private.label(f text) returns text language sql immutable as
$$ select initcap(replace(regexp_replace(f, '_id$', ''), '_', ' ')) $$;
create or replace function private.has_col(t text, c text) returns boolean language sql stable as
$$ select exists(select 1 from pg_attribute where attrelid = to_regclass('public.' || quote_ident(t)) and attname = c and attnum > 0 and not attisdropped and attgenerated = '') $$;
create or replace function private.plural(n bigint, word text) returns text language sql immutable as
$$ select n || ' ' || word || case when n = 1 then '' else 's' end $$;

-- roles
create or replace function private.r_admin() returns text[] language sql immutable as $$ select array['super_admin','college_admin','institute_admin'] $$;
create or replace function private.r_staff() returns text[] language sql immutable as $$ select array['super_admin','college_admin','institute_admin','faculty'] $$;
create or replace function private.r_all() returns text[] language sql immutable as $$ select array['super_admin','college_admin','institute_admin','faculty','student'] $$;
create or replace function private.rank(r text) returns int language sql immutable as
$$ select case r when 'super_admin' then 5 when 'college_admin' then 4 when 'institute_admin' then 3 when 'faculty' then 2 when 'student' then 1 else 0 end $$;
create or replace function private.role_label(r text) returns text language sql immutable as
$$ select case r when 'super_admin' then 'Super Admin' when 'college_admin' then 'College Admin' when 'institute_admin' then 'Institute Admin' when 'faculty' then 'Faculty' when 'student' then 'Student' else coalesce(r,'') end $$;
create or replace function private.can_manage(actor public.users, r text) returns boolean language sql immutable as
$$ select actor.role = 'super_admin' or private.rank(actor.role) > coalesce(nullif(private.rank(r),0), 9) $$;
create or replace function private.need(u public.users, roles text[]) returns void language plpgsql as $$
begin if not (u.role = any(roles)) then perform private.fail('You don''t have permission to do this.', '403'); end if; end $$;

create or replace function private.org_scope(u public.users) returns uuid[] language plpgsql stable security definer set search_path = public as $$
begin
  if u.role = 'super_admin' then return null; end if;
  if u.organization_id is null then return '{}'; end if;
  if u.role = 'college_admin' then
    return array[u.organization_id] || coalesce(array(select id from organizations where parent_id = u.organization_id), '{}');
  end if;
  return array[u.organization_id];
end $$;
create or replace function private.in_scope(s uuid[], id uuid) returns boolean language sql immutable as
$$ select s is null or (id is not null and id = any(s)) $$;

-- passwords & tokens
create or replace function private.hash_pw(pw text) returns text language sql volatile set search_path = extensions as
$$ select crypt(pw, gen_salt('bf', 10)) $$;
create or replace function private.verify_pw(pw text, stored text) returns boolean language plpgsql stable set search_path = extensions as $$
declare s text;
begin
  if stored is null or pw is null then return false; end if;
  if stored ~ '^\$2[abxy]\$' then
    s := regexp_replace(stored, '^\$2[bxy]\$', '$2a$');
    return crypt(pw, s) = s;
  end if;
  if stored ~* '^[a-f0-9]{64}$' then return encode(digest(pw, 'sha256'), 'hex') = lower(stored); end if;
  return false;
exception when others then return false;
end $$;
create or replace function private.check_pw(p text) returns void language plpgsql as $$
begin
  if p is null or length(p) < 8 then perform private.fail('Password must be at least 8 characters long.'); end if;
  if p !~ '[A-Za-z]' or p !~ '[0-9]' then perform private.fail('Password must contain at least one letter and one number.'); end if;
end $$;
create or replace function private.hash_token(t text) returns text language sql immutable set search_path = extensions as
$$ select encode(digest(coalesce(t,''), 'sha256'), 'hex') $$;

-- small "name" lookups used when returning rows
create or replace function private.nm_org(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.organizations where id = i $$;
create or replace function private.nm_cat(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name,'color',color) from public.exam_categories where id = i $$;
create or replace function private.nm_subject(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.subjects where id = i $$;
create or replace function private.nm_chapter(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.chapters where id = i $$;
create or replace function private.nm_unit(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.units where id = i $$;
create or replace function private.nm_topic(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.topics where id = i $$;
create or replace function private.nm_batch(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'name',name) from public.batches where id = i $$;
create or replace function private.nm_user(i uuid) returns jsonb language sql stable as $$ select jsonb_build_object('id',id,'full_name',full_name,'email',email,'roll_number',roll_number) from public.users where id = i $$;

create or replace function private.user_json(u public.users) returns jsonb language sql stable as $$
  select jsonb_build_object('id',u.id,'email',u.email,'full_name',u.full_name,'phone',u.phone,'role',u.role,'organization_id',u.organization_id,
    'is_active',u.is_active,'roll_number',u.roll_number,'avatar_url',u.avatar_url,'last_login_at',u.last_login_at,
    'organization',(select jsonb_build_object('id',o.id,'name',o.name,'type',o.type,'logo_url',o.logo_url) from public.organizations o where o.id = u.organization_id))
$$;

-- side effects
create or replace function private.audit(u public.users, act text, etype text, eid text, nd jsonb default null, od jsonb default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, old_data)
  values (u.id, u.email, act, etype, eid, nd - 'password_hash', od - 'password_hash');
exception when others then null;
end $$;
create or replace function private.notify(ids uuid[], ttl text, bdy text, typ text, ref uuid default null, ref_type text default null, url text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications(user_id, title, body, type, reference_id, reference_type, action_url)
  select distinct x, ttl, bdy, typ, ref, ref_type, url from unnest(ids) x where x is not null;
exception when others then null;
end $$;
create or replace function private.log_event(uid uuid, typ text, att uuid default null, m jsonb default '{}') returns void
language plpgsql security definer set search_path = public as $$
begin insert into activity_events(user_id, event_type, exam_attempt_id, meta) values (uid, typ, att, coalesce(m,'{}')); exception when others then null; end $$;
create or replace function private.touch(uid uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into engagement_status(user_id, status, last_activity_at, inactivity_days, updated_at) values (uid, 'active', now(), 0, now())
  on conflict (user_id) do update set status = 'active', last_activity_at = now(), inactivity_days = 0, updated_at = now();
exception when others then null;
end $$;
create or replace function private.my_batches(uid uuid) returns uuid[] language sql stable as
$$ select coalesce(array(select batch_id from public.batch_members where user_id = uid), '{}') $$;
create or replace function private.students_of(bids uuid[]) returns uuid[] language sql stable as
$$ select coalesce(array(select distinct m.user_id from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = any(bids) and u.role = 'student'), '{}') $$;
create or replace function private.ist(t timestamptz) returns text language sql stable as
$$ select to_char(t at time zone 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') || ' IST' $$;

-- =====================================================================
--  QUESTION NORMALISATION & GRADING
-- =====================================================================
create or replace function private.norm_options(o jsonb) returns jsonb language plpgsql immutable as $$
declare res jsonb := '[]'; e jsonb; i int := 0; k text; v text;
begin
  if o is null or jsonb_typeof(o) = 'null' then return '[]'; end if;
  if jsonb_typeof(o) = 'string' then
    begin o := (o #>> '{}')::jsonb; exception when others then return '[]'; end;
  end if;
  if jsonb_typeof(o) = 'array' then
    for e in select value from jsonb_array_elements(o) loop
      if jsonb_typeof(e) in ('string','number') then
        res := res || jsonb_build_array(jsonb_build_object('key', chr(65+i), 'text', e #>> '{}'));
      elsif jsonb_typeof(e) = 'object' then
        res := res || jsonb_build_array(jsonb_build_object('key', coalesce(e->>'key', e->>'id', e->>'label', chr(65+i)),
               'text', coalesce(e->>'text', e->>'value', e->>'option', e->>'content', '')));
      end if;
      i := i + 1;
    end loop;
  elsif jsonb_typeof(o) = 'object' then
    for k, v in select key, value #>> '{}' from jsonb_each(o) loop
      res := res || jsonb_build_array(jsonb_build_object('key', k, 'text', v));
    end loop;
  end if;
  return res;
end $$;

create or replace function private.norm_keys(v jsonb, opts jsonb) returns text[] language plpgsql immutable as $$
declare items jsonb; x jsonb; s text; out text[] := '{}'; idx int; m text;
begin
  if v is null or jsonb_typeof(v) = 'null' or v = '""' then return '{}'; end if;
  if jsonb_typeof(v) = 'object' then v := coalesce(v->'keys', v->'key', v->'answer', v->'value'); if v is null then return '{}'; end if; end if;
  if jsonb_typeof(v) = 'array' then items := v;
  elsif jsonb_typeof(v) = 'string' and position(',' in v #>> '{}') > 0 then items := to_jsonb(string_to_array(v #>> '{}', ','));
  else items := jsonb_build_array(v); end if;
  for x in select value from jsonb_array_elements(items) loop
    s := btrim(x #>> '{}');
    if jsonb_typeof(x) = 'number' then
      idx := s::int;
      if idx >= 0 and idx < jsonb_array_length(opts) and not exists(select 1 from jsonb_array_elements(opts) o where o->>'key' = s) then
        out := out || (opts->idx->>'key'); continue;
      end if;
    end if;
    if exists(select 1 from jsonb_array_elements(opts) o where o->>'key' = s) then out := out || s; continue; end if;
    if exists(select 1 from jsonb_array_elements(opts) o where o->>'key' = upper(s)) then out := out || upper(s); continue; end if;
    select o->>'key' into m from jsonb_array_elements(opts) o where lower(btrim(o->>'text')) = lower(s) limit 1;
    out := out || coalesce(m, s);
  end loop;
  return out;
end $$;

create or replace function private.ntext(s text) returns text language sql immutable as $$ select lower(regexp_replace(btrim(coalesce(s,'')), '\s+', ' ', 'g')) $$;
create or replace function private.is_mcq(t text) returns boolean language sql immutable as $$ select t in ('mcq_single','mcq_multi','mcq_multiple') $$;
create or replace function private.is_manual(t text) returns boolean language sql immutable as $$ select t in ('long_answer','coding','file_upload') $$;

-- returns correct | wrong | unattempted | manual
create or replace function private.grade(qtype text, opts jsonb, ca jsonb, ans jsonb) returns text language plpgsql immutable as $$
declare empty boolean; o jsonb := private.norm_options(opts); c text[]; a text[]; v numeric; tol numeric; n numeric;
begin
  empty := ans is null or jsonb_typeof(ans) = 'null' or ans = '""' or ans = '[]';
  if private.is_manual(qtype) then return case when empty then 'unattempted' else 'manual' end; end if;
  if empty then return 'unattempted'; end if;
  if qtype = 'mcq_single' then
    c := private.norm_keys(ca, o);
    return case when c[1] = btrim(ans #>> '{}') then 'correct' else 'wrong' end;
  elsif private.is_mcq(qtype) then
    c := array(select distinct x from unnest(private.norm_keys(ca, o)) x order by 1);
    a := array(select distinct x from jsonb_array_elements_text(case when jsonb_typeof(ans)='array' then ans else jsonb_build_array(ans) end) x order by 1);
    return case when c = a then 'correct' else 'wrong' end;
  elsif qtype = 'true_false' then
    return case when private.ntext(ca #>> '{}') = private.ntext(ans #>> '{}') then 'correct' else 'wrong' end;
  elsif qtype = 'numerical' then
    begin
      v := case when jsonb_typeof(ca) = 'object' then (ca->>'value')::numeric else (ca #>> '{}')::numeric end;
      tol := case when jsonb_typeof(ca) = 'object' then coalesce((ca->>'tolerance')::numeric, 0) else 0 end;
      n := (ans #>> '{}')::numeric;
    exception when others then return 'wrong'; end;
    return case when abs(n - v) <= greatest(tol, 0.000000001) then 'correct' else 'wrong' end;
  elsif qtype = 'short_answer' then
    return case when private.ntext(ans #>> '{}') in (select private.ntext(x) from jsonb_array_elements_text(case when jsonb_typeof(ca)='array' then ca else jsonb_build_array(ca) end) x) then 'correct' else 'wrong' end;
  end if;
  return 'manual';
end $$;

-- validates & normalises a question row (jsonb) before saving
create or replace function private.prepare_question(d jsonb, ex jsonb, u public.users, s uuid[], check_dup boolean) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare typ text := coalesce(d->>'question_type', ex->>'question_type'); o jsonb; ca jsonb; keys text[]; vals text[]; v numeric; tol numeric; h text;
begin
  o := private.norm_options(coalesce(d->'options', ex->'options'));
  ca := case when d ? 'correct_answer' then d->'correct_answer' else ex->'correct_answer' end;
  if d ? 'question_text' and btrim(regexp_replace(coalesce(d->>'question_text',''), '<[^>]*>', '', 'g')) = '' then perform private.fail('Please enter the question text.'); end if;
  if private.is_mcq(typ) then
    if jsonb_array_length(o) < 2 then perform private.fail('A multiple-choice question needs at least 2 options.'); end if;
    if exists(select 1 from jsonb_array_elements(o) x where btrim(x->>'text') = '') then perform private.fail('Please fill in the text for every option (or remove empty ones).'); end if;
    keys := array(select k from unnest(private.norm_keys(ca, o)) k where exists(select 1 from jsonb_array_elements(o) x where x->>'key' = k));
    if cardinality(keys) = 0 then perform private.fail('Please mark the correct option.'); end if;
    if typ = 'mcq_single' and cardinality(keys) > 1 then perform private.fail('A single-choice question can only have one correct option.'); end if;
    d := d || jsonb_build_object('options', o, 'correct_answer', case when typ = 'mcq_single' then to_jsonb(keys[1]) else to_jsonb(keys) end);
  elsif typ = 'true_false' then
    if lower(coalesce(ca #>> '{}','')) not in ('true','false') then perform private.fail('Please choose whether the correct answer is True or False.'); end if;
    d := d || jsonb_build_object('options', '[{"key":"true","text":"True"},{"key":"false","text":"False"}]'::jsonb, 'correct_answer', lower(ca #>> '{}'));
  elsif typ = 'numerical' then
    begin
      v := case when jsonb_typeof(ca) = 'object' then (ca->>'value')::numeric else (ca #>> '{}')::numeric end;
      tol := case when jsonb_typeof(ca) = 'object' then coalesce(nullif(ca->>'tolerance','')::numeric, 0) else 0 end;
    exception when others then v := null; end;
    if v is null then perform private.fail('Please enter the correct numerical answer.'); end if;
    d := d || jsonb_build_object('options', null, 'correct_answer', jsonb_build_object('value', v, 'tolerance', coalesce(tol,0)));
  elsif typ = 'short_answer' then
    vals := array(select btrim(x) from jsonb_array_elements_text(case when jsonb_typeof(ca)='array' then ca else to_jsonb(string_to_array(coalesce(ca #>> '{}',''), '|')) end) x where btrim(x) <> '');
    if cardinality(vals) = 0 then perform private.fail('Please enter at least one accepted answer.'); end if;
    d := d || jsonb_build_object('options', null, 'correct_answer', to_jsonb(vals));
  elsif private.is_manual(typ) then
    d := d || jsonb_build_object('options', null);
  else
    perform private.fail('Please choose a valid question type.');
  end if;
  if d ? 'marks' and d->>'marks' is not null and not (private.jnum(d,'marks') > 0) then perform private.fail('Marks must be greater than 0.'); end if;
  if d ? 'negative_marks' and private.jnum(d,'negative_marks') < 0 then perform private.fail('Negative marks can''t be below 0.'); end if;
  if jsonb_typeof(d->'tags') = 'string' then d := d || jsonb_build_object('tags', to_jsonb(array(select btrim(x) from unnest(string_to_array(d->>'tags', ',')) x where btrim(x) <> ''))); end if;
  if d->>'status' in ('approved','published','rejected') and coalesce(ex->>'status','') <> d->>'status' then
    d := d || jsonb_build_object('reviewed_by', u.id);
    if d->>'status' <> 'rejected' then d := d || jsonb_build_object('approved_at', now()); end if;
  end if;
  if check_dup and ex is null and d->>'question_text' is not null then
    h := md5(lower(regexp_replace(regexp_replace(d->>'question_text', '<[^>]*>', '', 'g'), '[^a-zA-Z0-9]+', '', 'g')));
    if exists(select 1 from questions q where md5(lower(regexp_replace(regexp_replace(q.question_text, '<[^>]*>', '', 'g'), '[^a-zA-Z0-9]+', '', 'g'))) = h
              and (s is null or q.organization_id = any(s) or q.organization_id is null)) then
      perform private.fail('A question with the same text already exists in the question bank.');
    end if;
  end if;
  return d;
end $$;

-- =====================================================================
--  SESSIONS & AUTH
-- =====================================================================
create or replace function private.get_session_user(tok text) returns public.users language plpgsql security definer set search_path = public as $$
declare u users; sid uuid; seen timestamptz;
begin
  if tok is null or length(tok) < 32 then return null; end if;
  select s.id, s.last_seen_at into sid, seen from app_sessions s where s.token_hash = private.hash_token(tok) and s.expires_at > now();
  if sid is null then return null; end if;
  select x.* into u from app_sessions s join users x on x.id = s.user_id where s.id = sid and coalesce(x.is_active, true);
  if u.id is null then return null; end if;
  if seen < now() - interval '5 minutes' then update app_sessions set last_seen_at = now() where id = sid; end if;
  return u;
end $$;

create or replace function private.a_login(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p->>'email',''))); pw text := coalesce(p->>'password',''); u users; failed int; tok text; mins int;
  generic text := 'Incorrect email or password. Please try again.';
begin
  if em = '' or pw = '' then return jsonb_build_object('ok',false,'error','Please enter your email and password.'); end if;
  select * into u from users where lower(email) = em;
  if u.id is null then perform pg_sleep(0.3); return jsonb_build_object('ok',false,'error',generic); end if;
  if u.locked_until is not null and u.locked_until > now() then
    mins := ceil(extract(epoch from (u.locked_until - now())) / 60);
    return jsonb_build_object('ok',false,'error',format('Too many failed attempts. Your account is locked for %s more minute%s.', mins, case when mins > 1 then 's' else '' end));
  end if;
  if not coalesce(u.is_active, true) then return jsonb_build_object('ok',false,'error','Your account has been deactivated. Please contact your administrator.'); end if;
  if u.password_hash is null then return jsonb_build_object('ok',false,'error','No password has been set for this account yet. Please contact your administrator.'); end if;
  if not private.verify_pw(pw, u.password_hash) then
    failed := coalesce(u.failed_logins, 0) + 1;
    if failed >= 5 then
      update users set failed_logins = 0, locked_until = now() + interval '15 minutes' where id = u.id;
      return jsonb_build_object('ok',false,'error','Too many failed attempts. Your account is locked for 15 minutes.');
    end if;
    update users set failed_logins = failed where id = u.id;
    return jsonb_build_object('ok',false,'error', format('%s (%s attempt%s left)', generic, 5 - failed, case when 5 - failed = 1 then '' else 's' end));
  end if;
  tok := encode(extensions.gen_random_bytes(32), 'hex');
  insert into app_sessions(user_id, token_hash, user_agent, expires_at) values (u.id, private.hash_token(tok), left(p->>'user_agent', 300), now() + interval '7 days');
  update users set failed_logins = 0, locked_until = null, last_login_at = now(),
         password_hash = case when u.password_hash ~ '^\$2' then u.password_hash else private.hash_pw(pw) end
   where id = u.id returning * into u;
  delete from app_sessions where user_id = u.id and expires_at < now();
  perform private.log_event(u.id, 'login');
  perform private.touch(u.id);
  perform private.audit(u, 'login', 'users', u.id::text);
  return jsonb_build_object('ok', true, 'token', tok, 'user', private.user_json(u));
end $$;

create or replace function private.act_auth_me(u public.users, s uuid[], p jsonb) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('user', private.user_json(u), 'unread', (select count(*) from notifications where user_id = u.id and not coalesce(is_read,false)))
$$;
create or replace function private.act_auth_logout(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  delete from app_sessions where token_hash = private.hash_token(p->>'_token');
  perform private.log_event(u.id, 'logout');
  return jsonb_build_object('message', 'You have been signed out.');
end $$;
create or replace function private.act_auth_changepassword(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not private.verify_pw(p->>'current_password', u.password_hash) then perform private.fail('Your current password is incorrect.'); end if;
  perform private.check_pw(p->>'new_password');
  if p->>'new_password' = p->>'current_password' then perform private.fail('The new password must be different from the current one.'); end if;
  update users set password_hash = private.hash_pw(p->>'new_password'), updated_at = now() where id = u.id;
  delete from app_sessions where user_id = u.id and token_hash <> private.hash_token(p->>'_token');
  perform private.audit(u, 'change_password', 'users', u.id::text);
  return jsonb_build_object('message', 'Your password has been changed. Other devices were signed out.');
end $$;
create or replace function private.act_profile_update(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare nu users;
begin
  if p ? 'full_name' and private.jt(p,'full_name') is null then perform private.fail('Please enter your name.'); end if;
  if p ? 'avatar_url' and length(coalesce(p->>'avatar_url','')) > 200000 then perform private.fail('That photo is too large. Please choose a smaller image.'); end if;
  update users set full_name = case when p ? 'full_name' then private.jt(p,'full_name') else full_name end,
                   phone = case when p ? 'phone' then private.jt(p,'phone') else phone end,
                   avatar_url = case when p ? 'avatar_url' then private.jt(p,'avatar_url') else avatar_url end,
                   updated_at = now()
   where id = u.id returning * into nu;
  return jsonb_build_object('message', 'Your profile has been updated.', 'user', private.user_json(nu));
end $$;

-- =====================================================================
--  GENERIC CRUD (list / get / save / delete) with role + organization scope
-- =====================================================================
create or replace function private.cfg(t text) returns jsonb language sql immutable as $$
select case t
 when 'organizations' then jsonb_build_object('read', private.r_admin(), 'write', array['super_admin','college_admin'], 'del', array['super_admin'], 'org', 'id',
   'fields', array['name','code','type','parent_id','is_active','city','contact_email','logo_url','address','settings'],
   'required', array['name','type'], 'search', array['name','code','city'], 'order', 'name', 'asc', true, 'upd', true, 'cby', false,
   'row', $r$to_jsonb(t) || jsonb_build_object('parent', private.nm_org(t.parent_id),
     'admins', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'full_name',a.full_name,'email',a.email,'is_active',a.is_active) order by a.created_at)
                         from public.users a where a.organization_id = t.id and a.role in ('college_admin','institute_admin','super_admin')), '[]'::jsonb))$r$)
 when 'users' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(), 'org', 'organization_id',
   'fields', array['email','full_name','phone','role','organization_id','is_active','roll_number','avatar_url'],
   'required', array['email','full_name','role'], 'search', array['full_name','email','roll_number','phone'], 'upd', true, 'cby', false,
   'row', $r$(to_jsonb(t) - 'password_hash' - 'metadata') || jsonb_build_object('organization', private.nm_org(t.organization_id))$r$)
 when 'batches' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(), 'org', 'organization_id',
   'fields', array['organization_id','name','code','academic_year','start_date','end_date','is_active','description','exam_category_id'],
   'required', array['name','organization_id'], 'search', array['name','code','academic_year'], 'upd', true, 'cby', true,
   'row', $r$to_jsonb(t) || jsonb_build_object('organization', private.nm_org(t.organization_id), 'exam_category', private.nm_cat(t.exam_category_id),
          'member_count', (select count(*) from public.batch_members m where m.batch_id = t.id))$r$)
 when 'exam_categories' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(), 'del', array['super_admin'],
   'fields', array['name','code','description','is_active','icon','color'], 'required', array['name'], 'search', array['name','code'],
   'order', 'name', 'asc', true, 'upd', true, 'cby', true, 'row', 'to_jsonb(t)')
 when 'subjects' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(),
   'fields', array['exam_category_id','name','code','order_index','is_active'], 'required', array['name','exam_category_id'], 'search', array['name','code'],
   'order', 'order_index', 'asc', true, 'row', $r$to_jsonb(t) || jsonb_build_object('exam_category', private.nm_cat(t.exam_category_id))$r$)
 when 'chapters' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(),
   'fields', array['subject_id','unit_id','name','code','order_index','is_active','weightage','status'], 'required', array['name','subject_id'], 'search', array['name','code'],
   'order', 'order_index', 'asc', true, 'row', $r$to_jsonb(t) || jsonb_build_object('subject', private.nm_subject(t.subject_id), 'unit', private.nm_unit(t.unit_id))$r$)
 when 'units' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(),
   'fields', array['subject_id','name','code','order_index','is_active'], 'required', array['name','subject_id'], 'search', array['name','code'],
   'order', 'order_index', 'asc', true, 'row', $r$to_jsonb(t) || jsonb_build_object('subject', private.nm_subject(t.subject_id))$r$)
 when 'topics' then jsonb_build_object('read', private.r_staff(), 'write', private.r_admin(),
   'fields', array['chapter_id','name','code','order_index','is_active'], 'required', array['name','chapter_id'], 'search', array['name','code'],
   'order', 'order_index', 'asc', true, 'row', $r$to_jsonb(t) || jsonb_build_object('chapter', private.nm_chapter(t.chapter_id))$r$)
 when 'questions' then jsonb_build_object('read', private.r_staff(), 'write', private.r_staff(), 'org', 'organization_id', 'org_null', true,
   'fields', array['organization_id','subject_id','chapter_id','topic_id','question_text','question_type','difficulty','language','options','correct_answer','explanation','marks','negative_marks','tags','source','status','review_note','metadata'],
   'required', array['question_text','question_type'], 'search', array['question_text'], 'upd', true, 'cby', true,
   'row', $r$to_jsonb(t) || jsonb_build_object('subject', private.nm_subject(t.subject_id), 'chapter', private.nm_chapter(t.chapter_id), 'topic', private.nm_topic(t.topic_id))$r$)
 when 'exams' then jsonb_build_object('read', private.r_staff(), 'write', private.r_staff(), 'org', 'organization_id',
   'fields', array['organization_id','exam_category_id','title','description','duration_minutes','attempt_limit','shuffle_questions','shuffle_options','show_result_immediately','negative_marking','start_time','end_time','instructions','pass_percentage','settings','blueprint'],
   'required', array['title','organization_id','duration_minutes'], 'search', array['title'], 'upd', true, 'cby', true,
   'row', $r$to_jsonb(t) || jsonb_build_object('organization', private.nm_org(t.organization_id), 'exam_category', private.nm_cat(t.exam_category_id))$r$)
 when 'assignments' then jsonb_build_object('read', private.r_staff(), 'write', private.r_staff(), 'org', 'organization_id',
   'fields', array['organization_id','title','description','assignment_type','max_marks','deadline','allow_resubmit','max_resubmits','allowed_types','settings'],
   'required', array['title','organization_id'], 'search', array['title'], 'upd', true, 'cby', true,
   'row', $r$to_jsonb(t) || jsonb_build_object('organization', private.nm_org(t.organization_id),
          'submission_count', (select count(*) from public.assignment_submissions x where x.assignment_id = t.id))$r$)
 when 'activities' then jsonb_build_object('read', private.r_staff(), 'write', private.r_staff(), 'org', 'organization_id',
   'fields', array['organization_id','title','activity_type','duration_minutes','start_time','end_time','description','exam_id','resource_url','points','is_active'],
   'required', array['title','organization_id'], 'search', array['title'], 'cby', true,
   'row', $r$to_jsonb(t) || jsonb_build_object('organization', private.nm_org(t.organization_id), 'exam', (select jsonb_build_object('id',e.id,'title',e.title) from public.exams e where e.id = t.exam_id),
          'completions', (select count(distinct a.user_id) from public.activity_events a where a.activity_id = t.id and a.event_type in ('completion','practice_complete')))$r$)
 when 'announcements' then jsonb_build_object('read', private.r_staff(), 'write', private.r_staff(), 'org', 'organization_id',
   'fields', array['organization_id','title','body','target_type','target_org','target_batch','target_role','priority','expires_at','published_at','attachment_url','attachment_name'],
   'required', array['title','body','organization_id'], 'search', array['title','body'], 'cby', true, 'order', 'published_at', 'asc', false,
   'row', $r$to_jsonb(t) || jsonb_build_object('organization', private.nm_org(t.organization_id), 'batch', private.nm_batch(t.target_batch))$r$)
 when 'audit_logs' then jsonb_build_object('read', array['super_admin'], 'write', array[]::text[], 'fields', array[]::text[], 'required', array[]::text[],
   'search', array['action','entity_type','actor_email'], 'row', 'to_jsonb(t)')
end $$;

create or replace function private.cfg_need(u public.users, t text, mode text) returns jsonb language plpgsql as $$
declare c jsonb := private.cfg(t);
begin
  if c is null then perform private.fail('Unknown data type. Please refresh the page.'); end if;
  if not (u.role = any(private.jarr(case mode when 'read' then c->'read' when 'del' then coalesce(c->'del', c->'write') else c->'write' end))) then
    perform private.fail('You don''t have permission to do this.', '403');
  end if;
  return c;
end $$;

create or replace function private.load_row(t text, id uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare j jsonb;
begin
  execute format('select %s from public.%I t where t.id = $1', private.cfg(t)->>'row', t) into j using id;
  return j;
end $$;

create or replace function private.load_scoped(u public.users, s uuid[], t text, id uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c jsonb := private.cfg(t); j jsonb; ov uuid;
begin
  if id is null then perform private.fail('Please select a valid item.'); end if;
  j := private.load_row(t, id);
  if j is null then perform private.fail('This item was not found. It may have been deleted.', '404'); end if;
  if c->>'org' is not null then
    ov := (j->>(c->>'org'))::uuid;
    if not (coalesce((c->>'org_null')::boolean,false) and ov is null) and not private.in_scope(s, ov) then
      perform private.fail('You don''t have access to this item.', '403');
    end if;
  end if;
  return j;
end $$;

create or replace function private.act_crud_list(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare t text := p->>'table'; c jsonb := private.cfg_need(u, t, 'read'); conds text[] := array['true']; k text; v jsonb; allowed text[];
  pg int := greatest(1, coalesce(private.jint(p,'page'), 1)); sz int := least(500, greatest(1, coalesce(private.jint(p,'pageSize'), 25)));
  srch text := nullif(btrim(p->>'search'), ''); ord text; dir text; rows jsonb; total bigint;
begin
  if c->>'org' is not null and s is not null then
    conds := conds || format('(t.%I = any($1)%s)', c->>'org', case when coalesce((c->>'org_null')::boolean,false) then format(' or t.%I is null', c->>'org') else '' end);
  end if;
  if t = 'users' and u.role <> 'super_admin' then conds := conds || 't.role <> ''super_admin'''::text; end if;
  allowed := private.jarr(c->'fields') || array['id','status','is_active','created_by','role','type','user_id','entity_type','action','question_type','difficulty'];
  for k, v in select key, value from jsonb_each(case when jsonb_typeof(p->'filters') = 'object' then p->'filters' else '{}'::jsonb end) loop
    continue when not (k = any(allowed)) or not private.has_col(t, k) or jsonb_typeof(v) = 'null' or v = '""'::jsonb;
    if jsonb_typeof(v) = 'array' then conds := conds || format('t.%I::text = any(array(select jsonb_array_elements_text($2->%L)))', k, k);
    else conds := conds || format('t.%I::text = ($2->>%L)', k, k); end if;
  end loop;
  if srch is not null and jsonb_array_length(c->'search') > 0 then
    conds := conds || ('(' || (select string_agg(format('t.%I::text ilike ''%%'' || $3 || ''%%''', x), ' or ') from jsonb_array_elements_text(c->'search') x) || ')');
  end if;
  ord := case when p->>'order' = any(allowed || array['created_at','name','published_at','deadline','start_time']) and private.has_col(t, p->>'order') then p->>'order'
              else coalesce(c->>'order', 'created_at') end;
  dir := case when coalesce(private.jbool(p,'asc'), (c->>'asc')::boolean, false) then 'asc' else 'desc' end;
  execute format('select coalesce(jsonb_agg(%s order by x.rn), ''[]''::jsonb), coalesce(max(x.total), 0)
                  from (select t.id, row_number() over (order by t.%I %s nulls last, t.id) rn, count(*) over () total
                        from public.%I t where %s order by t.%I %s nulls last, t.id limit %s offset %s) x
                  join public.%I t on t.id = x.id',
                 c->>'row', ord, dir, t, array_to_string(conds, ' and '), ord, dir, sz, (pg - 1) * sz, t)
    into rows, total using s, p->'filters', replace(replace(coalesce(srch,''), '%', '\%'), '_', '\_');
  return jsonb_build_object('rows', rows, 'total', total, 'page', pg, 'pageSize', sz);
end $$;

create or replace function private.act_crud_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform private.cfg_need(u, p->>'table', 'read');
  return jsonb_build_object('row', private.load_scoped(u, s, p->>'table', private.juuid(p, 'id')));
end $$;

-- table specific rules (returns the cleaned row)
create or replace function private.before_save(t text, u public.users, s uuid[], p jsonb, d jsonb, ex jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r text; pw text := p->'data'->>'password'; st timestamptz; en timestamptz;
begin
  if t = 'organizations' then
    if u.role <> 'super_admin' then
      if ex is null then
        d := d || jsonb_build_object('type', 'institute', 'parent_id', coalesce(d->>'parent_id', u.organization_id::text));
        if not private.in_scope(s, (d->>'parent_id')::uuid) then perform private.fail('You can only add institutes under your own college.'); end if;
      else
        if d ? 'type' and d->>'type' is distinct from ex->>'type' then perform private.fail('Only the Super Admin can change the organization type.'); end if;
        if d ? 'parent_id' and d->>'parent_id' is distinct from ex->>'parent_id' then perform private.fail('Only the Super Admin can move an organization.'); end if;
      end if;
    end if;
    if ex is not null and d->>'parent_id' = ex->>'id' then perform private.fail('An organization can''t be its own parent.'); end if;
    if d->>'contact_email' is not null and d->>'contact_email' !~ '^\S+@\S+\.\S+$' then perform private.fail('Please enter a valid contact email.'); end if;
  elsif t = 'users' then
    if d ? 'email' then
      d := d || jsonb_build_object('email', lower(d->>'email'));
      if d->>'email' !~ '^\S+@\S+\.\S+$' then perform private.fail('Please enter a valid email address.'); end if;
      if exists(select 1 from users x where lower(x.email) = d->>'email' and x.id::text is distinct from ex->>'id') then perform private.fail('This email address is already registered.'); end if;
    end if;
    r := coalesce(d->>'role', ex->>'role');
    if private.rank(r) = 0 then perform private.fail('Please choose a valid role.'); end if;
    if not private.can_manage(u, r) then perform private.fail(format('You can''t create or manage %s accounts.', private.role_label(r)), '403'); end if;
    if ex is not null then
      if (ex->>'id')::uuid = u.id and d ? 'role' and d->>'role' <> ex->>'role' then perform private.fail('You can''t change your own role.'); end if;
      if (ex->>'id')::uuid = u.id and (d->>'is_active')::boolean is false then perform private.fail('You can''t deactivate your own account.'); end if;
      if (ex->>'id')::uuid <> u.id and not private.can_manage(u, ex->>'role') then perform private.fail('You can''t edit this account.', '403'); end if;
    end if;
    if r <> 'super_admin' and coalesce(d->>'organization_id', ex->>'organization_id') is null then perform private.fail('Please select an organization for this user.'); end if;
    if r = 'super_admin' then d := d || jsonb_build_object('organization_id', null); end if;
    if nullif(pw, '') is not null then
      perform private.check_pw(pw);
      d := d || jsonb_build_object('password_hash', private.hash_pw(pw), 'failed_logins', 0, 'locked_until', null);
    elsif ex is null then perform private.fail('Please set a password for the new user.'); end if;
  elsif t in ('batches','exams','activities') then
    begin
      st := coalesce(d->>'start_date', d->>'start_time', ex->>'start_date', ex->>'start_time')::timestamptz;
      en := coalesce(d->>'end_date', d->>'end_time', ex->>'end_date', ex->>'end_time')::timestamptz;
    exception when others then perform private.fail('One of the dates has an invalid format.'); end;
    if st is not null and en is not null and en <= st then perform private.fail('The end date/time must be after the start date/time.'); end if;
    if t = 'exams' then
      if d ? 'duration_minutes' and not (private.jnum(d,'duration_minutes') >= 1) then perform private.fail('Duration must be at least 1 minute.'); end if;
      if d ? 'attempt_limit' and d->>'attempt_limit' is not null and not (private.jnum(d,'attempt_limit') >= 1) then perform private.fail('Attempts allowed must be at least 1.'); end if;
      if d ? 'pass_percentage' and d->>'pass_percentage' is not null and (private.jnum(d,'pass_percentage') < 0 or private.jnum(d,'pass_percentage') > 100) then perform private.fail('Pass percentage must be between 0 and 100.'); end if;
    end if;
    if t = 'activities' and d->>'exam_id' is not null and not exists(select 1 from exams e where e.id = (d->>'exam_id')::uuid and private.in_scope(s, e.organization_id)) then
      perform private.fail('Please choose a valid linked exam.');
    end if;
  elsif t = 'questions' then
    d := private.prepare_question(d, ex, u, s, coalesce(private.jbool(p,'allowDuplicate'), false) is false);
    if ex is not null and ex->>'organization_id' is null and u.role <> 'super_admin' then perform private.fail('Only the Super Admin can edit global questions.', '403'); end if;
  elsif t = 'announcements' then
    d := d || jsonb_build_object('target_type', coalesce(d->>'target_type', ex->>'target_type', 'all'));
    if d->>'target_type' = 'all' and u.role <> 'super_admin' then d := d || '{"target_type":"organization"}'::jsonb; end if;
    if d->>'target_type' = 'batch' and coalesce(d->>'target_batch', ex->>'target_batch') is null then perform private.fail('Please choose the batch for this announcement.'); end if;
    if d->>'target_type' = 'role' and coalesce(d->>'target_role', ex->>'target_role') is null then perform private.fail('Please choose the role for this announcement.'); end if;
    if d->>'target_type' = 'organization' and d->>'target_org' is null then d := d || jsonb_build_object('target_org', coalesce(d->>'organization_id', ex->>'organization_id')); end if;
    if d->>'target_org' is not null and not private.in_scope(s, (d->>'target_org')::uuid) then perform private.fail('You can only target your own organizations.'); end if;
    if ex is null and d->>'published_at' is null then d := d || jsonb_build_object('published_at', now()); end if;
  elsif t = 'assignments' then
    if d ? 'max_marks' and private.jnum(d,'max_marks') < 0 then perform private.fail('Max marks can''t be negative.'); end if;
    if d ? 'allowed_types' then d := d || jsonb_build_object('allowed_types', coalesce(nullif(lower(regexp_replace(d->>'allowed_types', '[\s.]', '', 'g')), ''), 'pdf,docx,jpg,jpeg,png,zip,txt')); end if;
  end if;
  return d;
end $$;

create or replace function private.act_crud_save(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t text := p->>'table'; c jsonb := private.cfg_need(u, t, 'write'); d jsonb := '{}'; ex jsonb; f text; v jsonb;
  oc text := c->>'org'; onull boolean := coalesce((c->>'org_null')::boolean, false); cols text[]; nid uuid; sets text; ad_role text;
begin
  -- keep only allowed fields; blank strings -> null
  for f in select jsonb_array_elements_text(c->'fields') loop
    if p->'data' ? f then
      v := p->'data'->f;
      if jsonb_typeof(v) = 'string' then v := case when btrim(v #>> '{}') = '' then 'null'::jsonb else to_jsonb(btrim(v #>> '{}')) end; end if;
      d := d || jsonb_build_object(f, v);
    end if;
  end loop;
  if private.juuid(p, 'id') is not null then ex := private.load_scoped(u, s, t, private.juuid(p, 'id')); end if;
  if ex is not null and t = 'users' and ex->>'role' = 'super_admin' and u.role <> 'super_admin' then perform private.fail('You can''t edit this account.', '403'); end if;
  -- organization scope
  if oc is not null and oc <> 'id' then
    if ex is null and d->>oc is null and not (onull and u.role = 'super_admin') and not (t = 'users' and d->>'role' = 'super_admin') then
      d := d || jsonb_build_object(oc, u.organization_id);
    end if;
    if d ? oc and d->>oc is distinct from ex->>oc and not private.in_scope(s, (d->>oc)::uuid)
       and not (d->>oc is null and (onull or t = 'users') and u.role = 'super_admin') then
      perform private.fail('You can only save records for your own organization.', '403');
    end if;
  end if;
  -- required fields (organizations get their type defaulted first)
  if t = 'organizations' and u.role <> 'super_admin' then d := private.before_save(t, u, s, p, d, ex); end if;
  for f in select jsonb_array_elements_text(c->'required') loop
    if coalesce(case when d ? f then d->>f else ex->>f end, '') = '' then
      continue when f = 'organization_id' and (t = 'users' or (onull and u.role = 'super_admin'));
      perform private.fail(format('Please fill in: %s.', private.label(f)));
    end if;
  end loop;
  if not (t = 'organizations' and u.role <> 'super_admin') then d := private.before_save(t, u, s, p, d, ex); end if;
  if coalesce((c->>'upd')::boolean, false) then d := d || jsonb_build_object('updated_at', now()); end if;
  cols := array(select k from jsonb_object_keys(d) k where private.has_col(t, k));
  if ex is null then
    if coalesce((c->>'cby')::boolean, false) then d := d || jsonb_build_object('created_by', u.id); cols := array_append(cols, 'created_by'); end if;
    execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) returning id', t,
                   (select string_agg(quote_ident(x), ',') from unnest(cols) x), (select string_agg(quote_ident(x), ',') from unnest(cols) x), t)
      into nid using d;
    perform private.audit(u, 'create', t, nid::text, d);
  else
    nid := (ex->>'id')::uuid;
    if cardinality(cols) > 0 then
      sets := (select string_agg(format('%I = r.%I', x, x), ', ') from unnest(cols) x);
      execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I, $1) r where t.id = $2', t, sets, t) using d, nid;
    end if;
    perform private.audit(u, 'update', t, nid::text, d, ex);
  end if;
  -- organizations: optionally create the organization's admin account in the same transaction
  if t = 'organizations' and private.jt(p->'admin', 'email') is not null then
    ad_role := case (select o.type from organizations o where o.id = nid) when 'college' then 'college_admin' when 'institute' then 'institute_admin' else 'super_admin' end;
    if private.jt(p->'admin', 'full_name') is null then perform private.fail('Please enter the admin''s full name.'); end if;
    if private.jt(p->'admin', 'password') is null then perform private.fail('Please set a password for the admin.'); end if;
    perform private.act_crud_save(u, private.org_scope(u), jsonb_build_object('table', 'users', 'data', jsonb_build_object(
      'full_name', p->'admin'->'full_name', 'email', p->'admin'->'email', 'phone', p->'admin'->'phone', 'password', p->'admin'->'password',
      'role', ad_role, 'organization_id', nid, 'is_active', true)));
    return jsonb_build_object('row', private.load_row(t, nid), 'message',
      case when ex is null then 'Organization created along with its admin account.' else format('Saved. New %s account created.', private.role_label(ad_role)) end);
  end if;
  return jsonb_build_object('row', private.load_row(t, nid), 'message', case when ex is null then 'Created successfully.' else 'Changes saved successfully.' end);
end $$;

create or replace function private.act_crud_delete(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t text := p->>'table'; c jsonb := private.cfg_need(u, t, 'del'); ex jsonb; v_id uuid; n bigint; atts uuid[];
begin
  ex := private.load_scoped(u, s, t, private.juuid(p, 'id'));
  v_id := (ex->>'id')::uuid;
  if t = 'users' then
    if v_id = u.id then perform private.fail('You can''t delete your own account.'); end if;
    if ex->>'role' = 'super_admin' then perform private.fail('Super Admin accounts can''t be deleted from here.'); end if;
    if not private.can_manage(u, ex->>'role') then perform private.fail('You can''t delete this account.', '403'); end if;
    if exists(select 1 from exam_attempts where user_id = v_id) or exists(select 1 from assignment_submissions where user_id = v_id) then
      perform private.fail('This user has exam or assignment history, so the account can''t be deleted. Deactivate it instead.');
    end if;
    delete from app_sessions where user_id = v_id; delete from notifications where user_id = v_id; delete from batch_members where user_id = v_id;
    delete from engagement_status where user_id = v_id; delete from activity_events where user_id = v_id; delete from exam_assignments where user_id = v_id;
    update audit_logs set user_id = null where user_id = v_id;
    update batches set created_by = null where created_by = v_id; update exam_categories set created_by = null where created_by = v_id;
    update questions set created_by = null where created_by = v_id; update questions set reviewed_by = null where reviewed_by = v_id;
    update exams set created_by = null where created_by = v_id; update exams set published_by = null where published_by = v_id;
    update exam_assignments set assigned_by = null where assigned_by = v_id; update assignments set created_by = null where created_by = v_id;
    update assignment_submissions set evaluated_by = null where evaluated_by = v_id; update activities set created_by = null where created_by = v_id;
    update announcements set created_by = null where created_by = v_id;
    update syllabus_imports set imported_by = null where imported_by = v_id; update syllabus_imports set reviewed_by = null where reviewed_by = v_id;
  elsif t = 'organizations' and ex->>'type' = 'root' then perform private.fail('The root organization can''t be deleted.');
  elsif t = 'questions' then
    if ex->>'organization_id' is null and u.role <> 'super_admin' then perform private.fail('Only the Super Admin can delete global questions.', '403'); end if;
    select count(*) into n from exam_questions where question_id = v_id;
    if n > 0 then perform private.fail(format('This question is used in %s. Remove it from those exams first, or archive it instead.', private.plural(n, 'exam'))); end if;
    delete from question_media where question_id = v_id; update questions set duplicate_of = null where duplicate_of = v_id;
  elsif t = 'exams' then
    atts := array(select x.id from exam_attempts x where x.exam_id = v_id);
    delete from results where exam_id = v_id; delete from activity_events where exam_attempt_id = any(atts);
    delete from exam_attempts where exam_id = v_id; delete from exam_questions where exam_id = v_id; delete from exam_assignments where exam_id = v_id;
    update activities set exam_id = null where exam_id = v_id;
  elsif t = 'batches' then
    delete from batch_members where batch_id = v_id; delete from exam_assignments where batch_id = v_id; delete from assignment_batches where batch_id = v_id;
    update announcements set target_batch = null where target_batch = v_id;
  elsif t = 'assignments' then
    delete from submission_files where submission_id in (select x.id from assignment_submissions x where x.assignment_id = v_id);
    delete from assignment_submissions where assignment_id = v_id; delete from assignment_attachments where assignment_id = v_id; delete from assignment_batches where assignment_id = v_id;
  elsif t = 'activities' then delete from activity_events where activity_id = v_id;
  elsif t = 'topics' then update questions set topic_id = null where topic_id = v_id;
  elsif t = 'subjects' and exists(select 1 from chapters where subject_id = v_id) then perform private.fail('Delete this subject''s chapters first.');
  elsif t = 'subjects' and exists(select 1 from units where subject_id = v_id) then perform private.fail('Delete this subject''s units first.');
  elsif t = 'units' then update chapters set unit_id = null where unit_id = v_id;
  elsif t = 'chapters' and exists(select 1 from topics where chapter_id = v_id) then perform private.fail('Delete this chapter''s topics first.');
  elsif t = 'exam_categories' and exists(select 1 from subjects where exam_category_id = v_id) then perform private.fail('Delete this category''s subjects first.');
  end if;
  execute format('delete from public.%I where id = $1', t) using v_id;
  perform private.audit(u, 'delete', t, v_id::text, null, ex);
  return jsonb_build_object('message', 'Deleted successfully.');
end $$;

-- dropdown lists
create or replace function private.act_lookup(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare typ text := p->>'type'; org uuid := private.juuid(p, 'organization_id'); srch text := '%' || coalesce(private.jt(p,'search'), '') || '%'; r jsonb;
begin
  if typ = 'organizations' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'type',type,'parent_id',parent_id) order by name), '[]') into r
      from organizations where coalesce(is_active, true) and private.in_scope(s, id);
    return jsonb_build_object('rows', r);
  end if;
  perform private.need(u, private.r_staff());
  if typ = 'batches' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code,'organization_id',organization_id) order by name), '[]') into r
      from batches where private.in_scope(s, organization_id) and (org is null or organization_id = org);
  elsif typ = 'exam_categories' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code,'color',color,'icon',icon) order by name), '[]') into r from exam_categories where coalesce(is_active, true);
  elsif typ = 'subjects' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'exam_category_id',exam_category_id) order by order_index, name), '[]') into r
      from subjects where private.juuid(p,'exam_category_id') is null or exam_category_id = private.juuid(p,'exam_category_id');
  elsif typ = 'chapters' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'subject_id',subject_id) order by order_index, name), '[]') into r
      from chapters where private.juuid(p,'subject_id') is null or subject_id = private.juuid(p,'subject_id');
  elsif typ = 'topics' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'chapter_id',chapter_id) order by order_index, name), '[]') into r
      from topics where private.juuid(p,'chapter_id') is null or chapter_id = private.juuid(p,'chapter_id');
  elsif typ in ('students','members') then
    select coalesce(jsonb_agg(x order by x->>'full_name'), '[]') into r from (
      select jsonb_build_object('id',id,'full_name',full_name,'email',email,'roll_number',roll_number,'role',role,'organization_id',organization_id) x
      from users where coalesce(is_active, true) and role = any(case when typ = 'students' then array['student'] else array['student','faculty'] end)
        and private.in_scope(s, organization_id) and (org is null or organization_id = org)
        and (full_name ilike srch or email ilike srch or coalesce(roll_number,'') ilike srch)
      limit 2000) q;
  elsif typ = 'exams' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'status',status) order by created_at desc), '[]') into r from exams where private.in_scope(s, organization_id);
  else perform private.fail('Unknown list.');
  end if;
  return jsonb_build_object('rows', r);
end $$;

-- =====================================================================
--  USERS (bulk / reset / unlock)
-- =====================================================================
create or replace function private.act_users_bulkcreate(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := coalesce(p->>'role','student'); org uuid := coalesce(private.juuid(p,'organization_id'), u.organization_id); bid uuid := private.juuid(p,'batch_id');
  row jsonb; em text; nm text; pw text; ln int; report jsonb := '[]'; created int := 0; nid uuid; seen text[] := '{}';
begin
  perform private.need(u, private.r_admin());
  if not private.can_manage(u, r) then perform private.fail(format('You can''t create %s accounts.', private.role_label(r)), '403'); end if;
  if org is null or not private.in_scope(s, org) then perform private.fail('Please choose an organization you manage.'); end if;
  if bid is not null and not exists(select 1 from batches where id = bid and private.in_scope(s, organization_id)) then perform private.fail('Please choose a valid batch.'); end if;
  for row in select value from jsonb_array_elements(case when jsonb_typeof(p->'rows') = 'array' then p->'rows' else '[]' end) limit 50 loop
    em := lower(btrim(coalesce(row->>'email',''))); nm := btrim(coalesce(row->>'full_name','')); ln := coalesce(private.jint(row,'_line'), 0);
    pw := coalesce(nullif(btrim(row->>'password'),''), p->>'default_password');
    if nm = '' or em !~ '^\S+@\S+\.\S+$' then report := report || jsonb_build_object('line',ln,'email',em,'ok',false,'reason','Missing name or invalid email'); continue; end if;
    if em = any(seen) or exists(select 1 from users where lower(email) = em) then report := report || jsonb_build_object('line',ln,'email',em,'ok',false,'reason','Email already registered'); continue; end if;
    if pw is null or length(pw) < 8 then report := report || jsonb_build_object('line',ln,'email',em,'ok',false,'reason','Password missing or shorter than 8 characters'); continue; end if;
    insert into users(email, full_name, phone, roll_number, role, organization_id, is_active, password_hash)
      values (em, nm, nullif(btrim(row->>'phone'),''), nullif(btrim(row->>'roll_number'),''), r, org, true, private.hash_pw(pw)) returning id into nid;
    if bid is not null then insert into batch_members(batch_id, user_id, role_in_batch) values (bid, nid, case when r = 'faculty' then 'faculty' else 'student' end); end if;
    seen := seen || em; created := created + 1;
    report := report || jsonb_build_object('line',ln,'email',em,'ok',true);
  end loop;
  if created > 0 then perform private.audit(u, 'bulk_create', 'users', null, jsonb_build_object('count', created, 'role', r)); end if;
  return jsonb_build_object('created', created, 'report', report);
end $$;

create or replace function private.act_users_resetpassword(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t users;
begin
  perform private.need(u, private.r_admin());
  select * into t from users where id = private.req_uuid(p,'id','user');
  if t.id is null or (t.id <> u.id and (not private.in_scope(s, t.organization_id) or not private.can_manage(u, t.role))) then perform private.fail('You can''t reset this user''s password.', '403'); end if;
  perform private.check_pw(p->>'password');
  update users set password_hash = private.hash_pw(p->>'password'), failed_logins = 0, locked_until = null, updated_at = now() where id = t.id;
  delete from app_sessions where user_id = t.id;
  perform private.audit(u, 'reset_password', 'users', t.id::text);
  return jsonb_build_object('message', 'Password reset. The user must sign in again with the new password.');
end $$;

create or replace function private.act_users_unlock(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t users;
begin
  perform private.need(u, private.r_admin());
  select * into t from users where id = private.req_uuid(p,'id','user');
  if t.id is null or not private.in_scope(s, t.organization_id) or not private.can_manage(u, t.role) then perform private.fail('You can''t unlock this account.', '403'); end if;
  update users set failed_logins = 0, locked_until = null where id = t.id;
  return jsonb_build_object('message', 'Account unlocked.');
end $$;

-- =====================================================================
--  ANNOUNCEMENT FEED
-- =====================================================================
create or replace function private.feed(u public.users) returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select private.my_batches(u.id) ids),
  o as (select coalesce(array_agg(x), '{}') ids from (
          select u.organization_id x union select parent_id from organizations where id = u.organization_id
          union select id from organizations where u.role = 'college_admin' and parent_id = u.organization_id) z where x is not null)
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'priority',a.priority,'published_at',a.published_at,
           'expires_at',a.expires_at,'target_type',a.target_type,'attachment_url',a.attachment_url,'attachment_name',a.attachment_name,'author',(select jsonb_build_object('full_name',full_name) from users where id = a.created_by))
         order by a.published_at desc), '[]')
  from (select * from announcements a, b, o
        where coalesce(a.published_at, a.created_at) <= now() and (a.expires_at is null or a.expires_at > now())
          and (a.target_type = 'all'
               or (a.target_type = 'role' and a.target_role = u.role)
               or (a.target_type = 'organization' and a.target_org = any(o.ids))
               or (a.target_type = 'batch' and a.target_batch = any(b.ids))
               or (u.role <> 'student' and a.created_by = u.id))
        order by a.published_at desc limit 50) a
$$;
create or replace function private.act_announcements_feed(u public.users, s uuid[], p jsonb) returns jsonb language sql stable as $$ select jsonb_build_object('rows', private.feed(u)) $$;

-- =====================================================================
--  BATCHES
-- =====================================================================
create or replace function private.scoped_batch(s uuid[], bid uuid) returns public.batches language plpgsql stable security definer set search_path = public as $$
declare b batches;
begin
  select * into b from batches where id = bid;
  if b.id is null or not private.in_scope(s, b.organization_id) then perform private.fail('Batch not found or you don''t have access.', '404'); end if;
  return b;
end $$;
create or replace function private.act_batch_members(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare b batches;
begin
  perform private.need(u, private.r_staff());
  b := private.scoped_batch(s, private.req_uuid(p,'batch_id','batch'));
  return jsonb_build_object('batch', to_jsonb(b), 'rows', coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'role_in_batch',m.role_in_batch,'joined_at',m.joined_at,
     'user', jsonb_build_object('id',x.id,'full_name',x.full_name,'email',x.email,'roll_number',x.roll_number,'role',x.role)) order by x.full_name)
     from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id), '[]'));
end $$;
create or replace function private.act_batch_addmembers(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare b batches; ids uuid[] := private.uuids(p->'user_ids'); added uuid[]; studs uuid[];
begin
  perform private.need(u, private.r_admin());
  b := private.scoped_batch(s, private.req_uuid(p,'batch_id','batch'));
  if cardinality(ids) = 0 then perform private.fail('Please select at least one person to add.'); end if;
  with ins as (
    insert into batch_members(batch_id, user_id, role_in_batch)
    select b.id, x.id, case when x.role = 'faculty' then 'faculty' else 'student' end from users x
    where x.id = any(ids) and private.in_scope(s, x.organization_id) and x.role in ('student','faculty')
      and not exists(select 1 from batch_members m where m.batch_id = b.id and m.user_id = x.id)
    returning user_id, role_in_batch)
  select coalesce(array_agg(user_id), '{}'), coalesce(array_agg(user_id) filter (where role_in_batch = 'student'), '{}') into added, studs from ins;
  perform private.notify(studs, 'Added to a batch', format('You have been added to batch "%s".', b.name), 'batch', b.id, 'batch');
  return jsonb_build_object('message', format('%s added.%s', private.plural(cardinality(added), 'member'),
     case when cardinality(ids) > cardinality(added) then format(' %s skipped (already in batch or not allowed).', cardinality(ids) - cardinality(added)) else '' end));
end $$;
create or replace function private.act_batch_removemember(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare m batch_members;
begin
  perform private.need(u, private.r_admin());
  select * into m from batch_members where id = private.req_uuid(p,'id');
  if m.id is null then perform private.fail('This member was already removed.'); end if;
  perform private.scoped_batch(s, m.batch_id);
  delete from batch_members where id = m.id;
  return jsonb_build_object('message', 'Member removed from batch.');
end $$;

-- =====================================================================
--  SYLLABUS
-- =====================================================================
create or replace function private.act_syllabus_tree(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cat uuid := private.req_uuid(p,'exam_category_id','exam category');
begin
  perform private.need(u, private.r_staff());
  return jsonb_build_object(
    'subjects', coalesce((select jsonb_agg(to_jsonb(x) order by x.order_index, x.name) from subjects x where x.exam_category_id = cat), '[]'),
    'units', coalesce((select jsonb_agg(to_jsonb(n) order by n.order_index, n.name) from units n join subjects x on x.id = n.subject_id where x.exam_category_id = cat), '[]'),
    'chapters', coalesce((select jsonb_agg(to_jsonb(c) order by c.order_index, c.name) from chapters c join subjects x on x.id = c.subject_id where x.exam_category_id = cat), '[]'),
    'topics', coalesce((select jsonb_agg(to_jsonb(t) order by t.order_index, t.name) from topics t join chapters c on c.id = t.chapter_id join subjects x on x.id = c.subject_id where x.exam_category_id = cat), '[]'));
end $$;

create or replace function private.act_syllabus_import(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare cat uuid := private.req_uuid(p,'exam_category_id','exam category'); sub jsonb; ch jsonb; tp text; sid uuid; cid uuid; si int := 0; ci int; ti int;
  ns int := 0; nc int := 0; nt int := 0; nu int := 0; uid_ uuid; un text; chs jsonb; st text := case when p->>'status' in ('draft','in_review','published') then p->>'status' else 'in_review' end;
begin
  perform private.need(u, private.r_admin());
  if coalesce(jsonb_typeof(p->'subjects'), '') <> 'array' or jsonb_array_length(p->'subjects') = 0 then perform private.fail('There is nothing to import.'); end if;
  for sub in select value from jsonb_array_elements(p->'subjects') loop
    continue when private.jt(sub,'name') is null;
    select id into sid from subjects where exam_category_id = cat and lower(name) = lower(private.jt(sub,'name'));
    if sid is null then insert into subjects(exam_category_id, name, order_index) values (cat, private.jt(sub,'name'), si) returning id into sid; ns := ns + 1; end if;
    si := si + 1; ci := 0;
    -- chapters may be given directly, or grouped inside units (subject -> unit -> chapter); a chapter may also carry a "unit" name
    chs := case when jsonb_typeof(sub->'chapters') = 'array' then sub->'chapters' else '[]' end;
    if jsonb_typeof(sub->'units') = 'array' then
      chs := chs || coalesce((select jsonb_agg(c || jsonb_build_object('unit', un_.value->>'name'))
                               from jsonb_array_elements(sub->'units') un_, jsonb_array_elements(case when jsonb_typeof(un_.value->'chapters') = 'array' then un_.value->'chapters' else '[]' end) c), '[]');
    end if;
    for ch in select value from jsonb_array_elements(chs) loop
      continue when private.jt(ch,'name') is null;
      cid := null; uid_ := null; un := private.jt(ch,'unit');
      if un is not null then
        select id into uid_ from units where subject_id = sid and lower(name) = lower(un);
        if uid_ is null then insert into units(subject_id, name, order_index) values (sid, un, (select count(*) from units where subject_id = sid)) returning id into uid_; nu := nu + 1; end if;
      end if;
      select id into cid from chapters where subject_id = sid and lower(name) = lower(private.jt(ch,'name'));
      if cid is null then insert into chapters(subject_id, unit_id, name, order_index, weightage, status) values (sid, uid_, private.jt(ch,'name'), ci, private.jnum(ch,'weightage'), st) returning id into cid; nc := nc + 1;
      elsif uid_ is not null then update chapters set unit_id = coalesce(unit_id, uid_) where id = cid; end if;
      ci := ci + 1; ti := 0;
      for tp in select coalesce(x->>'name', x #>> '{}') from jsonb_array_elements(case when jsonb_typeof(ch->'topics') = 'array' then ch->'topics' else '[]' end) x loop
        tp := btrim(tp);
        continue when tp is null or tp = '' or exists(select 1 from topics where chapter_id = cid and lower(name) = lower(tp));
        insert into topics(chapter_id, name, order_index) values (cid, tp, ti); ti := ti + 1; nt := nt + 1;
      end loop;
    end loop;
    sid := null;
  end loop;
  insert into syllabus_imports(exam_category_id, file_url, file_type, status, imported_by, review_notes) values (cat, private.jt(p,'file_url'), coalesce(p->>'source','text'), 'approved', u.id, format('%s subjects, %s units, %s chapters, %s topics', ns, nu, nc, nt));
  perform private.audit(u, 'syllabus_import', 'exam_categories', cat::text, jsonb_build_object('subjects',ns,'chapters',nc,'topics',nt));
  return jsonb_build_object('message', format('Import complete: %s, %s, %s and %s added.', private.plural(ns,'new subject'), private.plural(nu,'unit'), private.plural(nc,'chapter'), private.plural(nt,'topic'))
    || case when nc > 0 and st <> 'published' then ' New chapters are waiting for approval.' else '' end);
end $$;

create or replace function private.act_syllabus_setstatus(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare ids uuid[] := private.uuids(p->'chapter_ids'); st text := p->>'status'; n int;
begin
  perform private.need(u, private.r_admin());
  if st not in ('draft','in_review','published') then perform private.fail('Invalid status.'); end if;
  if cardinality(ids) = 0 then perform private.fail('Please select at least one chapter.'); end if;
  update chapters set status = st where id = any(ids); get diagnostics n = row_count;
  return jsonb_build_object('message', format('%s marked as %s.', private.plural(n,'chapter'), replace(st,'_',' ')));
end $$;

-- =====================================================================
--  AI (Groq) – the key never leaves the database
-- =====================================================================
create or replace function private.groq(sys text, prompt text, max_tokens int default 8000) returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare k text := private.setting('groq_api_key'); m text; models text[]; st int; body text; txt text; j jsonb;
begin
  if k is null then perform private.fail('AI features are not set up yet. Super Admin: open Settings and add the Groq API key.', '503'); end if;
  if not exists(select 1 from pg_extension where extname = 'http') then
    perform private.fail('The AI service isn''t available right now. Please contact your administrator.', '503');
  end if;
  models := array(select distinct x from unnest(array[coalesce(private.setting('groq_model'), 'openai/gpt-oss-120b'), 'openai/gpt-oss-120b', 'openai/gpt-oss-20b']) x);
  execute 'select extensions.http_set_curlopt(''CURLOPT_TIMEOUT_MS'', ''100000'')';
  foreach m in array models loop
    begin
      execute $q$select status, content from extensions.http(('POST', 'https://api.groq.com/openai/v1/chat/completions',
                 array[extensions.http_header('Authorization', 'Bearer ' || $1)], 'application/json', $2)::extensions.http_request)$q$
        into st, body
        using k, jsonb_build_object('model', m, 'temperature', 0.5, 'max_tokens', max_tokens, 'response_format', jsonb_build_object('type','json_object'),
              'messages', jsonb_build_array(jsonb_build_object('role','system','content',sys), jsonb_build_object('role','user','content',prompt)))::text;
    exception when others then
      insert into private.error_log(action, state, message) values ('groq', sqlstate, sqlerrm);
      continue;
    end;
    if st = 200 then
      txt := (body::jsonb) #>> '{choices,0,message,content}';
      begin return txt::jsonb; exception when others then
        begin return substring(txt from '\{.*\}')::jsonb; exception when others then continue; end;
      end;
    end if;
    insert into private.error_log(action, state, message) values ('groq', st::text, left(body, 500));
    if st in (401, 403) then perform private.fail('The AI service key is invalid or expired. Super Admin: update the Groq key in Settings.', '503'); end if;
    if st = 429 then perform private.fail('The AI service is busy right now (rate limit reached). Please wait a minute and try again.', '429'); end if;
    if st = 413 then perform private.fail('The request is too large for the AI. Try fewer questions or shorter text.'); end if;
  end loop;
  perform private.fail('The AI service is temporarily unavailable. Please try again in a moment.', '503');
end $$;

create or replace function private.act_ai_generatequestions(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare n int := least(20, greatest(1, coalesce(private.jint(p,'count'), 5)));
  typ text := case when p->>'question_type' in ('mcq_single','mcq_multi','true_false','numerical','short_answer','long_answer') then p->>'question_type' else 'mcq_single' end;
  diff text := case when p->>'difficulty' in ('easy','medium','hard') then p->>'difficulty' else 'medium' end;
  ctx text := ''; shape text; out jsonb; q jsonb; valid jsonb := '[]'; row jsonb;
begin
  perform private.need(u, private.r_staff());
  if private.juuid(p,'subject_id') is not null then ctx := ctx || 'Subject: ' || coalesce((select name from subjects where id = private.juuid(p,'subject_id')), '') || E'\n'; end if;
  if private.juuid(p,'chapter_id') is not null then ctx := ctx || 'Chapter: ' || coalesce((select name from chapters where id = private.juuid(p,'chapter_id')), '') || E'\n'; end if;
  if private.juuid(p,'topic_id') is not null then ctx := ctx || 'Topic: ' || coalesce((select name from topics where id = private.juuid(p,'topic_id')), '') || E'\n'; end if;
  if private.jt(p,'topic_text') is not null then ctx := ctx || 'Focus: ' || left(p->>'topic_text', 500) || E'\n'; end if;
  if private.jt(p,'source_text') is not null then ctx := ctx || E'Base the questions ONLY on this study material:\n"""\n' || left(p->>'source_text', 14000) || E'\n"""\n'; end if;
  if btrim(ctx) = '' then perform private.fail('Please choose a subject/chapter, type a topic, or upload a document for the AI.'); end if;
  shape := case typ
    when 'mcq_single' then '"options":[{"key":"A","text":"..."},{"key":"B","text":"..."},{"key":"C","text":"..."},{"key":"D","text":"..."}],"correct_answer":"B"'
    when 'mcq_multi' then '"options":[{"key":"A","text":"..."},{"key":"B","text":"..."},{"key":"C","text":"..."},{"key":"D","text":"..."}],"correct_answer":["A","C"]'
    when 'true_false' then '"correct_answer":"true"'
    when 'numerical' then '"correct_answer":{"value":12.5,"tolerance":0.01}'
    when 'short_answer' then '"correct_answer":["accepted answer","alternate spelling"]'
    else '"correct_answer":null' end;
  out := private.groq('You are an expert exam paper setter. You write accurate, unambiguous exam questions and always reply with valid JSON only.',
    ctx || format(E'Language: %s\nCreate %s %s questions of type "%s".%s\nReturn JSON exactly like: {"questions":[{"question_text":"...",%s,"explanation":"short reasoning","difficulty":"%s","tags":["tag"]}]}\nRules: factually correct, distinct, self-contained; exactly one correct option for mcq_single; never use "All of the above".',
      case when p->>'language' = 'hi' then 'Hindi' else 'English' end, n, diff, typ,
      case when private.jt(p,'instructions') is not null then E'\nExtra instructions: ' || left(p->>'instructions', 500) else '' end, shape, diff));
  for q in select value from jsonb_array_elements(case when jsonb_typeof(out->'questions') = 'array' then out->'questions' else '[]' end) loop
    begin
      row := jsonb_build_object('question_text', btrim(coalesce(q->>'question_text','')), 'question_type', typ, 'options', q->'options', 'correct_answer', q->'correct_answer',
        'explanation', q->>'explanation', 'difficulty', case when q->>'difficulty' in ('easy','medium','hard') then q->>'difficulty' else diff end,
        'tags', case when jsonb_typeof(q->'tags') = 'array' then q->'tags' else '[]' end);
      valid := valid || jsonb_build_array(private.prepare_question(row, null, u, s, false));
    exception when others then null;
    end;
  end loop;
  if jsonb_array_length(valid) = 0 then perform private.fail('The AI couldn''t produce usable questions this time. Please try again or change the topic.'); end if;
  return jsonb_build_object('questions', valid, 'message', format('%s generated. Review them, then save the ones you want.', private.plural(jsonb_array_length(valid), 'question')));
end $$;

create or replace function private.act_ai_parsesyllabus(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare txt text := btrim(coalesce(p->>'text','')); out jsonb;
begin
  perform private.need(u, private.r_admin());
  if length(txt) < 20 then perform private.fail('Please paste the syllabus text (at least a few lines).'); end if;
  out := private.groq('You convert syllabus text into a clean structured outline. Reply with JSON only.',
    E'Convert this syllabus into JSON: {"subjects":[{"name":"...","units":[{"name":"...","chapters":[{"name":"...","weightage":null,"topics":["..."]}]}]}]}. If the syllabus has no units, put the chapters directly in the subject as "chapters":[...]. Keep the original names, do not invent content.\n\nSYLLABUS:\n' || left(txt, 15000));
  if coalesce(jsonb_typeof(out->'subjects'), '') <> 'array' or jsonb_array_length(out->'subjects') = 0 then perform private.fail('The AI couldn''t find subjects in that text. Please check the text and try again.'); end if;
  return jsonb_build_object('subjects', out->'subjects');
end $$;

-- =====================================================================
--  QUESTIONS
-- =====================================================================
create or replace function private.act_questions_bulkcreate(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare it jsonb; d jsonb; f text; org uuid; saved int := 0; skipped int := 0; nid uuid; ids uuid[] := '{}'; st text := case when p->>'status' = 'approved' then 'approved' else 'draft' end;
begin
  perform private.need(u, private.r_staff());
  org := case when u.role = 'super_admin' then private.juuid(p,'organization_id')
              when private.juuid(p,'organization_id') is not null and private.in_scope(s, private.juuid(p,'organization_id')) then private.juuid(p,'organization_id')
              else u.organization_id end;
  if coalesce(jsonb_typeof(p->'items'), '') <> 'array' or jsonb_array_length(p->'items') = 0 then perform private.fail('Please select at least one question to save.'); end if;
  for it in select value from jsonb_array_elements(p->'items') limit 100 loop
    begin
      d := '{}';
      for f in select jsonb_array_elements_text(private.cfg('questions')->'fields') loop if it ? f then d := d || jsonb_build_object(f, it->f); end if; end loop;
      d := d || jsonb_build_object('organization_id', org, 'status', 'draft', 'source', coalesce(it->>'source','ai'),
        'subject_id', coalesce(private.juuid(p,'subject_id'), private.juuid(it,'subject_id')), 'chapter_id', coalesce(private.juuid(p,'chapter_id'), private.juuid(it,'chapter_id')),
        'topic_id', coalesce(private.juuid(p,'topic_id'), private.juuid(it,'topic_id')), 'marks', coalesce(private.jnum(it,'marks'), 1), 'negative_marks', coalesce(private.jnum(it,'negative_marks'), 0));
      d := private.prepare_question(d, null, u, s, true);
      insert into questions(organization_id, subject_id, chapter_id, topic_id, question_text, question_type, difficulty, language, options, correct_answer, explanation, marks, negative_marks, tags, source, status, created_by)
      select r.organization_id, r.subject_id, r.chapter_id, r.topic_id, r.question_text, r.question_type, r.difficulty, coalesce(r.language,'en'), r.options, r.correct_answer, r.explanation, r.marks, r.negative_marks, r.tags, r.source, 'draft', u.id
      from jsonb_populate_record(null::questions, d) r returning id into nid;
      if st = 'approved' then update questions set status = 'approved', reviewed_by = u.id, approved_at = now() where id = nid; end if;
      ids := ids || nid; saved := saved + 1;
    exception when others then skipped := skipped + 1;
    end;
  end loop;
  perform private.audit(u, 'bulk_create', 'questions', null, jsonb_build_object('count', saved));
  return jsonb_build_object('ids', to_jsonb(ids), 'message', format('%s saved as %s.%s', private.plural(saved, 'question'), st, case when skipped > 0 then format(' %s skipped (duplicate or incomplete).', skipped) else '' end));
end $$;

create or replace function private.act_questions_setstatus(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare ids uuid[] := private.uuids(p->'ids'); st text := p->>'status'; n int;
begin
  perform private.need(u, private.r_staff());
  if st not in ('draft','under_review','approved','rejected','archived','published') then perform private.fail('Invalid status.'); end if;
  if cardinality(ids) = 0 then perform private.fail('Please select at least one question.'); end if;
  update questions set status = st, updated_at = now(), review_note = private.jt(p,'review_note'),
         reviewed_by = case when st in ('approved','published','rejected') then u.id else reviewed_by end,
         approved_at = case when st in ('approved','published') then now() else approved_at end
   where id = any(ids) and (private.in_scope(s, organization_id) or (organization_id is null and u.role = 'super_admin'));
  get diagnostics n = row_count;
  if n = 0 then perform private.fail('You can''t change these questions.', '403'); end if;
  return jsonb_build_object('message', format('%s marked as %s.', private.plural(n,'question'), replace(st,'_',' ')));
end $$;

-- =====================================================================
--  EXAMS (staff)
-- =====================================================================
create or replace function private.scoped_exam(s uuid[], eid uuid) returns public.exams language plpgsql stable security definer set search_path = public as $$
declare e exams;
begin
  select * into e from exams where id = eid;
  if e.id is null or not private.in_scope(s, e.organization_id) then perform private.fail('Exam not found or you don''t have access.', '404'); end if;
  return e;
end $$;
create or replace function private.recalc_exam(eid uuid) returns void language sql security definer set search_path = public as $$
  update exams set total_questions = (select count(*) from exam_questions where exam_id = eid),
                   total_marks = coalesce((select sum(coalesce(eq.marks, q.marks, 1)) from exam_questions eq join questions q on q.id = eq.question_id where eq.exam_id = eid), 0),
                   updated_at = now() where id = eid
$$;
create or replace function private.exam_locked(eid uuid) returns void language plpgsql stable security definer set search_path = public as $$
begin if exists(select 1 from exam_attempts where exam_id = eid) then perform private.fail('Students have already attempted this exam, so its questions can''t be changed.'); end if; end $$;

create or replace function private.act_exam_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e exams;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'id','exam'));
  return jsonb_build_object('exam', to_jsonb(e) || jsonb_build_object('organization', private.nm_org(e.organization_id), 'exam_category', private.nm_cat(e.exam_category_id)),
    'questions', coalesce((select jsonb_agg(jsonb_build_object('id',eq.id,'order_index',eq.order_index,'marks',eq.marks,'section',eq.section,
        'question', jsonb_build_object('id',q.id,'question_text',q.question_text,'question_type',q.question_type,'difficulty',q.difficulty,'marks',q.marks,'status',q.status,'subject',private.nm_subject(q.subject_id)))
        order by eq.order_index nulls last) from exam_questions eq join questions q on q.id = eq.question_id where eq.exam_id = e.id), '[]'),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'assigned_at',a.assigned_at,'batch',private.nm_batch(a.batch_id),'user',private.nm_user(a.user_id)))
        from exam_assignments a where a.exam_id = e.id), '[]'),
    'attempts', (select count(*) from exam_attempts where exam_id = e.id));
end $$;

create or replace function private.act_exam_addquestions(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; ids uuid[] := private.uuids(p->'question_ids'); n int; mx int;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  perform private.exam_locked(e.id);
  if cardinality(ids) = 0 then perform private.fail('Please select at least one question.'); end if;
  select coalesce(max(order_index), 0) into mx from exam_questions where exam_id = e.id;
  insert into exam_questions(exam_id, question_id, marks, order_index, section)
  select e.id, q.id, coalesce(q.marks, 1), mx + row_number() over (order by array_position(ids, q.id)), private.jt(p,'section')
  from questions q where q.id = any(ids) and (private.in_scope(s, q.organization_id) or q.organization_id is null)
    and not exists(select 1 from exam_questions x where x.exam_id = e.id and x.question_id = q.id);
  get diagnostics n = row_count;
  perform private.recalc_exam(e.id);
  return jsonb_build_object('message', format('%s added to the exam.%s', private.plural(n,'question'), case when cardinality(ids) > n then format(' %s already in it or not available.', cardinality(ids) - n) else '' end));
end $$;

create or replace function private.act_exam_autopick(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; n int := least(200, greatest(1, coalesce(private.jint(p,'count'), 10))); ids uuid[];
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  perform private.exam_locked(e.id);
  ids := array(select q.id from questions q
    where q.status = any(case when private.jbool(p,'include_drafts') then array['draft','under_review','approved','published'] else array['approved','published'] end)
      and (private.in_scope(s, q.organization_id) or q.organization_id is null)
      and (private.juuid(p,'subject_id') is null or q.subject_id = private.juuid(p,'subject_id'))
      and (private.juuid(p,'chapter_id') is null or q.chapter_id = private.juuid(p,'chapter_id'))
      and (private.jt(p,'difficulty') is null or q.difficulty = p->>'difficulty')
      and not exists(select 1 from exam_questions x where x.exam_id = e.id and x.question_id = q.id)
    order by random() limit n);
  if cardinality(ids) = 0 then perform private.fail(case when private.jbool(p,'include_drafts') then 'No matching questions found in the bank.' else 'No approved questions match. Approve some questions first or tick ''Include draft questions''.' end); end if;
  perform private.act_exam_addquestions(u, s, jsonb_build_object('exam_id', e.id, 'question_ids', to_jsonb(ids), 'section', p->'section'));
  return jsonb_build_object('message', case when cardinality(ids) < n then format('Only %s matching questions were available; all were added.', cardinality(ids)) else format('%s added to the exam.', private.plural(cardinality(ids),'question')) end);
end $$;

create or replace function private.act_exam_updatequestion(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r exam_questions;
begin
  perform private.need(u, private.r_staff());
  select * into r from exam_questions where id = private.req_uuid(p,'id');
  if r.id is null then perform private.fail('This question is no longer in the exam.'); end if;
  perform private.scoped_exam(s, r.exam_id);
  if p ? 'marks' and not (private.jnum(p,'marks') > 0) then perform private.fail('Marks must be greater than 0.'); end if;
  update exam_questions set marks = case when p ? 'marks' then private.jnum(p,'marks') else marks end,
                            section = case when p ? 'section' then private.jt(p,'section') else section end,
                            order_index = case when p ? 'order_index' then private.jint(p,'order_index') else order_index end
   where id = r.id;
  perform private.recalc_exam(r.exam_id);
  return jsonb_build_object('message', 'Updated.');
end $$;

create or replace function private.act_exam_removequestion(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r exam_questions;
begin
  perform private.need(u, private.r_staff());
  select * into r from exam_questions where id = private.req_uuid(p,'id');
  if r.id is null then perform private.fail('This question was already removed.'); end if;
  perform private.scoped_exam(s, r.exam_id);
  perform private.exam_locked(r.exam_id);
  delete from exam_questions where id = r.id;
  perform private.recalc_exam(r.exam_id);
  return jsonb_build_object('message', 'Question removed from the exam.');
end $$;

create or replace function private.act_exam_assign(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; bids uuid[]; uids uuid[];
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  bids := array(select id from batches where id = any(private.uuids(p->'batch_ids')) and private.in_scope(s, organization_id)
                and not exists(select 1 from exam_assignments a where a.exam_id = e.id and a.batch_id = batches.id));
  uids := array(select id from users where id = any(private.uuids(p->'user_ids')) and role = 'student' and private.in_scope(s, organization_id)
                and not exists(select 1 from exam_assignments a where a.exam_id = e.id and a.user_id = users.id));
  if cardinality(private.uuids(p->'batch_ids')) + cardinality(private.uuids(p->'user_ids')) = 0 then perform private.fail('Please choose at least one batch or student.'); end if;
  if cardinality(bids) + cardinality(uids) = 0 then perform private.fail('These batches/students are already assigned to this exam.'); end if;
  insert into exam_assignments(exam_id, batch_id, assigned_by) select e.id, x, u.id from unnest(bids) x;
  insert into exam_assignments(exam_id, user_id, assigned_by) select e.id, x, u.id from unnest(uids) x;
  if e.status in ('scheduled','live') then
    perform private.notify(private.students_of(bids) || uids, 'New exam assigned', format('"%s" has been assigned to you.%s', e.title, coalesce(' Opens ' || private.ist(e.start_time) || '.', '')), 'exam', e.id, 'exam', 'my-exams.html');
  end if;
  return jsonb_build_object('message', format('Assigned to %s and %s.', private.plural(cardinality(bids),'batch'), private.plural(cardinality(uids),'student')));
end $$;

create or replace function private.act_exam_unassign(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r exam_assignments;
begin
  perform private.need(u, private.r_staff());
  select * into r from exam_assignments where id = private.req_uuid(p,'id');
  if r.id is null then perform private.fail('This assignment was already removed.'); end if;
  perform private.scoped_exam(s, r.exam_id);
  delete from exam_assignments where id = r.id;
  return jsonb_build_object('message', 'Assignment removed.');
end $$;

create or replace function private.act_exam_setstatus(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; st text := p->>'status'; studs uuid[];
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  if st not in ('draft','scheduled','live','completed','archived') then perform private.fail('Invalid status.'); end if;
  if st in ('scheduled','live') then
    if coalesce(e.total_questions, 0) = 0 then perform private.fail('Add at least one question before publishing this exam.'); end if;
    if e.duration_minutes is null then perform private.fail('Please set the exam duration before publishing.'); end if;
    if st = 'scheduled' and e.start_time is null then perform private.fail('Set an opening time (Settings) to schedule the exam, or choose ''Go live now''.'); end if;
    if not exists(select 1 from exam_assignments where exam_id = e.id) then perform private.fail('Assign the exam to at least one batch or student before publishing.'); end if;
  end if;
  update exams set status = st, updated_at = now(),
         published_by = case when st in ('scheduled','live') then u.id else published_by end,
         published_at = case when st in ('scheduled','live') then now() else published_at end
   where id = e.id;
  if st in ('scheduled','live') and e.status not in ('scheduled','live') then
    studs := private.students_of(array(select batch_id from exam_assignments where exam_id = e.id and batch_id is not null))
             || array(select user_id from exam_assignments where exam_id = e.id and user_id is not null);
    perform private.notify(studs, case when st = 'live' then 'Exam is live' else 'Exam scheduled' end,
      format('"%s" %s', e.title, case when st = 'live' then 'is now open.' else 'opens ' || private.ist(e.start_time) || '.' end), 'exam', e.id, 'exam', 'my-exams.html');
  end if;
  perform private.audit(u, 'exam_status', 'exams', e.id::text, jsonb_build_object('status', st), jsonb_build_object('status', e.status));
  return jsonb_build_object('message', case st when 'draft' then 'Exam moved back to draft.' when 'scheduled' then 'Exam scheduled. Students can start at the opening time.'
    when 'live' then 'Exam is now live for assigned students.' when 'completed' then 'Exam ended. No new attempts are allowed.' else 'Exam archived.' end);
end $$;

create or replace function private.act_exam_duplicate(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; nid uuid;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  insert into exams(organization_id, exam_category_id, title, description, duration_minutes, attempt_limit, shuffle_questions, shuffle_options, show_result_immediately,
                    negative_marking, instructions, pass_percentage, settings, blueprint, status, created_by)
  values (e.organization_id, e.exam_category_id, e.title || ' (copy)', e.description, e.duration_minutes, e.attempt_limit, e.shuffle_questions, e.shuffle_options,
          e.show_result_immediately, e.negative_marking, e.instructions, e.pass_percentage, e.settings, e.blueprint, 'draft', u.id) returning id into nid;
  insert into exam_questions(exam_id, question_id, order_index, marks, section, is_mandatory) select nid, question_id, order_index, marks, section, is_mandatory from exam_questions where exam_id = e.id;
  perform private.recalc_exam(nid);
  return jsonb_build_object('id', nid, 'message', 'Exam duplicated as a new draft.');
end $$;

create or replace function private.act_exam_results(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e exams;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  return jsonb_build_object('exam', to_jsonb(e),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'total_score',r.total_score,'max_score',r.max_score,'percentage',r.percentage,'rank',r.rank,'percentile',r.percentile,
        'accuracy',r.accuracy,'is_visible',r.is_visible,'released_at',r.released_at,'time_spent_seconds',r.time_spent_seconds,'created_at',r.created_at,
        'subject_wise', r.subject_wise, 'user', private.nm_user(r.user_id),
        'attempt', jsonb_build_object('id',a.id,'attempt_number',a.attempt_number,'status',a.status,'tab_switches',a.tab_switches,'submitted_at',a.submitted_at))
        order by r.rank nulls last) from results r join exam_attempts a on a.id = r.exam_attempt_id where r.exam_id = e.id), '[]'),
    'inProgress', (select count(*) from exam_attempts where exam_id = e.id and status = 'in_progress'));
end $$;

create or replace function private.act_exam_releaseresults(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; vis boolean := coalesce(private.jbool(p,'visible'), false); ids uuid[];
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  with up as (update results set is_visible = vis, released_at = case when vis then now() end, updated_at = now() where exam_id = e.id returning user_id)
  select coalesce(array_agg(user_id), '{}') into ids from up;
  if vis then perform private.notify(ids, 'Result published', format('Your result for "%s" is now available.', e.title), 'result', e.id, 'exam', 'results.html'); end if;
  return jsonb_build_object('message', case when vis then format('Results released to %s.', private.plural(cardinality(ids),'student')) else 'Results hidden from students.' end);
end $$;

-- =====================================================================
--  EXAM TAKING (students) – answer keys never leave the database
-- =====================================================================
create or replace function private.exam_window(e public.exams) returns text language sql stable as $$
  select case when e.status = 'completed' or (e.end_time is not null and e.end_time < now()) then 'closed'
              when e.start_time is not null and e.start_time > now() then 'upcoming'
              when e.status = 'scheduled' and e.start_time is null then 'upcoming'
              when e.status in ('scheduled','live') then 'open' else 'closed' end
$$;
create or replace function private.attempt_deadline(e public.exams, a public.exam_attempts) returns timestamptz language sql stable as $$
  select least(a.started_at + make_interval(mins => coalesce(e.duration_minutes, 60)), coalesce(e.end_time, 'infinity'::timestamptz))
$$;
create or replace function private.is_assigned(uid uuid, eid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from exam_assignments where exam_id = eid and (user_id = uid or batch_id = any(private.my_batches(uid))))
$$;

create or replace function private.student_exams(u public.users) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x->>'sort')), '[]') from (
    select to_jsonb(e) - 'settings' - 'blueprint' || jsonb_build_object('exam_category', private.nm_cat(e.exam_category_id),
      'attempts_used', st.done, 'active_attempt', st.active,
      'state', case when private.exam_window(e) = 'open' and st.active is not null then 'in_progress'
                    when private.exam_window(e) = 'open' and st.done >= coalesce(e.attempt_limit, 1) then 'attempted'
                    else private.exam_window(e) end,
      'sort', coalesce(e.start_time, e.created_at)::text) x
    from exams e
    cross join lateral (select count(*) filter (where a.status not in ('in_progress','cancelled')) done,
                               (array_agg(a.id) filter (where a.status = 'in_progress'))[1] active
                        from exam_attempts a where a.exam_id = e.id and a.user_id = u.id) st
    where e.status in ('scheduled','live','completed') and private.is_assigned(u.id, e.id)) q
$$;
create or replace function private.act_student_exams(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable as $$
begin perform private.need(u, array['student']); return jsonb_build_object('rows', private.student_exams(u)); end $$;

create or replace function private.finalize_attempt(e public.exams, a public.exam_attempts, ans jsonb, auto boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare mx numeric; sc numeric; correct int; attempted int; manual int; grading jsonb; sw jsonb; cw jsonb; tw jsonb; pct numeric; spent int; vis boolean;
begin
  create temp table if not exists _g (qid uuid, mx numeric, st text, m numeric, sn text, cn text, tn text) on commit drop;
  truncate _g;
  insert into _g
  select q.id, coalesce(eq.marks, q.marks, 1), g.st,
         case g.st when 'correct' then coalesce(eq.marks, q.marks, 1) when 'wrong' then case when e.negative_marking then -coalesce(private.jnum(e.settings,'negative_marks'), q.negative_marks, 0) else 0 end else 0 end,
         coalesce(sj.name, 'General'), coalesce(ch.name, 'General'), coalesce(tp.name, 'General')
  from exam_questions eq join questions q on q.id = eq.question_id
  left join subjects sj on sj.id = q.subject_id left join chapters ch on ch.id = q.chapter_id left join topics tp on tp.id = q.topic_id
  cross join lateral (select private.grade(q.question_type, q.options, q.correct_answer, ans->(q.id::text)) st) g
  where eq.exam_id = e.id;
  select coalesce(sum(_g.mx),0), coalesce(sum(_g.m),0), count(*) filter (where _g.st='correct'), count(*) filter (where _g.st <> 'unattempted'), count(*) filter (where _g.st='manual'),
         coalesce(jsonb_object_agg(_g.qid, jsonb_build_object('status',_g.st,'marks',_g.m,'max',_g.mx)), '{}')
    into mx, sc, correct, attempted, manual, grading from _g;
  select coalesce(jsonb_object_agg(k, v), '{}') into sw from (select sn k, jsonb_build_object('score',sum(m),'max',sum(_g.mx),'correct',count(*) filter (where st='correct'),'wrong',count(*) filter (where st='wrong'),'unattempted',count(*) filter (where st='unattempted')) v from _g group by sn) z;
  select coalesce(jsonb_object_agg(k, v), '{}') into cw from (select cn k, jsonb_build_object('score',sum(m),'max',sum(_g.mx),'correct',count(*) filter (where st='correct'),'wrong',count(*) filter (where st='wrong'),'unattempted',count(*) filter (where st='unattempted')) v from _g group by cn) z;
  select coalesce(jsonb_object_agg(k, v), '{}') into tw from (select tn k, jsonb_build_object('score',sum(m),'max',sum(_g.mx),'correct',count(*) filter (where st='correct'),'wrong',count(*) filter (where st='wrong'),'unattempted',count(*) filter (where st='unattempted')) v from _g group by tn) z;
  pct := case when mx > 0 then round(sc / mx * 100, 2) else 0 end;
  spent := least(extract(epoch from now() - a.started_at)::int, coalesce(e.duration_minutes, 60) * 60 + 60);
  vis := coalesce(e.show_result_immediately, false) and manual = 0;
  update exam_attempts set status = case when auto then 'auto_submitted' when manual > 0 then 'submitted' else 'evaluated' end,
         submitted_at = now(), answers = ans, score = sc, max_score = mx, percentage = pct, time_spent_seconds = spent,
         auto_save_data = coalesce(auto_save_data, '{}') || jsonb_build_object('grading', grading, 'pending_manual', manual), updated_at = now()
   where id = a.id;
  insert into results(exam_attempt_id, user_id, exam_id, total_score, max_score, percentage, accuracy, subject_wise, chapter_wise, topic_wise, is_visible, released_at, time_spent_seconds)
  values (a.id, a.user_id, e.id, sc, mx, pct, case when attempted > 0 then round(correct::numeric / attempted * 100, 2) else 0 end, sw, cw, tw, vis, case when vis then now() end, spent)
  on conflict (exam_attempt_id) do update set total_score = excluded.total_score, max_score = excluded.max_score, percentage = excluded.percentage, accuracy = excluded.accuracy,
     subject_wise = excluded.subject_wise, chapter_wise = excluded.chapter_wise, topic_wise = excluded.topic_wise, is_visible = excluded.is_visible,
     released_at = excluded.released_at, time_spent_seconds = excluded.time_spent_seconds, updated_at = now();
  perform private.recalc_ranks(e.id);
  perform private.log_event(a.user_id, 'completion', a.id, jsonb_build_object('exam_id', e.id, 'score', sc, 'max', mx));
  perform private.touch(a.user_id);
  return jsonb_build_object('score', sc, 'max', mx, 'pct', pct, 'manual', manual, 'visible', vis);
end $$;

create or replace function private.recalc_ranks(eid uuid) returns void language sql security definer set search_path = public as $$
  update results r set rank = x.rk, percentile = round(((x.n - x.rk + 1)::numeric / x.n) * 100, 2)
    from (select id, rank() over (order by total_score desc) rk, count(*) over () n from results where exam_id = eid) x where r.id = x.id;
  update exam_attempts a set rank = r.rank, percentile = r.percentile from results r where r.exam_attempt_id = a.id and r.exam_id = eid;
$$;

create or replace function private.act_student_startexam(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; a exam_attempts; used int; ord jsonb; opt jsonb := '{}'; qs jsonb; w text;
begin
  perform private.need(u, array['student']);
  select * into e from exams where id = private.req_uuid(p,'exam_id','exam');
  if e.id is null or e.status not in ('scheduled','live','completed') or not private.is_assigned(u.id, e.id) then perform private.fail('This exam isn''t available to you.', '404'); end if;
  select * into a from exam_attempts where exam_id = e.id and user_id = u.id and status = 'in_progress' order by started_at desc limit 1;
  if a.id is not null and now() > private.attempt_deadline(e, a) + interval '60 seconds' then
    perform private.finalize_attempt(e, a, coalesce(a.answers, '{}'), true);
    return jsonb_build_object('_error', 'Your time for this exam ran out. Your saved answers were submitted automatically.', '_code', '409');
  end if;
  if a.id is null then
    w := private.exam_window(e);
    if w = 'upcoming' then perform private.fail('This exam hasn''t started yet.' || coalesce(' It opens at ' || private.ist(e.start_time) || '.', '')); end if;
    if w = 'closed' then perform private.fail('This exam has ended.'); end if;
    select count(*) into used from exam_attempts where exam_id = e.id and user_id = u.id and status <> 'cancelled';
    if used >= coalesce(e.attempt_limit, 1) then perform private.fail(format('You have used all %s for this exam.', private.plural(coalesce(e.attempt_limit,1), 'attempt'))); end if;
    if not exists(select 1 from exam_questions where exam_id = e.id) then perform private.fail('This exam has no questions yet. Please contact your teacher.'); end if;
    select jsonb_agg(question_id order by case when e.shuffle_questions then random() else coalesce(order_index, 0) end) into ord from exam_questions where exam_id = e.id;
    if e.shuffle_options then
      select coalesce(jsonb_object_agg(q.id, (select jsonb_agg(o->'key' order by random()) from jsonb_array_elements(private.norm_options(q.options)) o)), '{}') into opt
        from exam_questions eq join questions q on q.id = eq.question_id where eq.exam_id = e.id and private.is_mcq(q.question_type);
    end if;
    insert into exam_attempts(exam_id, user_id, attempt_number, status, started_at, answers, auto_save_data, user_agent)
      values (e.id, u.id, used + 1, 'in_progress', now(), '{}', jsonb_build_object('order', ord, 'opt', opt), left(p->>'user_agent', 300)) returning * into a;
    perform private.log_event(u.id, 'session_start', a.id, jsonb_build_object('exam_id', e.id));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', q.id, 'text', q.question_text, 'type', q.question_type, 'section', eq.section,
      'marks', coalesce(eq.marks, q.marks, 1), 'negative', case when e.negative_marking then coalesce(private.jnum(e.settings,'negative_marks'), q.negative_marks, 0) else 0 end,
      'options', case when q.question_type = 'true_false' then '[{"key":"true","text":"True"},{"key":"false","text":"False"}]'::jsonb
                      when a.auto_save_data->'opt' ? q.id::text then (select jsonb_agg(o order by array_position(private.jarr(a.auto_save_data->'opt'->(q.id::text)), o->>'key')) from jsonb_array_elements(private.norm_options(q.options)) o)
                      else private.norm_options(q.options) end,
      'media', coalesce((select jsonb_agg(jsonb_build_object('type', m.media_type, 'url', m.file_path) order by m.order_index) from question_media m where m.question_id = q.id and m.file_path ~* '^https?://'), '[]'))
    order by o.n), '[]') into qs
  from jsonb_array_elements_text(a.auto_save_data->'order') with ordinality o(qid, n)
  join exam_questions eq on eq.exam_id = e.id and eq.question_id = o.qid::uuid join questions q on q.id = eq.question_id;
  return jsonb_build_object(
    'attempt', jsonb_build_object('id', a.id, 'attempt_number', a.attempt_number, 'answers', coalesce(a.answers,'{}'), 'tab_switches', coalesce(a.tab_switches,0), 'flagged', coalesce(a.auto_save_data->'flagged','[]'), 'qtime', coalesce(a.auto_save_data->'qtime','{}')),
    'exam', jsonb_build_object('id', e.id, 'title', e.title, 'instructions', e.instructions, 'total_marks', e.total_marks, 'duration_minutes', e.duration_minutes, 'negative_marking', e.negative_marking),
    'remaining_seconds', greatest(0, floor(extract(epoch from private.attempt_deadline(e, a) - now())))::int,
    'questions', qs);
end $$;

create or replace function private.own_attempt(u public.users, aid uuid) returns public.exam_attempts language plpgsql stable security definer set search_path = public as $$
declare a exam_attempts;
begin
  select * into a from exam_attempts where id = aid;
  if a.id is null or a.user_id <> u.id then perform private.fail('This attempt was not found.', '404'); end if;
  return a;
end $$;

create or replace function private.act_student_saveanswers(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a exam_attempts; e exams;
begin
  perform private.need(u, array['student']);
  a := private.own_attempt(u, private.req_uuid(p,'attempt_id','attempt'));
  if a.status <> 'in_progress' then perform private.fail('This exam has already been submitted.', '409'); end if;
  select * into e from exams where id = a.exam_id;
  if now() > private.attempt_deadline(e, a) + interval '60 seconds' then perform private.fail('Time is over for this exam.', '409'); end if;
  update exam_attempts set answers = case when jsonb_typeof(p->'answers') = 'object' then p->'answers' else answers end,
         tab_switches = greatest(coalesce(tab_switches,0), coalesce(private.jint(p,'tab_switches'),0)),
         auto_save_data = coalesce(auto_save_data,'{}') || jsonb_build_object('flagged', coalesce(p->'flagged','[]'), 'saved_at', now())
                          || case when jsonb_typeof(p->'qtime') = 'object' then jsonb_build_object('qtime', p->'qtime') else '{}'::jsonb end, updated_at = now()
   where id = a.id;
  return jsonb_build_object('saved_at', now(), 'remaining_seconds', greatest(0, floor(extract(epoch from private.attempt_deadline(e, a) - now())))::int);
end $$;

create or replace function private.act_student_submitexam(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a exam_attempts; e exams; late boolean; r jsonb;
begin
  perform private.need(u, array['student']);
  a := private.own_attempt(u, private.req_uuid(p,'attempt_id','attempt'));
  if a.status <> 'in_progress' then perform private.fail('This exam has already been submitted.', '409'); end if;
  select * into e from exams where id = a.exam_id;
  late := now() > private.attempt_deadline(e, a) + interval '90 seconds';
  update exam_attempts set tab_switches = greatest(coalesce(tab_switches,0), coalesce(private.jint(p,'tab_switches'),0)),
         auto_save_data = coalesce(auto_save_data,'{}') || case when jsonb_typeof(p->'qtime') = 'object' then jsonb_build_object('qtime', p->'qtime') else '{}'::jsonb end
   where id = a.id returning * into a;
  r := private.finalize_attempt(e, a, case when late or coalesce(jsonb_typeof(p->'answers'), '') <> 'object' then coalesce(a.answers,'{}') else p->'answers' end, coalesce(private.jbool(p,'auto'), false) or late);
  return jsonb_build_object('message', case when late then 'Time was over, so your last auto-saved answers were submitted.' else 'Your exam has been submitted successfully.' end,
    'show_result', (r->>'visible')::boolean, 'score', case when (r->>'visible')::boolean then r->'score' end, 'max', case when (r->>'visible')::boolean then r->'max' end,
    'percentage', case when (r->>'visible')::boolean then r->'pct' end, 'pending_manual', r->'manual', 'result_id', (select id from results where exam_attempt_id = a.id));
end $$;

-- =====================================================================
--  RESULTS
-- =====================================================================
create or replace function private.verify_code(rid uuid) returns text language sql stable security definer set search_path = public as
$$ select upper(left(md5(rid::text || coalesce(private.setting('verify_secret'), 'x')), 10)) $$;

create or replace function private.act_student_results(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform private.need(u, array['student']);
  return jsonb_build_object(
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'total_score',r.total_score,'max_score',r.max_score,'percentage',r.percentage,'rank',r.rank,'percentile',r.percentile,
              'accuracy',r.accuracy,'released_at',r.released_at,'time_spent_seconds',r.time_spent_seconds,'created_at',r.created_at,
              'exam',(select jsonb_build_object('id',e.id,'title',e.title,'pass_percentage',e.pass_percentage) from exams e where e.id = r.exam_id)) order by r.created_at desc)
             from results r where r.user_id = u.id and r.is_visible), '[]'),
    'pending', (select count(*) from results where user_id = u.id and not coalesce(is_visible,false)));
end $$;

create or replace function private.act_result_detail(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r results; e exams; a exam_attempts; ans jsonb; gr jsonb;
begin
  select * into r from results where id = private.req_uuid(p,'id','result');
  if r.id is null then perform private.fail('Result not found.', '404'); end if;
  select * into e from exams where id = r.exam_id;
  select * into a from exam_attempts where id = r.exam_attempt_id;
  if u.role = 'student' then
    if r.user_id <> u.id or not coalesce(r.is_visible,false) then perform private.fail('This result hasn''t been released yet.', '403'); end if;
  elsif not private.in_scope(s, e.organization_id) then perform private.fail('You don''t have access to this result.', '403'); end if;
  ans := coalesce(a.answers, '{}'); gr := coalesce(a.auto_save_data->'grading', '{}');
  return jsonb_build_object(
    'result', to_jsonb(r) || jsonb_build_object('exam', jsonb_build_object('id',e.id,'title',e.title,'pass_percentage',e.pass_percentage,'negative_marking',e.negative_marking),
        'organization', private.nm_org(e.organization_id), 'user', private.nm_user(r.user_id), 'verify_code', private.verify_code(r.id),
        'attempt', jsonb_build_object('id',a.id,'attempt_number',a.attempt_number,'tab_switches',a.tab_switches,'started_at',a.started_at,'submitted_at',a.submitted_at,'status',a.status)),
    'review', coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'text',q.question_text,'type',q.question_type,'options',private.norm_options(q.options),
        'correct_answer',q.correct_answer,'explanation',q.explanation,'your_answer',ans->(q.id::text),'time_seconds',private.jint(a.auto_save_data->'qtime', q.id::text)) ||
        coalesce(gr->(q.id::text), jsonb_build_object('status', private.grade(q.question_type,q.options,q.correct_answer,ans->(q.id::text)), 'marks', 0, 'max', coalesce(eq.marks,q.marks,1)))
        order by eq.order_index nulls last) from exam_questions eq join questions q on q.id = eq.question_id where eq.exam_id = r.exam_id), '[]'),
    'can_grade', u.role <> 'student');
end $$;

create or replace function private.act_result_grademanual(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r results; e exams; a exam_attempts; gr jsonb; k text; v jsonb; m numeric; g jsonb; sc numeric; pend int; pct numeric;
begin
  perform private.need(u, private.r_staff());
  select * into r from results where id = private.req_uuid(p,'id','result');
  select * into e from exams where id = r.exam_id;
  if r.id is null or not private.in_scope(s, e.organization_id) then perform private.fail('Result not found.', '404'); end if;
  select * into a from exam_attempts where id = r.exam_attempt_id;
  gr := coalesce(a.auto_save_data->'grading', '{}');
  for k, v in select key, value from jsonb_each(case when jsonb_typeof(p->'awards') = 'object' then p->'awards' else '{}' end) loop
    g := gr->k; continue when g is null;
    begin m := (v #>> '{}')::numeric; exception when others then m := null; end;
    if m is null or m < 0 or m > (g->>'max')::numeric then perform private.fail(format('Awarded marks must be between 0 and %s.', g->>'max')); end if;
    gr := gr || jsonb_build_object(k, g || jsonb_build_object('marks', m, 'status', case when m >= (g->>'max')::numeric then 'correct' when m > 0 then 'partial' else 'wrong' end, 'graded_by', u.id));
  end loop;
  select coalesce(sum((value->>'marks')::numeric), 0), count(*) filter (where value->>'status' = 'manual') into sc, pend from jsonb_each(gr);
  pct := case when r.max_score > 0 then round(sc / r.max_score * 100, 2) else 0 end;
  update exam_attempts set score = sc, percentage = pct, status = case when pend > 0 then 'submitted' else 'evaluated' end,
         auto_save_data = auto_save_data || jsonb_build_object('grading', gr, 'pending_manual', pend) where id = a.id;
  update results set total_score = sc, percentage = pct, updated_at = now() where id = r.id;
  perform private.recalc_ranks(r.exam_id);
  return jsonb_build_object('message', case when pend > 0 then format('Marks saved. %s still need grading.', private.plural(pend, 'answer')) else 'Grading complete. You can now release the result.' end);
end $$;

-- public: anyone can verify a scorecard with its code (used by the QR code)
create or replace function private.a_verify(p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r results; rid uuid := private.juuid(p,'id');
begin
  select * into r from results where id = rid;
  if r.id is null or upper(coalesce(p->>'code','')) <> private.verify_code(r.id) or not coalesce(r.is_visible,false) then
    return jsonb_build_object('ok', true, 'valid', false);
  end if;
  return jsonb_build_object('ok', true, 'valid', true, 'result', jsonb_build_object(
    'student', (select full_name from users where id = r.user_id), 'roll_number', (select roll_number from users where id = r.user_id),
    'exam', (select title from exams where id = r.exam_id), 'organization', (select o.name from exams e join organizations o on o.id = e.organization_id where e.id = r.exam_id),
    'score', r.total_score, 'max', r.max_score, 'percentage', r.percentage, 'rank', r.rank, 'date', r.created_at));
end $$;

-- =====================================================================
--  ASSIGNMENTS
-- =====================================================================
create or replace function private.scoped_assignment(s uuid[], aid uuid) returns public.assignments language plpgsql stable security definer set search_path = public as $$
declare a assignments;
begin
  select * into a from assignments where id = aid;
  if a.id is null or not private.in_scope(s, a.organization_id) then perform private.fail('Assignment not found or you don''t have access.', '404'); end if;
  return a;
end $$;
create or replace function private.act_assignment_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a assignments;
begin
  perform private.need(u, private.r_staff());
  a := private.scoped_assignment(s, private.req_uuid(p,'id','assignment'));
  return jsonb_build_object('assignment', to_jsonb(a),
    'batches', coalesce((select jsonb_agg(private.nm_batch(batch_id)) from assignment_batches where assignment_id = a.id), '[]'),
    'attachments', coalesce((select jsonb_agg(to_jsonb(x)) from assignment_attachments x where x.assignment_id = a.id), '[]'));
end $$;
create or replace function private.act_assignment_setbatches(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a assignments; ok uuid[]; before uuid[];
begin
  perform private.need(u, private.r_staff());
  a := private.scoped_assignment(s, private.req_uuid(p,'assignment_id','assignment'));
  ok := array(select id from batches where id = any(private.uuids(p->'batch_ids')) and private.in_scope(s, organization_id));
  before := array(select batch_id from assignment_batches where assignment_id = a.id);
  delete from assignment_batches where assignment_id = a.id;
  insert into assignment_batches(assignment_id, batch_id) select a.id, x from unnest(ok) x;
  if a.status = 'published' then
    perform private.notify(private.students_of(array(select x from unnest(ok) x where not (x = any(before)))), 'New assignment', format('"%s" has been assigned to you.', a.title), 'assignment', a.id, 'assignment', 'my-assignments.html');
  end if;
  return jsonb_build_object('message', format('Assignment linked to %s.', private.plural(cardinality(ok), 'batch')));
end $$;
create or replace function private.act_assignment_addattachment(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a assignments;
begin
  perform private.need(u, private.r_staff());
  a := private.scoped_assignment(s, private.req_uuid(p,'assignment_id','assignment'));
  if not (coalesce(p->>'file_path','') like 'assignment-attachments/' || u.id || '/%' or coalesce(p->>'file_path','') like 'assignment-files/' || u.id || '/%'
          or coalesce(p->>'file_path','') like 'assignment/' || u.id || '/%') then perform private.fail('Please upload the file again.'); end if;
  insert into assignment_attachments(assignment_id, file_path, file_name, file_type) values (a.id, p->>'file_path', private.jt(p,'file_name'), private.jt(p,'file_type'));
  return jsonb_build_object('message', 'Attachment added.');
end $$;
create or replace function private.act_assignment_removeattachment(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare at assignment_attachments;
begin
  perform private.need(u, private.r_staff());
  select * into at from assignment_attachments where id = private.req_uuid(p,'id');
  if at.id is null then perform private.fail('Attachment already removed.'); end if;
  perform private.scoped_assignment(s, at.assignment_id);
  delete from assignment_attachments where id = at.id;
  return jsonb_build_object('message', 'Attachment removed.');
end $$;
create or replace function private.act_assignment_setstatus(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a assignments; st text := p->>'status'; bids uuid[];
begin
  perform private.need(u, private.r_staff());
  a := private.scoped_assignment(s, private.req_uuid(p,'assignment_id','assignment'));
  if st not in ('draft','published','closed') then perform private.fail('Invalid status.'); end if;
  bids := array(select batch_id from assignment_batches where assignment_id = a.id);
  if st = 'published' and cardinality(bids) = 0 then perform private.fail('Choose at least one batch (and save) before publishing this assignment.'); end if;
  update assignments set status = st, published_at = case when st = 'published' then coalesce(published_at, now()) else published_at end, updated_at = now() where id = a.id;
  if st = 'published' and coalesce(a.status,'') <> 'published' then
    perform private.notify(private.students_of(bids), 'New assignment', format('"%s"%s', a.title, coalesce(' – due ' || private.ist(a.deadline), '')), 'assignment', a.id, 'assignment', 'my-assignments.html');
  end if;
  return jsonb_build_object('message', case st when 'draft' then 'Assignment moved to draft.' when 'published' then 'Assignment published to students.' else 'Assignment closed. Students can no longer submit.' end);
end $$;
create or replace function private.act_assignment_submissions(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a assignments;
begin
  perform private.need(u, private.r_staff());
  a := private.scoped_assignment(s, private.req_uuid(p,'assignment_id','assignment'));
  return jsonb_build_object('assignment', to_jsonb(a), 'rows', coalesce((select jsonb_agg(to_jsonb(x) || jsonb_build_object('user', private.nm_user(x.user_id),
      'files', coalesce((select jsonb_agg(to_jsonb(f)) from submission_files f where f.submission_id = x.id), '[]')) order by x.submitted_at desc)
    from assignment_submissions x where x.assignment_id = a.id), '[]'));
end $$;
create or replace function private.act_assignment_evaluate(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare x assignment_submissions; a assignments; st text := coalesce(p->>'status','evaluated'); m numeric := private.jnum(p,'marks_obtained');
begin
  perform private.need(u, private.r_staff());
  select * into x from assignment_submissions where id = private.req_uuid(p,'id','submission');
  if x.id is null then perform private.fail('Submission not found.', '404'); end if;
  a := private.scoped_assignment(s, x.assignment_id);
  if st not in ('evaluated','returned','needs_correction','under_review') then perform private.fail('Invalid status.'); end if;
  if st = 'evaluated' and m is null then perform private.fail('Please enter the marks.'); end if;
  if m is not null and (m < 0 or (a.max_marks is not null and m > a.max_marks)) then perform private.fail(format('Marks must be between 0 and %s.', coalesce(a.max_marks::text, 'the maximum'))); end if;
  update assignment_submissions set marks_obtained = m, feedback = private.jt(p,'feedback'), status = st, evaluated_by = u.id, evaluated_at = now(), updated_at = now() where id = x.id;
  perform private.notify(array[x.user_id], case when st = 'needs_correction' then 'Assignment needs correction' else 'Assignment reviewed' end,
    format('"%s"%s%s', a.title, coalesce(' – ' || m || '/' || coalesce(a.max_marks::text,'?'), ''), coalesce(': ' || left(private.jt(p,'feedback'), 120), '')), 'assignment', a.id, 'assignment', 'my-assignments.html');
  return jsonb_build_object('message', 'Evaluation saved and the student has been notified.');
end $$;

create or replace function private.student_assignments(u public.users) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(a) - 'settings' || jsonb_build_object(
      'attachments', coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'file_name',f.file_name,'file_path',f.file_path)) from assignment_attachments f where f.assignment_id = a.id), '[]'),
      'my_submission', (select to_jsonb(x) || jsonb_build_object('files', coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'file_name',f.file_name,'file_path',f.file_path)) from submission_files f where f.submission_id = x.id), '[]'))
                        from assignment_submissions x where x.assignment_id = a.id and x.user_id = u.id order by x.attempt_number desc limit 1),
      'submission_count', (select count(*) from assignment_submissions x where x.assignment_id = a.id and x.user_id = u.id))
    order by a.deadline nulls last), '[]')
  from assignments a
  where a.status in ('published','closed') and exists(select 1 from assignment_batches b where b.assignment_id = a.id and b.batch_id = any(private.my_batches(u.id)))
$$;
create or replace function private.act_student_assignments(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable as $$
begin perform private.need(u, array['student']); return jsonb_build_object('rows', private.student_assignments(u)); end $$;

create or replace function private.act_student_submitassignment(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a jsonb; n int; last jsonb; late boolean; sid uuid; f jsonb; content text := private.jt(p,'content'); link text := private.jt(p,'link_url');
begin
  perform private.need(u, array['student']);
  select x into a from jsonb_array_elements(private.student_assignments(u)) x where x->>'id' = p->>'assignment_id';
  if a is null then perform private.fail('This assignment isn''t available to you.', '404'); end if;
  if a->>'status' = 'closed' then perform private.fail('This assignment is closed and no longer accepts submissions.'); end if;
  if content is null and link is null and coalesce(jsonb_array_length(case when jsonb_typeof(p->'files') = 'array' then p->'files' end), 0) = 0 then
    perform private.fail('Please write an answer, add a link, or attach a file before submitting.');
  end if;
  if link is not null and link !~* '^https?://\S+$' then perform private.fail('Please enter a valid link starting with http:// or https://'); end if;
  n := (a->>'submission_count')::int; last := a->'my_submission';
  if n > 0 and coalesce(last->>'status','') not in ('needs_correction','returned') then
    if not coalesce((a->>'allow_resubmit')::boolean, false) then perform private.fail('You''ve already submitted this assignment and resubmission isn''t allowed.'); end if;
    if n > coalesce((a->>'max_resubmits')::int, 0) then perform private.fail(format('You''ve used all %s for this assignment.', private.plural(coalesce((a->>'max_resubmits')::int,0), 'resubmission'))); end if;
  end if;
  late := a->>'deadline' is not null and (a->>'deadline')::timestamptz < now();
  insert into assignment_submissions(assignment_id, user_id, attempt_number, status, content, link_url, submitted_at)
    values ((a->>'id')::uuid, u.id, n + 1, case when late then 'late' when n > 0 then 'resubmitted' else 'submitted' end, content, link, now()) returning id into sid;
  for f in select value from jsonb_array_elements(case when jsonb_typeof(p->'files') = 'array' then p->'files' else '[]' end) limit 10 loop
    if not (coalesce(f->>'path','') like 'student-submissions/' || u.id || '/%' or coalesce(f->>'path','') like 'submission/' || u.id || '/%') then perform private.fail('One of the files is invalid. Please upload it again.'); end if;
    insert into submission_files(submission_id, file_path, file_name, file_type, file_size) values (sid, f->>'path', f->>'name', f->>'type', private.jint(f,'size'));
  end loop;
  perform private.touch(u.id);
  return jsonb_build_object('message', case when late then 'Submitted, but after the deadline – it is marked as late.' else 'Your assignment has been submitted successfully.' end);
end $$;

-- =====================================================================
--  FILES (Supabase Storage with one-time tickets)
-- =====================================================================
create or replace function private.storage_can_upload(objname text) returns boolean language sql stable security definer set search_path = private as
$$ select exists(select 1 from private.file_tickets where path = objname and kind = 'upload' and expires_at > now()) $$;
create or replace function private.storage_can_read(objname text) returns boolean language sql stable security definer set search_path = private as
$$ select exists(select 1 from private.file_tickets where path = objname and kind = 'read' and expires_at > now()) $$;

create or replace function private.act_files_prepareupload(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare purpose text := p->>'purpose'; nm text := coalesce(private.jt(p,'name'), 'file'); ext text; allowed text; v_path text;
begin
  if coalesce(private.jint(p,'size'), 0) > 10485760 then perform private.fail('The file is too large. The maximum size is 10 MB.'); end if;
  if purpose = 'submission' then
    perform private.need(u, array['student']);
    select coalesce(allowed_types, 'pdf,docx,jpg,jpeg,png,zip,txt') into allowed from assignments where id = private.req_uuid(p,'assignment_id','assignment');
    if allowed is null then perform private.fail('Assignment not found.'); end if;
  elsif purpose = 'assignment' then
    perform private.need(u, private.r_staff()); allowed := 'pdf,docx,doc,pptx,xlsx,jpg,jpeg,png,zip,txt';
  else perform private.fail('Unknown upload type.');
  end if;
  ext := lower(substring(nm from '\.([A-Za-z0-9]+)$'));
  if ext is null or not (ext = any(string_to_array(replace(lower(allowed), ' ', ''), ','))) then
    perform private.fail(format('This file type (.%s) isn''t allowed. Allowed types: %s.', coalesce(ext,'?'), allowed));
  end if;
  v_path := format('%s/%s/%s_%s', purpose, u.id, encode(extensions.gen_random_bytes(12), 'hex'), right(regexp_replace(nm, '[^A-Za-z0-9._-]+', '_', 'g'), 80));
  delete from private.file_tickets where expires_at < now() - interval '1 day';
  insert into private.file_tickets(path, kind, user_id, expires_at) values (v_path, 'upload', u.id, now() + interval '15 minutes');
  return jsonb_build_object('path', v_path);
end $$;

create or replace function private.act_files_url(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_path text := coalesce(p->>'path',''); ok boolean := false; owner uuid;
begin
  if v_path = '' or v_path like '%..%' then perform private.fail('Invalid file.'); end if;
  if u.role = 'student' then
    ok := v_path like 'submission/' || u.id || '/%'
          or exists(select 1 from assignment_attachments at join jsonb_array_elements(private.student_assignments(u)) x on x->>'id' = at.assignment_id::text where at.file_path = v_path);
  else
    if v_path like 'submission/%' then
      begin owner := split_part(v_path, '/', 2)::uuid; exception when others then owner := null; end;
      ok := exists(select 1 from users where id = owner and private.in_scope(s, organization_id));
    else ok := exists(select 1 from assignment_attachments at join assignments a on a.id = at.assignment_id where at.file_path = v_path and private.in_scope(s, a.organization_id));
    end if;
  end if;
  if not ok then perform private.fail('You don''t have access to this file.', '403'); end if;
  insert into private.file_tickets(path, kind, user_id, expires_at) values (v_path, 'read', u.id, now() + interval '2 minutes')
    on conflict (path, kind) do update set expires_at = excluded.expires_at, user_id = excluded.user_id;
  return jsonb_build_object('path', v_path);
end $$;

-- =====================================================================
--  NOTIFICATIONS
-- =====================================================================
create or replace function private.act_notifications_list(u public.users, s uuid[], p jsonb) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('rows', coalesce((select jsonb_agg(to_jsonb(n) order by n.created_at desc) from (
    select * from notifications where user_id = u.id and (not coalesce(private.jbool(p,'unread'),false) or not coalesce(is_read,false))
    order by created_at desc limit least(200, coalesce(private.jint(p,'limit'), 50))) n), '[]'))
$$;
create or replace function private.act_notifications_read(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update notifications set is_read = true, read_at = now() where user_id = u.id and not coalesce(is_read,false) and (private.juuid(p,'id') is null or id = private.juuid(p,'id'));
  return jsonb_build_object('message', case when private.juuid(p,'id') is null then 'All notifications marked as read.' else 'Marked as read.' end);
end $$;
create or replace function private.act_notifications_clear(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin delete from notifications where user_id = u.id and coalesce(is_read,false); return jsonb_build_object('message', 'Read notifications cleared.'); end $$;

-- =====================================================================
--  ACTIVITIES & ENGAGEMENT
-- =====================================================================
create or replace function private.act_student_activities(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform private.need(u, array['student']);
  return jsonb_build_object('rows', coalesce((select jsonb_agg(to_jsonb(a) || jsonb_build_object(
        'exam', (select jsonb_build_object('id',e.id,'title',e.title) from exams e where e.id = a.exam_id),
        'started', exists(select 1 from activity_events v where v.activity_id = a.id and v.user_id = u.id and v.event_type = 'practice_start'),
        'completed', exists(select 1 from activity_events v where v.activity_id = a.id and v.user_id = u.id and v.event_type = 'practice_complete'),
        'state', case when a.start_time > now() then 'upcoming' when a.end_time < now() then 'closed' else 'open' end) order by a.start_time nulls first, a.created_at desc)
      from activities a
      where coalesce(a.is_active, true) and a.organization_id in (select u.organization_id union select parent_id from organizations where id = u.organization_id)), '[]'),
    'points', coalesce((select sum(a.points) from activities a where exists(select 1 from activity_events v where v.activity_id = a.id and v.user_id = u.id and v.event_type = 'practice_complete')), 0));
end $$;
create or replace function private.act_student_activityevent(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a activities; ev text := case when p->>'event' = 'complete' then 'practice_complete' else 'practice_start' end;
begin
  perform private.need(u, array['student']);
  select * into a from activities where id = private.req_uuid(p,'activity_id','activity') and coalesce(is_active,true)
    and organization_id in (select u.organization_id union select parent_id from organizations where id = u.organization_id);
  if a.id is null then perform private.fail('This activity isn''t available to you.', '404'); end if;
  if a.start_time > now() then perform private.fail('This activity hasn''t started yet.'); end if;
  if a.end_time < now() then perform private.fail('This activity has ended.'); end if;
  if ev = 'practice_complete' and exists(select 1 from activity_events where activity_id = a.id and user_id = u.id and event_type = ev) then
    return jsonb_build_object('message', 'You already completed this activity.');
  end if;
  -- an answer file (uploaded first through files.prepareUpload, purpose activity_answer) and a short note can come with "complete"
  if ev = 'practice_complete' and private.jt(p, 'file_path') is not null and private.jt(p, 'file_path') not like 'student-submissions/' || u.id || '/%' then
    perform private.fail('Please upload your file again.'); end if;
  insert into activity_events(user_id, activity_id, event_type, meta) values (u.id, a.id, ev, jsonb_strip_nulls(jsonb_build_object('title', a.title,
    'file_path', case when ev = 'practice_complete' then private.jt(p, 'file_path') end, 'file_name', case when ev = 'practice_complete' then private.jt(p, 'file_name') end,
    'note', case when ev = 'practice_complete' then left(private.jt(p, 'note'), 1000) end)));
  perform private.touch(u.id);
  return jsonb_build_object('message', case when ev = 'practice_complete' then format('Well done! You earned %s.', private.plural(coalesce(a.points,0), 'point')) else 'Activity started. Good luck!' end);
end $$;

create or replace function private.act_engagement_overview(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare bid uuid := private.juuid(p,'batch_id'); rows jsonb;
begin
  perform private.need(u, private.r_staff());
  create temp table if not exists _eng (user_id uuid, full_name text, email text, roll_number text, org text, last_at timestamptz, days int, pending int, bucket text, status text) on commit drop;
  truncate _eng;
  insert into _eng
  select x.id, x.full_name, x.email, x.roll_number, (select name from organizations where id = x.organization_id), la.t,
         case when la.t is null then 999 else floor(extract(epoch from now() - la.t) / 86400)::int end, pw.n, null, null
  from users x
  cross join lateral (select greatest(x.last_login_at, (select last_activity_at from engagement_status where user_id = x.id),
                                      (select max(created_at) from activity_events where user_id = x.id),
                                      (select max(submitted_at) from assignment_submissions where user_id = x.id)) t) la
  cross join lateral (select
        (select count(*) from assignments a where a.status = 'published' and (a.deadline is null or a.deadline > now() - interval '30 days')
           and exists(select 1 from assignment_batches b where b.assignment_id = a.id and b.batch_id = any(private.my_batches(x.id)))
           and not exists(select 1 from assignment_submissions z where z.assignment_id = a.id and z.user_id = x.id))
      + (select count(*) from exams e where e.status = 'live' and private.is_assigned(x.id, e.id)
           and not exists(select 1 from exam_attempts z where z.exam_id = e.id and z.user_id = x.id)) n) pw
  where x.role = 'student' and coalesce(x.is_active,true) and private.in_scope(s, x.organization_id)
    and (bid is null or exists(select 1 from batch_members m where m.batch_id = bid and m.user_id = x.id));
  update _eng set bucket = case when days >= 30 then '30+' when days >= 15 then '15+' when days >= 7 then '7+' when days >= 3 then '3+' else 'active' end,
                  status = case when days >= 3 then 'inactive' when pending > 0 then 'pending_work' else 'active' end;
  -- keep engagement_status table in sync (inactivity rules 3/7/15/30 days)
  insert into engagement_status(user_id, status, last_activity_at, inactivity_days, updated_at)
  select user_id, status, last_at, least(days, 9999), now() from _eng
  on conflict (user_id) do update set status = excluded.status, last_activity_at = coalesce(excluded.last_activity_at, engagement_status.last_activity_at), inactivity_days = excluded.inactivity_days, updated_at = now();
  select coalesce(jsonb_agg(to_jsonb(e) order by e.days desc, e.full_name), '[]') into rows from _eng e
    where coalesce(private.jt(p,'bucket'), 'all') = 'all' or e.bucket = p->>'bucket' or (p->>'bucket' = 'pending' and e.pending > 0);
  return jsonb_build_object('rows', rows, 'summary', (select jsonb_build_object('total', count(*), 'active', count(*) filter (where bucket = 'active'),
      'd3', count(*) filter (where bucket = '3+'), 'd7', count(*) filter (where bucket = '7+'), 'd15', count(*) filter (where bucket = '15+'),
      'd30', count(*) filter (where bucket = '30+'), 'pending', count(*) filter (where pending > 0)) from _eng));
end $$;

create or replace function private.act_engagement_remind(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare ids uuid[];
begin
  perform private.need(u, private.r_staff());
  ids := array(select id from users where id = any(private.uuids(p->'user_ids')) and role = 'student' and private.in_scope(s, organization_id));
  if cardinality(ids) = 0 then perform private.fail('Please select at least one student.'); end if;
  perform private.notify(ids, coalesce(private.jt(p,'title'), 'We miss you!'), coalesce(private.jt(p,'body'), 'You have pending work. Sign in and continue your preparation today.'), 'reminder', null, null, 'dashboard.html');
  return jsonb_build_object('message', format('Reminder sent to %s.', private.plural(cardinality(ids), 'student')));
end $$;

-- =====================================================================
--  DASHBOARD
-- =====================================================================
create or replace function private.act_dashboard(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ex jsonb; asg jsonb;
begin
  if u.role = 'student' then
    ex := private.student_exams(u); asg := private.student_assignments(u);
    return jsonb_build_object(
      'stats', jsonb_build_object(
        'available_exams', (select count(*) from jsonb_array_elements(ex) x where x->>'state' in ('open','in_progress')),
        'upcoming_exams', (select count(*) from jsonb_array_elements(ex) x where x->>'state' = 'upcoming'),
        'results', (select count(*) from results where user_id = u.id and is_visible),
        'avg_percentage', (select round(avg(percentage), 1) from results where user_id = u.id and is_visible),
        'pending_assignments', (select count(*) from jsonb_array_elements(asg) x where x->>'status' = 'published' and x->'my_submission' = 'null'::jsonb),
        'points', coalesce((select sum(a.points) from activities a where exists(select 1 from activity_events v where v.activity_id = a.id and v.user_id = u.id and v.event_type = 'practice_complete')), 0)),
      'exams', coalesce((select jsonb_agg(x) from (select x from jsonb_array_elements(ex) x where x->>'state' in ('open','upcoming','in_progress') limit 6) z), '[]'),
      'assignments', coalesce((select jsonb_agg(x) from (select x from jsonb_array_elements(asg) x where x->'my_submission' = 'null'::jsonb and x->>'status' = 'published' limit 6) z), '[]'),
      'trend', coalesce((select jsonb_agg(jsonb_build_object('label', e.title, 'value', r.percentage) order by r.created_at) from (select * from results where user_id = u.id and is_visible order by created_at desc limit 8) r join exams e on e.id = r.exam_id), '[]'),
      'announcements', (select coalesce(jsonb_agg(x), '[]') from (select x from jsonb_array_elements(private.feed(u)) x limit 5) z));
  end if;
  return jsonb_build_object(
    'stats', jsonb_build_object(
      'organizations', (select count(*) from organizations where private.in_scope(s, id)),
      'students', (select count(*) from users where role = 'student' and private.in_scope(s, organization_id)),
      'faculty', (select count(*) from users where role = 'faculty' and private.in_scope(s, organization_id)),
      'batches', (select count(*) from batches where private.in_scope(s, organization_id)),
      'questions', (select count(*) from questions where private.in_scope(s, organization_id) or organization_id is null),
      'exams', (select count(*) from exams where private.in_scope(s, organization_id)),
      'live_exams', (select count(*) from exams where status = 'live' and private.in_scope(s, organization_id)),
      'assignments', (select count(*) from assignments where private.in_scope(s, organization_id)),
      'pending_reviews', (select count(*) from assignment_submissions x join assignments a on a.id = x.assignment_id where x.status in ('submitted','late','resubmitted','under_review') and private.in_scope(s, a.organization_id)),
      'inactive_students', (select count(*) from engagement_status es join users x on x.id = es.user_id where es.status = 'inactive' and private.in_scope(s, x.organization_id))),
    'exams', coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'status',status,'start_time',start_time,'total_questions',total_questions,'organization',private.nm_org(organization_id))) from (
        select * from exams where private.in_scope(s, organization_id) order by created_at desc limit 6) e), '[]'),
    'trend', coalesce((select jsonb_agg(jsonb_build_object('label', to_char(d, 'DD Mon'), 'value', (select count(*) from exam_attempts a join exams e on e.id = a.exam_id
        where a.submitted_at::date = d and private.in_scope(s, e.organization_id))) order by d) from generate_series(current_date - 6, current_date, interval '1 day') d), '[]'),
    'announcements', (select coalesce(jsonb_agg(x), '[]') from (select x from jsonb_array_elements(private.feed(u)) x limit 5) z));
end $$;

-- =====================================================================
--  SETTINGS (Super Admin) – Groq key is stored privately, never returned
-- =====================================================================
create or replace function private.act_settings_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare k text := private.setting('groq_api_key');
begin
  perform private.need(u, array['super_admin']);
  return jsonb_build_object('groq_configured', k is not null, 'groq_key_hint', case when k is not null then '••••' || right(k, 4) end,
    'groq_model', coalesce(private.setting('groq_model'), 'openai/gpt-oss-120b'), 'http_enabled', exists(select 1 from pg_extension where extname = 'http'),
    'app_name', private.setting('app_name'));
end $$;
create or replace function private.act_settings_save(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform private.need(u, array['super_admin']);
  if private.jt(p,'groq_api_key') is not null then
    if p->>'groq_api_key' !~ '^gsk_[A-Za-z0-9]{20,}$' then perform private.fail('That doesn''t look like a Groq key. It should start with "gsk_".'); end if;
    insert into private.settings(key, value) values ('groq_api_key', btrim(p->>'groq_api_key')) on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;
  if private.jt(p,'groq_model') is not null then
    insert into private.settings(key, value) values ('groq_model', btrim(p->>'groq_model')) on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;
  if coalesce(private.jbool(p,'remove_key'), false) then delete from private.settings where key = 'groq_api_key'; end if;
  perform private.audit(u, 'settings', 'settings', null, jsonb_build_object('groq_model', p->>'groq_model', 'key_changed', private.jt(p,'groq_api_key') is not null));
  return jsonb_build_object('message', 'Settings saved.');
end $$;
create or replace function private.act_settings_testai(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb;
begin
  perform private.need(u, array['super_admin']);
  r := private.groq('Reply with JSON only.', 'Reply with {"status":"ok"}', 50);
  return jsonb_build_object('message', 'AI is working! Groq replied successfully.', 'reply', r);
end $$;

-- =====================================================================
--  v3: STORAGE BUCKETS, MEDIA, EXAM WIZARD, INTELLIGENCE, REPORTS
-- =====================================================================

-- ---------- storage buckets ----------
-- public buckets: files are served by an unguessable public link (images shown inside pages)
-- private buckets: files are only readable with a short-lived ticket from api()
do $$
declare b record;
begin
  for b in select * from (values
      ('uploads', false), ('assignment-files', false), ('question-images', true), ('avatars', true),
      ('announcements-media', true), ('question-media', true), ('student-submissions', false),
      ('syllabus-files', false), ('assignment-attachments', false), ('scorecards', false)) v(id, pub)
  loop
    insert into storage.buckets (id, name, public, file_size_limit) values (b.id, b.id, b.pub, 10485760)
    on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;
  end loop;
exception when others then raise notice 'Storage buckets not created: %', sqlerrm;
end $$;

create or replace function private.buckets() returns text[] language sql immutable as
$$ select array['uploads','assignment-files','question-images','avatars','announcements-media','question-media','student-submissions','syllabus-files','assignment-attachments','scorecards'] $$;
create or replace function private.public_buckets() returns text[] language sql immutable as
$$ select array['question-images','avatars','announcements-media','question-media'] $$;

-- a stored file reference is "<bucket>/<object name>"; older references without a bucket prefix live in "uploads"
create or replace function private.split_ref(ref text, out bkt text, out nm text) language plpgsql immutable as $$
begin
  if split_part(coalesce(ref,''), '/', 1) = any(private.buckets()) then bkt := split_part(ref, '/', 1); nm := substr(ref, length(bkt) + 2);
  else bkt := 'uploads'; nm := ref; end if;
end $$;

create or replace function private.storage_can_upload2(b text, n text) returns boolean language sql stable security definer set search_path = private as
$$ select exists(select 1 from private.file_tickets where path = b || '/' || n and kind = 'upload' and expires_at > now()) $$;
create or replace function private.storage_can_read2(b text, n text) returns boolean language sql stable security definer set search_path = private as
$$ select exists(select 1 from private.file_tickets where path = b || '/' || n and kind in ('read','upload') and expires_at > now()) $$;

create or replace function private.act_files_prepareupload(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare purpose text := coalesce(p->>'purpose',''); nm text := coalesce(private.jt(p,'name'), 'file'); ext text; allowed text; bkt text; roles text[];
  objname text; docs text := 'pdf,doc,docx,ppt,pptx,xls,xlsx,csv,txt,zip,jpg,jpeg,png,webp';
  imgs text := 'jpg,jpeg,png,gif,webp,svg';
begin
  if coalesce(private.jint(p,'size'), 0) > 10485760 then perform private.fail('The file is too large. The maximum size is 10 MB.'); end if;
  case purpose
    when 'submission' then bkt := 'student-submissions'; roles := array['student'];
      select coalesce(nullif(allowed_types,''), 'pdf,docx,jpg,jpeg,png,zip,txt') into allowed from assignments where id = private.req_uuid(p,'assignment_id','assignment');
      if allowed is null then perform private.fail('Assignment not found.'); end if;
    when 'activity_answer' then bkt := 'student-submissions'; roles := array['student']; allowed := docs;   -- a student's answer sheet for a quiz / activity
      if not exists (select 1 from activities a where a.id = private.req_uuid(p,'activity_id','activity') and coalesce(a.is_active, true)
                     and a.organization_id in (select u.organization_id union select parent_id from organizations where id = u.organization_id)) then
        perform private.fail('This activity isn''t available to you.'); end if;
    when 'assignment' then bkt := 'assignment-attachments'; roles := private.r_staff(); allowed := docs;
    when 'assignment_file' then bkt := 'assignment-files'; roles := private.r_staff(); allowed := docs || ',mp3,mp4,webm';
    when 'question_image' then bkt := 'question-images'; roles := private.r_staff(); allowed := imgs;
    when 'question_media' then bkt := 'question-media'; roles := private.r_staff(); allowed := imgs || ',mp3,wav,mp4,webm,pdf';
    when 'avatar' then bkt := 'avatars'; roles := private.r_all(); allowed := 'jpg,jpeg,png,webp';
    when 'logo' then bkt := 'avatars'; roles := array['super_admin','college_admin']; allowed := imgs;
    when 'announcement' then bkt := 'announcements-media'; roles := private.r_staff(); allowed := imgs || ',pdf,doc,docx,ppt,pptx,xls,xlsx,mp4';
    when 'syllabus' then bkt := 'syllabus-files'; roles := private.r_admin(); allowed := 'pdf,doc,docx,xls,xlsx,csv,txt';
    when 'scorecard' then bkt := 'scorecards'; roles := private.r_all(); allowed := 'pdf';
    when 'document' then bkt := 'uploads'; roles := private.r_staff(); allowed := docs;
    else perform private.fail('This file can''t be uploaded here right now. Please refresh the page and try again.');
  end case;
  perform private.need(u, roles);
  ext := lower(substring(nm from '\.([A-Za-z0-9]+)$'));
  if ext is null or not (ext = any(string_to_array(replace(lower(allowed), ' ', ''), ','))) then
    perform private.fail(format('This file type (.%s) isn''t allowed here. Allowed types: %s.', coalesce(ext,'?'), replace(allowed, ',', ', ')));
  end if;
  objname := format('%s/%s_%s', u.id, encode(extensions.gen_random_bytes(12), 'hex'), right(regexp_replace(nm, '[^A-Za-z0-9._-]+', '_', 'g'), 80));
  delete from private.file_tickets where expires_at < now() - interval '1 day';
  insert into private.file_tickets(path, kind, user_id, expires_at) values (bkt || '/' || objname, 'upload', u.id, now() + interval '15 minutes');
  return jsonb_build_object('path', bkt || '/' || objname, 'bucket', bkt, 'name', objname, 'public', bkt = any(private.public_buckets()));
end $$;

create or replace function private.act_files_url(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare ref text := coalesce(p->>'path',''); b text; n text; ok boolean := false; owner uuid; seg text;
begin
  if ref = '' or ref like '%..%' then perform private.fail('Invalid file.'); end if;
  select x.bkt, x.nm into b, n from private.split_ref(ref) x;
  if b = any(private.public_buckets()) then return jsonb_build_object('bucket', b, 'name', n, 'public', true); end if;
  seg := case when b = 'uploads' and n ~ '^(submission|assignment)/' then split_part(n, '/', 2) else split_part(n, '/', 1) end;
  begin owner := seg::uuid; exception when others then owner := null; end;
  if owner = u.id then ok := true;
  elsif u.role = 'student' then
    ok := exists(select 1 from assignment_attachments at join jsonb_array_elements(private.student_assignments(u)) x on x->>'id' = at.assignment_id::text where at.file_path in (ref, n))
       or exists(select 1 from activities a where a.resource_url in (ref, n) and coalesce(a.is_active, true)
                 and (a.organization_id is null or a.organization_id = u.organization_id or a.organization_id = (select parent_id from organizations where id = u.organization_id)))
       or (b = 'scorecards' and exists(select 1 from results r where r.scorecard_url in (ref, n) and r.user_id = u.id));
  else
    ok := exists(select 1 from users x where x.id = owner and private.in_scope(s, x.organization_id))
       or (s is null);
  end if;
  if not ok then perform private.fail('You don''t have access to this file.', '403'); end if;
  insert into private.file_tickets(path, kind, user_id, expires_at) values (b || '/' || n, 'read', u.id, now() + interval '2 minutes')
    on conflict (path, kind) do update set expires_at = excluded.expires_at, user_id = excluded.user_id;
  return jsonb_build_object('bucket', b, 'name', n, 'public', false);
end $$;

-- ---------- question media (images / audio / video / pdf attached to a question) ----------
create or replace function private.scoped_question(u public.users, s uuid[], qid uuid) returns public.questions language plpgsql stable security definer set search_path = public as $$
declare q questions;
begin
  select * into q from questions where id = qid;
  if q.id is null or not (private.in_scope(s, q.organization_id) or (q.organization_id is null and u.role = 'super_admin')) then perform private.fail('Question not found or you don''t have access.', '404'); end if;
  return q;
end $$;
create or replace function private.act_question_media(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare q questions;
begin
  perform private.need(u, private.r_staff());
  q := private.scoped_question(u, s, private.req_uuid(p,'question_id','question'));
  return jsonb_build_object('rows', coalesce((select jsonb_agg(to_jsonb(m) order by m.order_index, m.created_at) from question_media m where m.question_id = q.id), '[]'));
end $$;
create or replace function private.act_question_addmedia(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare q questions; t text := coalesce(p->>'media_type','image');
begin
  perform private.need(u, private.r_staff());
  q := private.scoped_question(u, s, private.req_uuid(p,'question_id','question'));
  if t not in ('image','equation','audio','video','file') then t := 'file'; end if;
  if private.jt(p,'file_path') is null or private.jt(p,'file_path') !~ '^https://' then perform private.fail('Please upload the file again.'); end if;
  insert into question_media(question_id, media_type, file_path, order_index) values (q.id, t, p->>'file_path', (select count(*) from question_media where question_id = q.id));
  return jsonb_build_object('message', 'Media attached to the question.');
end $$;
create or replace function private.act_question_removemedia(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare m question_media;
begin
  perform private.need(u, private.r_staff());
  select * into m from question_media where id = private.req_uuid(p,'id');
  if m.id is null then perform private.fail('This media was already removed.'); end if;
  perform private.scoped_question(u, s, m.question_id);
  delete from question_media where id = m.id;
  return jsonb_build_object('message', 'Media removed.');
end $$;

-- ---------- exam wizard helpers ----------
-- random pick inside the chosen syllabus, optionally with a difficulty mix {"easy":5,"medium":10,"hard":5}
create or replace function private.act_exam_autopick(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; ids uuid[] := '{}'; part uuid[]; d text; want int; total_want int := 0;
  sids uuid[] := private.uuids(p->'subject_ids'); cids uuid[] := private.uuids(p->'chapter_ids'); tids uuid[] := private.uuids(p->'topic_ids');
  mix jsonb := case when jsonb_typeof(p->'mix') = 'object' then p->'mix' else jsonb_build_object(coalesce(private.jt(p,'difficulty'),'any'), least(200, greatest(1, coalesce(private.jint(p,'count'), 10)))) end;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  perform private.exam_locked(e.id);
  if private.juuid(p,'subject_id') is not null then sids := sids || private.juuid(p,'subject_id'); end if;
  if private.juuid(p,'chapter_id') is not null then cids := cids || private.juuid(p,'chapter_id'); end if;
  for d, want in select key, least(200, greatest(0, coalesce((value #>> '{}')::int, 0))) from jsonb_each(mix) loop
    continue when want = 0;
    total_want := total_want + want;
    part := array(select q.id from questions q
      where q.status = any(case when private.jbool(p,'include_drafts') then array['draft','under_review','approved','published'] else array['approved','published'] end)
        and (private.in_scope(s, q.organization_id) or q.organization_id is null)
        and (case when coalesce(private.jbool(p,'match_any'), false)
               then (cardinality(sids) + cardinality(cids) + cardinality(tids) = 0 or q.subject_id = any(sids) or q.chapter_id = any(cids) or q.topic_id = any(tids))
               else (cardinality(sids) = 0 or q.subject_id = any(sids)) and (cardinality(cids) = 0 or q.chapter_id = any(cids)) and (cardinality(tids) = 0 or q.topic_id = any(tids)) end)
        and (d = 'any' or q.difficulty = d)
        and not (q.id = any(ids))
        and not exists(select 1 from exam_questions x where x.exam_id = e.id and x.question_id = q.id)
      order by random() limit want);
    ids := ids || part;
  end loop;
  if cardinality(ids) = 0 then perform private.fail(case when private.jbool(p,'include_drafts') then 'No matching questions found in the bank for this syllabus.' else 'No approved questions match this syllabus. Approve some questions first or tick ''Include draft questions''.' end); end if;
  perform private.act_exam_addquestions(u, s, jsonb_build_object('exam_id', e.id, 'question_ids', to_jsonb(ids), 'section', p->'section'));
  return jsonb_build_object('added', cardinality(ids), 'message', case when cardinality(ids) < total_want then format('Only %s matching questions were available; all were added.', cardinality(ids)) else format('%s added to the exam.', private.plural(cardinality(ids),'question')) end);
end $$;

-- marks / sections / order for many exam questions at once + exam-level negative marks
create or replace function private.act_exam_configure(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare e exams; it jsonb; n int := 0;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  if exists(select 1 from exam_attempts where exam_id = e.id) and jsonb_typeof(p->'items') = 'array' then
    perform private.fail('Students have already attempted this exam, so marks and sections can''t be changed.');
  end if;
  for it in select value from jsonb_array_elements(case when jsonb_typeof(p->'items') = 'array' then p->'items' else '[]' end) loop
    if it ? 'marks' and not (private.jnum(it,'marks') > 0) then perform private.fail('Marks must be greater than 0 for every question.'); end if;
    update exam_questions set marks = coalesce(private.jnum(it,'marks'), marks),
                              section = case when it ? 'section' then private.jt(it,'section') else section end,
                              order_index = coalesce(private.jint(it,'order_index'), order_index)
     where id = private.juuid(it,'id') and exam_id = e.id;
    n := n + 1;
  end loop;
  if p ? 'negative_marks' then
    if private.jnum(p,'negative_marks') < 0 then perform private.fail('Negative marks can''t be below 0.'); end if;
    update exams set settings = case when private.jnum(p,'negative_marks') is null then coalesce(settings,'{}') - 'negative_marks'
                                     else coalesce(settings,'{}') || jsonb_build_object('negative_marks', private.jnum(p,'negative_marks')) end
     where id = e.id;
  end if;
  update exams set negative_marking = coalesce(private.jbool(p,'negative_marking'), negative_marking),
                   shuffle_questions = coalesce(private.jbool(p,'shuffle_questions'), shuffle_questions),
                   shuffle_options = coalesce(private.jbool(p,'shuffle_options'), shuffle_options),
                   show_result_immediately = coalesce(private.jbool(p,'show_result_immediately'), show_result_immediately), updated_at = now()
   where id = e.id;
  perform private.recalc_exam(e.id);
  return jsonb_build_object('message', 'Exam configuration saved.');
end $$;

-- full question data for the wizard preview (staff only; includes answers)
create or replace function private.act_exam_preview(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e exams;
begin
  perform private.need(u, private.r_staff());
  e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
  return jsonb_build_object('questions', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'eq_id', eq.id, 'text', q.question_text, 'type', q.question_type,
      'options', private.norm_options(q.options), 'correct_answer', q.correct_answer, 'marks', coalesce(eq.marks, q.marks, 1), 'section', eq.section,
      'difficulty', q.difficulty, 'subject', private.nm_subject(q.subject_id), 'chapter', private.nm_chapter(q.chapter_id), 'topic', private.nm_topic(q.topic_id),
      'negative', coalesce(private.jnum(e.settings,'negative_marks'), q.negative_marks, 0),
      'media', coalesce((select jsonb_agg(jsonb_build_object('type', m.media_type, 'url', m.file_path) order by m.order_index) from question_media m where m.question_id = q.id), '[]'))
      order by eq.order_index nulls last) from exam_questions eq join questions q on q.id = eq.question_id where eq.exam_id = e.id), '[]'));
end $$;

-- ---------- engagement score (0-100) ----------
create or replace function private.engagement_score(uid uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare last_at timestamptz; days int; logins int; exams_n int; subs int; acts int; pending int; tabs numeric; sc int; lvl text;
begin
  select greatest(u.last_login_at, (select last_activity_at from engagement_status where user_id = uid), (select max(created_at) from activity_events where user_id = uid))
    into last_at from users u where u.id = uid;
  days := case when last_at is null then 999 else floor(extract(epoch from now() - last_at) / 86400)::int end;
  select count(*) into logins from activity_events where user_id = uid and event_type = 'login' and created_at > now() - interval '14 days';
  select count(*), coalesce(avg(tab_switches), 0) into exams_n, tabs from exam_attempts where user_id = uid and started_at > now() - interval '30 days';
  select count(*) into subs from assignment_submissions where user_id = uid and submitted_at > now() - interval '30 days';
  select count(*) into acts from activity_events where user_id = uid and activity_id is not null and created_at > now() - interval '30 days';
  select (select count(*) from assignments a where a.status = 'published' and (a.deadline is null or a.deadline > now() - interval '30 days')
            and exists(select 1 from assignment_batches b where b.assignment_id = a.id and b.batch_id = any(private.my_batches(uid)))
            and not exists(select 1 from assignment_submissions z where z.assignment_id = a.id and z.user_id = uid))
       + (select count(*) from exams e where e.status = 'live' and private.is_assigned(uid, e.id) and not exists(select 1 from exam_attempts z where z.exam_id = e.id and z.user_id = uid))
    into pending;
  sc := (case when days <= 1 then 35 when days < 3 then 28 when days < 7 then 15 when days < 15 then 5 else 0 end)
      + least(logins * 3, 15) + least(exams_n * 8, 20) + least(subs * 5, 15) + least(acts * 3, 10)
      + (case when exams_n = 0 then 3 when tabs = 0 then 5 when tabs <= 2 then 3 else 0 end)
      - least(pending * 4, 15);
  sc := greatest(0, least(100, sc));
  lvl := case when sc >= 75 then 'Highly engaged' when sc >= 50 then 'Engaged' when sc >= 25 then 'At risk' else 'Inactive' end;
  return jsonb_build_object('score', sc, 'level', lvl, 'days_inactive', days, 'logins_14d', logins, 'exams_30d', exams_n, 'submissions_30d', subs,
                            'activities_30d', acts, 'pending', pending, 'avg_tab_switches', round(tabs, 1), 'last_activity', last_at);
end $$;

create or replace function private.act_engagement_overview(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare bid uuid := private.juuid(p,'batch_id'); rows jsonb;
begin
  perform private.need(u, private.r_staff());
  create temp table if not exists _eng3 (user_id uuid, full_name text, email text, roll_number text, org text, last_at timestamptz, days int, pending int,
                                         bucket text, status text, score int, level text, logins int, exams int, subs int) on commit drop;
  truncate _eng3;
  insert into _eng3
  select x.id, x.full_name, x.email, x.roll_number, (select name from organizations where id = x.organization_id), (es->>'last_activity')::timestamptz,
         (es->>'days_inactive')::int, (es->>'pending')::int, null, null, (es->>'score')::int, es->>'level',
         (es->>'logins_14d')::int, (es->>'exams_30d')::int, (es->>'submissions_30d')::int
  from users x cross join lateral (select private.engagement_score(x.id) es) z
  where x.role = 'student' and coalesce(x.is_active,true) and private.in_scope(s, x.organization_id)
    and (bid is null or exists(select 1 from batch_members m where m.batch_id = bid and m.user_id = x.id));
  update _eng3 set bucket = case when days >= 30 then '30+' when days >= 15 then '15+' when days >= 7 then '7+' when days >= 3 then '3+' else 'active' end,
                   status = case when days >= 3 then 'inactive' when pending > 0 then 'pending_work' else 'active' end;
  insert into engagement_status(user_id, status, last_activity_at, inactivity_days, updated_at)
  select user_id, status, last_at, least(days, 9999), now() from _eng3
  on conflict (user_id) do update set status = excluded.status, last_activity_at = coalesce(excluded.last_activity_at, engagement_status.last_activity_at), inactivity_days = excluded.inactivity_days, updated_at = now();
  select coalesce(jsonb_agg(to_jsonb(e) order by e.score, e.full_name), '[]') into rows from _eng3 e
    where coalesce(private.jt(p,'bucket'), 'all') = 'all' or e.bucket = p->>'bucket' or (p->>'bucket' = 'pending' and e.pending > 0) or e.level = p->>'bucket';
  return jsonb_build_object('rows', rows, 'summary', (select jsonb_build_object('total', count(*), 'active', count(*) filter (where bucket = 'active'),
      'd3', count(*) filter (where bucket = '3+'), 'd7', count(*) filter (where bucket = '7+'), 'd15', count(*) filter (where bucket = '15+'),
      'd30', count(*) filter (where bucket = '30+'), 'pending', count(*) filter (where pending > 0), 'avg_score', round(coalesce(avg(score),0)),
      'high', count(*) filter (where level = 'Highly engaged'), 'engaged', count(*) filter (where level = 'Engaged'),
      'risk', count(*) filter (where level = 'At risk'), 'inactive', count(*) filter (where level = 'Inactive')) from _eng3));
end $$;

-- ---------- student preparation intelligence ----------
create or replace function private.act_insights_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare stu users; vis_only boolean; agg jsonb; overall jsonb; trend jsonb; qt jsonb;
begin
  if u.role = 'student' then stu := u; vis_only := true;
  else
    perform private.need(u, private.r_staff());
    select * into stu from users where id = private.req_uuid(p,'user_id','student') and role = 'student';
    if stu.id is null or not private.in_scope(s, stu.organization_id) then perform private.fail('Student not found or you don''t have access.', '404'); end if;
    vis_only := false;
  end if;
  create temp table if not exists _ins (lvl text, name text, score numeric, mx numeric, correct int, wrong int, skipped int) on commit drop;
  truncate _ins;
  insert into _ins
  select g.lvl, k.key, (k.value->>'score')::numeric, (k.value->>'max')::numeric, (k.value->>'correct')::int, (k.value->>'wrong')::int, (k.value->>'unattempted')::int
  from results r
  cross join lateral (values ('subject', r.subject_wise), ('chapter', r.chapter_wise), ('topic', r.topic_wise)) g(lvl, j)
  cross join lateral jsonb_each(case when jsonb_typeof(g.j) = 'object' then g.j else '{}'::jsonb end) k
  where r.user_id = stu.id and (not vis_only or coalesce(r.is_visible,false)) and k.key <> 'General';
  select coalesce(jsonb_object_agg(lvl, items), '{}') into agg from (
    select lvl, jsonb_agg(jsonb_build_object('name', name, 'score', sc, 'max', mx, 'correct', c, 'wrong', w, 'skipped', sk,
             'accuracy', case when c + w > 0 then round(c::numeric / (c + w) * 100, 1) end,
             'score_pct', case when mx > 0 then round(sc / mx * 100, 1) end) order by case when c + w > 0 then c::numeric / (c + w) end nulls last, name) items
    from (select lvl, name, sum(score) sc, sum(mx) mx, sum(correct) c, sum(wrong) w, sum(skipped) sk from _ins group by lvl, name) z group by lvl) y;
  select jsonb_build_object('exams', count(*), 'avg_pct', round(coalesce(avg(percentage),0), 1), 'best_pct', max(percentage), 'avg_accuracy', round(coalesce(avg(accuracy),0),1),
                            'best_rank', min(rank), 'total_time', sum(time_spent_seconds))
    into overall from results where user_id = stu.id and (not vis_only or coalesce(is_visible,false));
  select coalesce(jsonb_agg(jsonb_build_object('title', e.title, 'date', r.created_at, 'pct', r.percentage, 'rank', r.rank) order by r.created_at), '[]') into trend
    from (select * from results where user_id = stu.id and (not vis_only or coalesce(is_visible,false)) order by created_at desc limit 12) r join exams e on e.id = r.exam_id;
  select jsonb_build_object('avg_seconds_per_question', round(avg((v.value #>> '{}')::numeric), 1), 'questions_timed', count(*)) into qt
    from exam_attempts a cross join lateral jsonb_each(case when jsonb_typeof(a.auto_save_data->'qtime') = 'object' then a.auto_save_data->'qtime' else '{}'::jsonb end) v
    where a.user_id = stu.id and a.status <> 'in_progress' and (v.value #>> '{}') ~ '^[0-9.]+$';
  return jsonb_build_object('student', jsonb_build_object('id', stu.id, 'full_name', stu.full_name, 'email', stu.email, 'roll_number', stu.roll_number),
    'overall', overall, 'trend', trend, 'subjects', coalesce(agg->'subject','[]'), 'chapters', coalesce(agg->'chapter','[]'), 'topics', coalesce(agg->'topic','[]'),
    'time', qt, 'engagement', private.engagement_score(stu.id));
end $$;

create or replace function private.act_ai_studyplan(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare ins jsonb; weak text; strong text; out jsonb;
begin
  ins := private.act_insights_get(u, s, p);
  select string_agg(format('%s (accuracy %s%%)', x->>'name', coalesce(x->>'accuracy','n/a')), '; ') into weak
    from (select x from jsonb_array_elements(case when jsonb_array_length(ins->'topics') > 0 then ins->'topics' else ins->'chapters' end) x limit 6) z;
  select string_agg(x->>'name', ', ') into strong
    from (select x from jsonb_array_elements(case when jsonb_array_length(ins->'topics') > 0 then ins->'topics' else ins->'chapters' end) x
          where (x->>'accuracy')::numeric >= 75 limit 5) z;
  if weak is null then perform private.fail('There isn''t enough exam data yet. Take at least one exam (and wait for its result) to get a study plan.'); end if;
  out := private.groq('You are an expert exam coach for Indian competitive exams (JEE/NEET). Reply with JSON only.',
    format(E'Student performance summary:\n- Average score: %s%%\n- Weakest areas (lowest first): %s\n- Strong areas: %s\n- Avg time per question: %s seconds\n\nCreate a practical 7-day study plan. Return JSON: {"summary":"2 sentences","plan":[{"day":1,"focus":"topic","tasks":["task 1","task 2","task 3"],"minutes":90}],"tips":["tip"]}',
      coalesce(ins->'overall'->>'avg_pct','0'), weak, coalesce(strong, 'none yet'), coalesce(ins->'time'->>'avg_seconds_per_question','unknown')), 3000);
  if coalesce(jsonb_typeof(out->'plan'), '') <> 'array' then perform private.fail('The AI couldn''t create a plan this time. Please try again.'); end if;
  return out;
end $$;

-- ---------- scorecards ----------
create or replace function private.act_result_setscorecard(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare r results; e exams; ref text := private.jt(p,'path');
begin
  select * into r from results where id = private.req_uuid(p,'id','result');
  if r.id is null then perform private.fail('Result not found.', '404'); end if;
  select * into e from exams where id = r.exam_id;
  if u.role = 'student' and (r.user_id <> u.id or not coalesce(r.is_visible,false)) then perform private.fail('This result hasn''t been released yet.', '403'); end if;
  if u.role <> 'student' and not private.in_scope(s, e.organization_id) then perform private.fail('You don''t have access to this result.', '403'); end if;
  if ref is null or ref not like 'scorecards/' || u.id || '/%' then perform private.fail('Please generate the scorecard again.'); end if;
  update results set scorecard_url = ref, updated_at = now() where id = r.id;
  return jsonb_build_object('message', 'Scorecard PDF saved.');
end $$;

-- ---------- reports (data for CSV / Excel / PDF export) ----------
create or replace function private.act_reports_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare typ text := coalesce(p->>'type',''); cols jsonb; rows jsonb; ttl text; e exams; bid uuid := private.juuid(p,'batch_id'); a assignments;
begin
  if typ = 'my_results' then
    ttl := 'My results – ' || u.full_name;
    cols := '["Exam","Date","Score","Max","Percentage","Rank","Percentile","Accuracy","Time (min)"]';
    select coalesce(jsonb_agg(jsonb_build_array(e2.title, to_char(r.created_at at time zone 'Asia/Kolkata','DD-Mon-YYYY'), r.total_score, r.max_score, r.percentage, r.rank, r.percentile, r.accuracy, round(coalesce(r.time_spent_seconds,0)/60.0,1)) order by r.created_at), '[]')
      into rows from results r join exams e2 on e2.id = r.exam_id where r.user_id = u.id and coalesce(r.is_visible,false);
    return jsonb_build_object('title', ttl, 'columns', cols, 'rows', rows);
  end if;
  perform private.need(u, private.r_staff());
  if typ = 'exam_results' then
    e := private.scoped_exam(s, private.req_uuid(p,'exam_id','exam'));
    ttl := 'Exam results – ' || e.title;
    cols := '["Rank","Student","Roll no.","Email","Score","Max","Percentage","Percentile","Accuracy","Time (min)","Tab switches","Status","Result"]';
    select coalesce(jsonb_agg(jsonb_build_array(r.rank, x.full_name, x.roll_number, x.email, r.total_score, r.max_score, r.percentage, r.percentile, r.accuracy,
             round(coalesce(r.time_spent_seconds,0)/60.0,1), a2.tab_switches, a2.status, case when r.percentage >= coalesce(e.pass_percentage,33) then 'Pass' else 'Fail' end)
             order by r.rank nulls last), '[]') into rows
      from results r join users x on x.id = r.user_id join exam_attempts a2 on a2.id = r.exam_attempt_id where r.exam_id = e.id;
  elsif typ = 'student_performance' then
    ttl := 'Student performance summary';
    cols := '["Student","Roll no.","Email","Organization","Exams taken","Average %","Best %","Average accuracy","Engagement score","Engagement level"]';
    select coalesce(jsonb_agg(jsonb_build_array(x.full_name, x.roll_number, x.email, (select name from organizations where id = x.organization_id),
             (select count(*) from results r where r.user_id = x.id), (select round(avg(percentage),1) from results r where r.user_id = x.id),
             (select max(percentage) from results r where r.user_id = x.id), (select round(avg(accuracy),1) from results r where r.user_id = x.id),
             (private.engagement_score(x.id)->>'score')::int, private.engagement_score(x.id)->>'level') order by x.full_name), '[]') into rows
      from users x where x.role = 'student' and coalesce(x.is_active,true) and private.in_scope(s, x.organization_id)
        and (bid is null or exists(select 1 from batch_members m where m.batch_id = bid and m.user_id = x.id));
  elsif typ = 'assignment_marks' then
    select * into a from assignments where id = private.req_uuid(p,'assignment_id','assignment');
    if a.id is null or not private.in_scope(s, a.organization_id) then perform private.fail('Assignment not found.', '404'); end if;
    ttl := 'Assignment marks – ' || a.title;
    cols := '["Student","Roll no.","Email","Attempt","Submitted","Status","Marks","Max marks","Feedback"]';
    select coalesce(jsonb_agg(jsonb_build_array(x.full_name, x.roll_number, x.email, z.attempt_number, to_char(z.submitted_at at time zone 'Asia/Kolkata','DD-Mon-YYYY HH24:MI'),
             z.status, z.marks_obtained, a.max_marks, z.feedback) order by x.full_name, z.attempt_number), '[]') into rows
      from assignment_submissions z join users x on x.id = z.user_id where z.assignment_id = a.id;
  elsif typ = 'engagement' then
    ttl := 'Student engagement';
    cols := '["Student","Roll no.","Email","Score","Level","Days inactive","Logins (14 days)","Exams (30 days)","Submissions (30 days)","Pending work"]';
    select coalesce(jsonb_agg(jsonb_build_array(x.full_name, x.roll_number, x.email, (es->>'score')::int, es->>'level', nullif((es->>'days_inactive')::int, 999),
             (es->>'logins_14d')::int, (es->>'exams_30d')::int, (es->>'submissions_30d')::int, (es->>'pending')::int) order by (es->>'score')::int), '[]') into rows
      from users x cross join lateral (select private.engagement_score(x.id) es) z
      where x.role = 'student' and coalesce(x.is_active,true) and private.in_scope(s, x.organization_id)
        and (bid is null or exists(select 1 from batch_members m where m.batch_id = bid and m.user_id = x.id));
  elsif typ = 'question_bank' then
    ttl := 'Question bank';
    cols := '["Question","Type","Difficulty","Subject","Chapter","Topic","Marks","Negative","Status","Source"]';
    select coalesce(jsonb_agg(jsonb_build_array(left(regexp_replace(q.question_text, '<[^>]*>', '', 'g'), 300), q.question_type, q.difficulty,
             private.nm_subject(q.subject_id)->>'name', private.nm_chapter(q.chapter_id)->>'name', private.nm_topic(q.topic_id)->>'name', q.marks, q.negative_marks, q.status, q.source)
             order by q.created_at desc), '[]') into rows
      from (select * from questions q where private.in_scope(s, q.organization_id) or q.organization_id is null order by created_at desc limit 5000) q;
  else perform private.fail('Please choose a report type.');
  end if;
  return jsonb_build_object('title', ttl, 'columns', cols, 'rows', rows);
end $$;

-- questions inside a syllabus selection (any of the chosen subjects / chapters / topics), for the exam wizard
create or replace function private.act_questions_inscope(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare sids uuid[] := private.uuids(p->'subject_ids'); cids uuid[] := private.uuids(p->'chapter_ids'); tids uuid[] := private.uuids(p->'topic_ids');
  q_ text := nullif(btrim(coalesce(p->>'search','')), ''); eid uuid := private.juuid(p,'exam_id');
begin
  perform private.need(u, private.r_staff());
  return jsonb_build_object('rows', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'question_text', q.question_text, 'question_type', q.question_type,
      'difficulty', q.difficulty, 'marks', q.marks, 'status', q.status, 'source', q.source,
      'subject', private.nm_subject(q.subject_id), 'chapter', private.nm_chapter(q.chapter_id), 'topic', private.nm_topic(q.topic_id),
      'in_exam', eid is not null and exists(select 1 from exam_questions x where x.exam_id = eid and x.question_id = q.id)) order by q.created_at desc)
    from (select * from questions q
          where (private.in_scope(s, q.organization_id) or q.organization_id is null)
            and q.status not in ('rejected','archived')
            and (cardinality(sids) + cardinality(cids) + cardinality(tids) = 0 or q.subject_id = any(sids) or q.chapter_id = any(cids) or q.topic_id = any(tids))
            and (private.jt(p,'difficulty') is null or q.difficulty = p->>'difficulty')
            and (private.jt(p,'status') is null or q.status = p->>'status')
            and (q_ is null or q.question_text ilike '%' || q_ || '%')
          order by q.created_at desc limit 300) q), '[]'));
end $$;

-- =====================================================================
--  v3.2: TABLE LINKING (foreign keys), AUTOMATIC UPDATES (triggers),
--        ORGANIZATION ADMINS, BACKEND VERSION
-- =====================================================================
create or replace function private.backend_version() returns text language sql immutable as $$ select '3.4' $$;

-- (re)create one foreign key with the wanted ON DELETE rule. Old rows that point
-- to something that no longer exists are cleaned first, so this never fails.
create or replace function private.relink(t text, c text, rt text, act text) returns void language plpgsql as $$
declare con record; nm text := left(t || '_' || c || '_fkey', 63); is_nn boolean; att smallint;
begin
  if to_regclass('public.' || t) is null or to_regclass('public.' || rt) is null then return; end if;
  select a.attnum, a.attnotnull into att, is_nn from pg_attribute a where a.attrelid = ('public.' || t)::regclass and a.attname = c and not a.attisdropped;
  if att is null then return; end if;
  for con in select conname from pg_constraint where conrelid = ('public.' || t)::regclass and contype = 'f' and conkey = array[att] loop
    execute format('alter table public.%I drop constraint %I', t, con.conname);
  end loop;
  if act = 'cascade' or is_nn then
    execute format('delete from public.%I x where x.%I is not null and not exists (select 1 from public.%I r where r.id = x.%I)', t, c, rt, c);
  else
    execute format('update public.%I x set %I = null where x.%I is not null and not exists (select 1 from public.%I r where r.id = x.%I)', t, c, c, rt, c);
  end if;
  execute format('alter table public.%I add constraint %I foreign key (%I) references public.%I(id) on update cascade on delete %s', t, nm, c, rt, act);
end $$;

do $$
declare r record;
begin
  for r in select * from (values
    -- hierarchy
    ('organizations','parent_id','organizations','set null'),
    ('users','organization_id','organizations','restrict'),          -- never delete people by accident
    -- batches
    ('batches','organization_id','organizations','cascade'), ('batches','created_by','users','set null'), ('batches','exam_category_id','exam_categories','set null'),
    ('batch_members','batch_id','batches','cascade'), ('batch_members','user_id','users','cascade'),
    -- syllabus: exam type → subject → unit → chapter → topic
    ('exam_categories','created_by','users','set null'),
    ('subjects','exam_category_id','exam_categories','cascade'),
    ('units','subject_id','subjects','cascade'),
    ('chapters','subject_id','subjects','cascade'), ('chapters','unit_id','units','set null'),
    ('topics','chapter_id','chapters','cascade'),
    ('syllabus_imports','exam_category_id','exam_categories','cascade'), ('syllabus_imports','imported_by','users','set null'), ('syllabus_imports','reviewed_by','users','set null'),
    -- questions
    ('questions','organization_id','organizations','cascade'), ('questions','subject_id','subjects','set null'), ('questions','chapter_id','chapters','set null'),
    ('questions','topic_id','topics','set null'), ('questions','created_by','users','set null'), ('questions','reviewed_by','users','set null'), ('questions','duplicate_of','questions','set null'),
    ('question_media','question_id','questions','cascade'),
    -- exams
    ('exams','organization_id','organizations','cascade'), ('exams','exam_category_id','exam_categories','set null'), ('exams','created_by','users','set null'), ('exams','published_by','users','set null'),
    ('exam_questions','exam_id','exams','cascade'), ('exam_questions','question_id','questions','restrict'),   -- a question used in an exam can't silently disappear
    ('exam_assignments','exam_id','exams','cascade'), ('exam_assignments','batch_id','batches','cascade'), ('exam_assignments','user_id','users','cascade'), ('exam_assignments','assigned_by','users','set null'),
    ('exam_attempts','exam_id','exams','cascade'), ('exam_attempts','user_id','users','cascade'),
    ('results','exam_attempt_id','exam_attempts','cascade'), ('results','user_id','users','cascade'), ('results','exam_id','exams','cascade'),
    -- assignments
    ('assignments','organization_id','organizations','cascade'), ('assignments','created_by','users','set null'),
    ('assignment_attachments','assignment_id','assignments','cascade'),
    ('assignment_batches','assignment_id','assignments','cascade'), ('assignment_batches','batch_id','batches','cascade'),
    ('assignment_submissions','assignment_id','assignments','cascade'), ('assignment_submissions','user_id','users','cascade'), ('assignment_submissions','evaluated_by','users','set null'),
    ('submission_files','submission_id','assignment_submissions','cascade'),
    -- activities & monitoring
    ('activities','organization_id','organizations','cascade'), ('activities','created_by','users','set null'), ('activities','exam_id','exams','set null'),
    ('activity_events','user_id','users','cascade'), ('activity_events','activity_id','activities','cascade'), ('activity_events','exam_attempt_id','exam_attempts','cascade'),
    ('engagement_status','user_id','users','cascade'),
    -- communication & security
    ('announcements','organization_id','organizations','cascade'), ('announcements','created_by','users','set null'),
    ('announcements','target_org','organizations','cascade'), ('announcements','target_batch','batches','cascade'),
    ('notifications','user_id','users','cascade'),
    ('audit_logs','user_id','users','set null'),
    ('app_sessions','user_id','users','cascade')
  ) v(t, c, rt, act) loop
    perform private.relink(r.t, r.c, r.rt, r.act);
  end loop;
end $$;

-- no duplicate links
do $$ begin
  delete from public.batch_members a using public.batch_members b where a.batch_id = b.batch_id and a.user_id = b.user_id and a.ctid > b.ctid;
  create unique index if not exists ux_batch_members on public.batch_members(batch_id, user_id);
  delete from public.exam_questions a using public.exam_questions b where a.exam_id = b.exam_id and a.question_id = b.question_id and a.ctid > b.ctid
    and not exists (select 1 from public.exam_attempts x where x.exam_id = a.exam_id);
  create unique index if not exists ux_exam_questions on public.exam_questions(exam_id, question_id);
exception when others then raise notice 'Unique link indexes skipped: %', sqlerrm; end $$;

-- ---------- automatic updates ----------
-- 1) updated_at is refreshed on every change
create or replace function private.tg_updated_at() returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end $$;
do $$ declare t text; begin
  for t in select c.table_name from information_schema.columns c where c.table_schema = 'public' and c.column_name = 'updated_at'
           and c.table_name in ('organizations','users','batches','exam_categories','syllabus_imports','questions','exams','exam_attempts','assignments','assignment_submissions','engagement_status','results')
  loop
    execute format('drop trigger if exists ep_updated_at on public.%I', t);
    execute format('create trigger ep_updated_at before update on public.%I for each row execute function private.tg_updated_at()', t);
  end loop;
end $$;

-- 2) exam totals (questions & marks) follow every add / edit / remove of exam questions
create or replace function private.tg_exam_totals() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('INSERT','UPDATE') then perform private.recalc_exam(new.exam_id); end if;
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and new.exam_id is distinct from old.exam_id) then perform private.recalc_exam(old.exam_id); end if;
  return null;
end $$;
drop trigger if exists ep_exam_totals on public.exam_questions;
create trigger ep_exam_totals after insert or update or delete on public.exam_questions for each row execute function private.tg_exam_totals();

create or replace function private.tg_question_marks() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.marks is distinct from old.marks then
    perform private.recalc_exam(eq.exam_id) from (select distinct exam_id from exam_questions where question_id = new.id and marks is null) eq;
  end if;
  return null;
end $$;
drop trigger if exists ep_question_marks on public.questions;
create trigger ep_question_marks after update of marks on public.questions for each row execute function private.tg_question_marks();

-- 3) admin roles always match their organization type
create or replace function private.admin_role_for(org_type text) returns text language sql immutable as
$$ select case org_type when 'college' then 'college_admin' when 'institute' then 'institute_admin' when 'root' then 'super_admin' end $$;

create or replace function private.tg_org_type() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type is distinct from old.type and new.type in ('college','institute') then
    update users set role = private.admin_role_for(new.type)
     where organization_id = new.id and role in ('college_admin','institute_admin') and role <> private.admin_role_for(new.type);
  end if;
  return null;
end $$;
drop trigger if exists ep_org_type on public.organizations;
create trigger ep_org_type after update of type on public.organizations for each row execute function private.tg_org_type();

create or replace function private.tg_user_role() returns trigger language plpgsql security definer set search_path = public as $$
declare ot text;
begin
  if tg_op = 'UPDATE' and new.role is not distinct from old.role and new.organization_id is not distinct from old.organization_id then return new; end if;
  if new.role in ('college_admin','institute_admin') then
    select type into ot from organizations where id = new.organization_id;
    if ot is null then perform private.fail('Please choose the organization this admin manages.'); end if;
    if new.role = 'college_admin' and ot <> 'college' then perform private.fail('A College Admin must belong to a college. Choose a college, or make this person an Institute Admin.'); end if;
    if new.role = 'institute_admin' and ot <> 'institute' then perform private.fail('An Institute Admin must belong to an institute. Choose an institute, or make this person a College Admin.'); end if;
  end if;
  new.email := lower(btrim(new.email));
  return new;
end $$;
drop trigger if exists ep_user_role on public.users;
create trigger ep_user_role before insert or update of role, organization_id, email on public.users for each row execute function private.tg_user_role();

-- ---------- delete: linked rows now follow automatically ----------
create or replace function private.act_crud_delete(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t text := p->>'table'; c jsonb := private.cfg_need(u, t, 'del'); ex jsonb; v_id uuid; n bigint; msg text := 'Deleted successfully.';
begin
  ex := private.load_scoped(u, s, t, private.juuid(p, 'id'));
  v_id := (ex->>'id')::uuid;
  if t = 'users' then
    if v_id = u.id then perform private.fail('You can''t delete your own account.'); end if;
    if ex->>'role' = 'super_admin' then perform private.fail('Super Admin accounts can''t be deleted from here.'); end if;
    if not private.can_manage(u, ex->>'role') then perform private.fail('You can''t delete this account.', '403'); end if;
  elsif t = 'organizations' then
    if ex->>'type' = 'root' then perform private.fail('The root organization can''t be deleted.'); end if;
    select count(*) into n from users where organization_id = v_id;
    if n > 0 then perform private.fail(format('This organization still has %s. Delete or move them first (Users page), or simply deactivate the organization.', private.plural(n, 'user account'))); end if;
  elsif t = 'questions' then
    if ex->>'organization_id' is null and u.role <> 'super_admin' then perform private.fail('Only the Super Admin can delete global questions.', '403'); end if;
    select count(*) into n from exam_questions where question_id = v_id;
    if n > 0 then perform private.fail(format('This question is used in %s. Remove it from those exams first, or archive it instead.', private.plural(n, 'exam'))); end if;
  elsif t = 'exam_categories' then
    select count(*) into n from subjects where exam_category_id = v_id;
    if n > 0 then msg := format('Deleted, together with its %s and their chapters and topics.', private.plural(n, 'subject')); end if;
  elsif t = 'subjects' then
    select count(*) into n from chapters where subject_id = v_id;
    if n > 0 then msg := format('Subject deleted with its %s. Questions keep their text but lose the subject link.', private.plural(n, 'chapter')); end if;
  elsif t = 'chapters' then
    select count(*) into n from topics where chapter_id = v_id;
    if n > 0 then msg := format('Chapter deleted with its %s.', private.plural(n, 'topic')); end if;
  end if;
  execute format('delete from public.%I where id = $1', t) using v_id;   -- linked rows are removed / unlinked by the foreign keys
  perform private.audit(u, 'delete', t, v_id::text, null, ex);
  return jsonb_build_object('message', msg);
end $$;

-- ---------- organization admins ----------
create or replace function private.scoped_org(s uuid[], oid uuid) returns public.organizations language plpgsql stable security definer set search_path = public as $$
declare o organizations;
begin
  select * into o from organizations where id = oid;
  if o.id is null or not private.in_scope(s, o.id) then perform private.fail('Organization not found or you don''t have access.', '404'); end if;
  return o;
end $$;

create or replace function private.act_org_admins(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare o organizations;
begin
  perform private.need(u, array['super_admin','college_admin']);
  o := private.scoped_org(s, private.req_uuid(p,'organization_id','organization'));
  return jsonb_build_object('organization', jsonb_build_object('id', o.id, 'name', o.name, 'type', o.type), 'admin_role', private.admin_role_for(o.type),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'full_name',x.full_name,'email',x.email,'phone',x.phone,'role',x.role,'is_active',x.is_active,
              'last_login_at',x.last_login_at,'created_at',x.created_at,'locked', x.locked_until > now()) order by x.created_at)
      from users x where x.organization_id = o.id and x.role in ('super_admin','college_admin','institute_admin')), '[]'));
end $$;

-- create or update an admin of an organization (role is set from the organization type)
create or replace function private.act_org_saveadmin(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare o organizations; rl text; d jsonb; r jsonb; uid uuid := private.juuid(p,'id');
begin
  perform private.need(u, array['super_admin','college_admin']);
  o := private.scoped_org(s, private.req_uuid(p,'organization_id','organization'));
  rl := private.admin_role_for(o.type);
  if rl = 'super_admin' and u.role <> 'super_admin' then perform private.fail('Only the Super Admin can add admins to the head office.', '403'); end if;
  if uid is null and private.jt(p,'password') is null then perform private.fail('Please set a password for the new admin.'); end if;
  d := jsonb_build_object('full_name', p->'full_name', 'email', p->'email', 'phone', p->'phone', 'role', rl, 'organization_id', o.id,
                          'is_active', coalesce(private.jbool(p,'is_active'), true));
  if private.jt(p,'password') is not null then d := d || jsonb_build_object('password', p->'password'); end if;
  r := private.act_crud_save(u, s || array[o.id], jsonb_build_object('table', 'users', 'id', uid, 'data', d));
  return jsonb_build_object('row', r->'row', 'message', case when uid is null then format('%s account created for %s.', private.role_label(rl), o.name) else 'Admin details updated.' end);
end $$;

-- organizations + their admins, for dashboards
create or replace function private.act_org_overview(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform private.need(u, private.r_admin());
  return jsonb_build_object('rows', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'name', o.name, 'type', o.type, 'city', o.city, 'is_active', o.is_active, 'logo_url', o.logo_url,
      'parent', private.nm_org(o.parent_id),
      'admins', coalesce((select jsonb_agg(jsonb_build_object('full_name', x.full_name, 'email', x.email, 'last_login_at', x.last_login_at) order by x.created_at)
                          from users x where x.organization_id = o.id and x.role in ('college_admin','institute_admin','super_admin') and coalesce(x.is_active,true)), '[]'),
      'students', (select count(*) from users x where x.organization_id = o.id and x.role = 'student'),
      'faculty', (select count(*) from users x where x.organization_id = o.id and x.role = 'faculty'),
      'exams', (select count(*) from exams e where e.organization_id = o.id)) order by case o.type when 'root' then 0 when 'college' then 1 else 2 end, o.name)
    from organizations o where private.in_scope(s, o.id)), '[]'));
end $$;

-- who am I + backend version (lets the website warn when the database needs the latest setup SQL)
create or replace function private.act_auth_me(u public.users, s uuid[], p jsonb) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('user', private.user_json(u), 'unread', (select count(*) from notifications where user_id = u.id and not coalesce(is_read,false)),
    'backend_version', private.backend_version(),
    'org_admins', coalesce((select jsonb_agg(jsonb_build_object('full_name', x.full_name, 'email', x.email, 'phone', x.phone))
       from users x where x.organization_id = u.organization_id and x.role in ('college_admin','institute_admin') and coalesce(x.is_active,true) and x.id <> u.id), '[]'))
$$;

-- =====================================================================
--  STUDENTS – full student records in their own table, linked to
--  users (login), organizations, batches and exam categories
-- =====================================================================
create table if not exists public.students (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null unique,
  organization_id   uuid,
  batch_id          uuid,            -- main batch (a student can still be in more batches via batch_members)
  exam_category_id  uuid,            -- target exam (JEE Main, NEET UG, Aptitude …)
  admission_no      text,
  roll_number       text,
  admission_date    date,
  date_of_birth     date,
  gender            text check (gender is null or gender in ('male','female','other')),
  blood_group       text check (blood_group is null or blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  category          text check (category is null or category in ('General','OBC','SC','ST','EWS','Other')),
  nationality       text default 'Indian',
  alt_phone         text,
  address_line      text,
  city              text,
  state             text,
  pincode           text,
  father_name       text,
  father_phone      text,
  father_occupation text,
  mother_name       text,
  mother_phone      text,
  guardian_email    text,
  school_name       text,
  board             text,
  class_10_percent  numeric check (class_10_percent is null or class_10_percent between 0 and 100),
  class_12_percent  numeric check (class_12_percent is null or class_12_percent between 0 and 100),
  passing_year      int,
  fee_total         numeric check (fee_total is null or fee_total >= 0),
  fee_paid          numeric check (fee_paid is null or fee_paid >= 0),
  fee_status        text not null default 'pending' check (fee_status in ('paid','partial','pending')),
  status            text not null default 'active' check (status in ('active','on_hold','left','completed')),
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
-- if the table already existed with fewer columns, add the missing ones
do $$
declare c record;
begin
  for c in select * from (values ('organization_id','uuid'),('batch_id','uuid'),('exam_category_id','uuid'),('admission_no','text'),('roll_number','text'),
      ('admission_date','date'),('date_of_birth','date'),('gender','text'),('blood_group','text'),('category','text'),('nationality','text'),('alt_phone','text'),
      ('address_line','text'),('city','text'),('state','text'),('pincode','text'),('father_name','text'),('father_phone','text'),('father_occupation','text'),
      ('mother_name','text'),('mother_phone','text'),('guardian_email','text'),('school_name','text'),('board','text'),('class_10_percent','numeric'),
      ('class_12_percent','numeric'),('passing_year','int'),('fee_total','numeric'),('fee_paid','numeric'),('fee_status','text'),('status','text'),('notes','text'),
      ('created_at','timestamptz'),('updated_at','timestamptz')) v(col, typ) loop
    execute format('alter table public.students add column if not exists %I %s', c.col, c.typ);
  end loop;
end $$;

-- links (edit / delete in one table updates the others)
select private.relink('students', 'user_id', 'users', 'cascade');                     -- delete the login → the student record goes too
select private.relink('students', 'organization_id', 'organizations', 'set null');
select private.relink('students', 'batch_id', 'batches', 'set null');
select private.relink('students', 'exam_category_id', 'exam_categories', 'set null');
create unique index if not exists ux_students_admission on public.students(organization_id, admission_no) where admission_no is not null;
create index if not exists ix_students_org on public.students(organization_id);
create index if not exists ix_students_batch on public.students(batch_id);

alter table public.students enable row level security;
do $$ declare pol record; begin
  for pol in select policyname from pg_policies where schemaname = 'public' and tablename = 'students' loop
    execute format('drop policy if exists %I on public.students', pol.policyname);
  end loop;
end $$;
revoke all on public.students from anon, authenticated;

drop trigger if exists students_updated_at on public.students;
create trigger students_updated_at before update on public.students for each row execute function private.tg_updated_at();

-- ---------- keep students in step with users and batches ----------
create or replace function private.tg_student_from_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'student' then
    insert into students(user_id, organization_id, roll_number, admission_date)
    values (new.id, new.organization_id, new.roll_number, coalesce(new.created_at, now())::date)
    on conflict (user_id) do update set organization_id = excluded.organization_id, roll_number = coalesce(excluded.roll_number, students.roll_number);
  elsif tg_op = 'UPDATE' and old.role = 'student' then
    delete from students where user_id = new.id;              -- no longer a student
  end if;
  return new;
end $$;
drop trigger if exists users_student_sync on public.users;
create trigger users_student_sync after insert or update of role, organization_id, roll_number on public.users
  for each row execute function private.tg_student_from_user();

create or replace function private.tg_student_batch() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update students s set batch_id = new.batch_id,
           exam_category_id = coalesce(s.exam_category_id, (select b.exam_category_id from batches b where b.id = new.batch_id))
     where s.user_id = new.user_id and s.batch_id is null;
    return new;
  end if;
  update students s set batch_id = (select m.batch_id from batch_members m where m.user_id = old.user_id and m.batch_id <> old.batch_id order by m.joined_at limit 1)
   where s.user_id = old.user_id and s.batch_id = old.batch_id;
  return old;
end $$;
drop trigger if exists batch_members_student_sync on public.batch_members;
create trigger batch_members_student_sync after insert or delete on public.batch_members for each row execute function private.tg_student_batch();

-- a student record for every existing student account
insert into public.students(user_id, organization_id, roll_number, admission_date, batch_id, exam_category_id)
select u.id, u.organization_id, u.roll_number, u.created_at::date,
       (select m.batch_id from public.batch_members m where m.user_id = u.id order by m.joined_at limit 1),
       (select b.exam_category_id from public.batch_members m join public.batches b on b.id = m.batch_id where m.user_id = u.id order by m.joined_at limit 1)
from public.users u where u.role = 'student'
on conflict (user_id) do nothing;

-- ---------- one student as JSON ----------
create or replace function private.student_row(uid uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select (to_jsonb(s) - 'id' - 'user_id') || jsonb_build_object(
    'id', u.id, 'student_id', s.id, 'full_name', u.full_name, 'email', u.email, 'phone', u.phone, 'avatar_url', u.avatar_url,
    'is_active', u.is_active, 'last_login_at', u.last_login_at, 'roll_number', coalesce(s.roll_number, u.roll_number),
    'organization', private.nm_org(u.organization_id), 'batch', private.nm_batch(s.batch_id), 'exam_category', private.nm_cat(s.exam_category_id),
    'batches', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name) order by b.name) from batch_members m join batches b on b.id = m.batch_id where m.user_id = u.id), '[]'),
    'fee_due', greatest(coalesce(s.fee_total, 0) - coalesce(s.fee_paid, 0), 0),
    'age', case when s.date_of_birth is not null then extract(year from age(s.date_of_birth))::int end)
  from users u left join students s on s.user_id = u.id where u.id = uid and u.role = 'student' $$;

-- ---------- student.list ----------
create or replace function private.act_student_list(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare pg int := greatest(coalesce(private.jint(p, 'page'), 1), 1); ps int := least(greatest(coalesce(private.jint(p, 'pageSize'), 20), 1), 200);
        q text := lower(private.jt(p, 'search')); f jsonb := coalesce(p->'filters', '{}'); bid uuid := private.juuid(f, 'batch_id');
        oid uuid := private.juuid(f, 'organization_id'); st text := private.jt(f, 'status'); fee text := private.jt(f, 'fee_status');
        tot bigint; rows jsonb;
begin
  perform private.need(u, private.r_staff());
  with base as (
    select u2.id from users u2 left join students x on x.user_id = u2.id
    where u2.role = 'student' and private.in_scope(s, u2.organization_id)
      and (oid is null or u2.organization_id = oid)
      and (bid is null or exists (select 1 from batch_members m where m.user_id = u2.id and m.batch_id = bid))
      and (u.role <> 'faculty' or exists (select 1 from batch_members m where m.user_id = u2.id and m.batch_id = any(private.my_batches(u.id))))
      and (st is null or x.status = st) and (fee is null or x.fee_status = fee)
      and (q is null or lower(u2.full_name) like '%' || q || '%' or lower(u2.email) like '%' || q || '%' or lower(coalesce(x.roll_number, u2.roll_number, '')) like '%' || q || '%'
           or lower(coalesce(x.admission_no, '')) like '%' || q || '%' or coalesce(u2.phone, '') like '%' || q || '%' or lower(coalesce(x.city, '') || ' ' || coalesce(x.address_line, '')) like '%' || q || '%'
           or lower(coalesce(x.father_name, '')) like '%' || q || '%')
  )
  select count(*) into tot from base;
  select coalesce(jsonb_agg(r order by r->>'roll_number' nulls last, r->>'full_name'), '[]') into rows from (
    select private.student_row(u2.id) || jsonb_build_object(
      'exams_taken', (select count(*) from results r where r.user_id = u2.id),
      'avg_percent', (select round(avg(r.percentage), 1) from results r where r.user_id = u2.id)) r
    from users u2 left join students x on x.user_id = u2.id
    where u2.role = 'student' and private.in_scope(s, u2.organization_id)
      and (oid is null or u2.organization_id = oid)
      and (bid is null or exists (select 1 from batch_members m where m.user_id = u2.id and m.batch_id = bid))
      and (u.role <> 'faculty' or exists (select 1 from batch_members m where m.user_id = u2.id and m.batch_id = any(private.my_batches(u.id))))
      and (st is null or x.status = st) and (fee is null or x.fee_status = fee)
      and (q is null or lower(u2.full_name) like '%' || q || '%' or lower(u2.email) like '%' || q || '%' or lower(coalesce(x.roll_number, u2.roll_number, '')) like '%' || q || '%'
           or lower(coalesce(x.admission_no, '')) like '%' || q || '%' or coalesce(u2.phone, '') like '%' || q || '%' or lower(coalesce(x.city, '') || ' ' || coalesce(x.address_line, '')) like '%' || q || '%'
           or lower(coalesce(x.father_name, '')) like '%' || q || '%')
    order by coalesce(x.roll_number, u2.roll_number) nulls last, u2.full_name
    limit ps offset (pg - 1) * ps) z;
  return jsonb_build_object('rows', rows, 'total', tot, 'page', pg, 'pageSize', ps,
    'summary', (select jsonb_build_object('total', count(*), 'active', count(*) filter (where x.status = 'active'),
                  'fee_pending', count(*) filter (where x.fee_status <> 'paid'), 'female', count(*) filter (where x.gender = 'female'), 'male', count(*) filter (where x.gender = 'male'))
                from users u2 left join students x on x.user_id = u2.id where u2.role = 'student' and private.in_scope(s, u2.organization_id)
                  and (u.role <> 'faculty' or exists (select 1 from batch_members m where m.user_id = u2.id and m.batch_id = any(private.my_batches(u.id))))));
end $$;

-- ---------- student.get (staff in scope, or the student themself) ----------
create or replace function private.act_student_get(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare sid uuid := coalesce(private.juuid(p, 'id'), case when u.role = 'student' then u.id end); st public.users; r jsonb;
begin
  select * into st from users where id = sid and role = 'student';
  if st.id is null then perform private.fail('Please select a valid student.'); end if;
  if u.role = 'student' and u.id <> st.id then perform private.fail('You don''t have permission to do this.', '403'); end if;
  if u.role <> 'student' and not private.in_scope(s, st.organization_id) then perform private.fail('You don''t have permission to do this.', '403'); end if;
  r := private.student_row(st.id);
  return jsonb_build_object('student', r,
    'results', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'exam_id', e.id, 'title', e.title, 'score', x.total_score, 'max', x.max_score, 'percentage', x.percentage,
                    'rank', x.rank, 'date', x.created_at) order by x.created_at desc) from results x join exams e on e.id = x.exam_id where x.user_id = st.id and (x.is_visible or u.role <> 'student')), '[]'),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('title', a.title, 'status', z.status, 'marks', z.marks_obtained, 'max', a.max_marks, 'submitted_at', z.submitted_at)
                    order by z.submitted_at desc) from assignment_submissions z join assignments a on a.id = z.assignment_id where z.user_id = st.id), '[]'),
    'engagement', private.engagement_score(st.id));
end $$;

-- ---------- student.save (admins: create or update a student with full details) ----------
create or replace function private.act_student_save(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare d jsonb := coalesce(p->'data', p); sid uuid := private.juuid(d, 'id'); ex public.users; org uuid; res jsonb; bids uuid[]; b uuid; v text;
        msg text; t10 numeric; t12 numeric;
begin
  perform private.need(u, private.r_admin());
  -- checks with clear messages
  if private.jt(d, 'full_name') is null then perform private.fail('Please enter the student''s full name.'); end if;
  if private.jt(d, 'email') is null or private.jt(d, 'email') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then perform private.fail('Please enter a valid email address.'); end if;
  foreach v in array array['phone', 'alt_phone', 'father_phone', 'mother_phone'] loop
    if private.jt(d, v) is not null and regexp_replace(private.jt(d, v), '[^0-9]', '', 'g') !~ '^(91)?[0-9]{10}$' then
      perform private.fail(format('Please enter a valid 10-digit %s.', replace(replace(v, '_', ' '), 'phone', 'phone number')));
    end if;
  end loop;
  if private.jt(d, 'pincode') is not null and private.jt(d, 'pincode') !~ '^[1-9][0-9]{5}$' then perform private.fail('Please enter a valid 6-digit PIN code.'); end if;
  if private.jt(d, 'guardian_email') is not null and private.jt(d, 'guardian_email') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then perform private.fail('Please enter a valid guardian email address.'); end if;
  if private.jt(d, 'date_of_birth') is not null and (private.jt(d, 'date_of_birth'))::date > current_date - interval '10 years' then perform private.fail('Please check the date of birth.'); end if;
  t10 := private.jnum(d, 'class_10_percent'); t12 := private.jnum(d, 'class_12_percent');
  if (t10 is not null and (t10 < 0 or t10 > 100)) or (t12 is not null and (t12 < 0 or t12 > 100)) then perform private.fail('Percentages must be between 0 and 100.'); end if;
  if private.jnum(d, 'fee_paid') is not null and private.jnum(d, 'fee_total') is not null and private.jnum(d, 'fee_paid') > private.jnum(d, 'fee_total') then
    perform private.fail('Fee paid can''t be more than the total fee.'); end if;

  if sid is not null then
    select * into ex from users where id = sid and role = 'student';
    if ex.id is null or not private.in_scope(s, ex.organization_id) then perform private.fail('Please select a valid student.'); end if;
  end if;
  org := coalesce(case when u.role in ('super_admin', 'college_admin') then private.juuid(d, 'organization_id') end, ex.organization_id, u.organization_id);
  if org is null then perform private.fail('Please choose the student''s organization.'); end if;
  if not private.in_scope(s, org) then perform private.fail('You can''t add students to this organization.', '403'); end if;
  if sid is null and private.jt(d, 'password') is null then perform private.fail('Please set a password for the student''s login.'); end if;
  if private.jt(d, 'admission_no') is not null and exists (select 1 from students x where x.organization_id = org and x.admission_no = private.jt(d, 'admission_no') and x.user_id is distinct from sid) then
    perform private.fail('This admission number is already used by another student.'); end if;

  -- 1) the login (users table) – reuses the standard save so passwords, audit and rules stay the same
  res := private.act_crud_save(u, s, jsonb_strip_nulls(jsonb_build_object('table', 'users', 'id', sid)) || jsonb_build_object('data', jsonb_strip_nulls(jsonb_build_object(
           'full_name', private.jt(d, 'full_name'), 'email', lower(private.jt(d, 'email')), 'phone', private.jt(d, 'phone'),
           'password', private.jt(d, 'password'), 'role', 'student', 'organization_id', org, 'roll_number', private.jt(d, 'roll_number'),
           'is_active', coalesce(private.jbool(d, 'is_active'), true), 'avatar_url', private.jt(d, 'avatar_url')))));
  sid := (res->'row'->>'id')::uuid;

  -- 2) the full student record (students table – the row already exists thanks to the trigger)
  insert into students(user_id, organization_id) values (sid, org) on conflict (user_id) do nothing;
  update students x set
    organization_id = org, roll_number = private.jt(d, 'roll_number'), admission_no = private.jt(d, 'admission_no'),
    admission_date = coalesce((private.jt(d, 'admission_date'))::date, x.admission_date), date_of_birth = (private.jt(d, 'date_of_birth'))::date,
    gender = private.jt(d, 'gender'), blood_group = private.jt(d, 'blood_group'), category = private.jt(d, 'category'),
    nationality = coalesce(private.jt(d, 'nationality'), 'Indian'), alt_phone = private.jt(d, 'alt_phone'),
    address_line = private.jt(d, 'address_line'), city = private.jt(d, 'city'), state = private.jt(d, 'state'), pincode = private.jt(d, 'pincode'),
    father_name = private.jt(d, 'father_name'), father_phone = private.jt(d, 'father_phone'), father_occupation = private.jt(d, 'father_occupation'),
    mother_name = private.jt(d, 'mother_name'), mother_phone = private.jt(d, 'mother_phone'), guardian_email = lower(private.jt(d, 'guardian_email')),
    school_name = private.jt(d, 'school_name'), board = private.jt(d, 'board'), class_10_percent = t10, class_12_percent = t12,
    passing_year = private.jint(d, 'passing_year'), exam_category_id = private.juuid(d, 'exam_category_id'),
    fee_total = private.jnum(d, 'fee_total'), fee_paid = private.jnum(d, 'fee_paid'),
    fee_status = case when coalesce(private.jnum(d, 'fee_total'), 0) > 0 and coalesce(private.jnum(d, 'fee_paid'), 0) >= private.jnum(d, 'fee_total') then 'paid'
                      when coalesce(private.jnum(d, 'fee_paid'), 0) > 0 then 'partial' else 'pending' end,
    status = coalesce(private.jt(d, 'status'), 'active'), notes = private.jt(d, 'notes')
  where x.user_id = sid;

  -- 3) batches (batch_members table): the batches ticked in the form
  if d ? 'batch_ids' then
    bids := private.uuids(d->'batch_ids');
    if exists (select 1 from unnest(bids) z left join batches bb on bb.id = z where bb.id is null or bb.organization_id <> org) then
      perform private.fail('Please choose batches from the student''s own organization.'); end if;
    delete from batch_members m where m.user_id = sid and not (m.batch_id = any(bids));
    foreach b in array bids loop
      insert into batch_members(batch_id, user_id, role_in_batch) select b, sid, 'student'
      where not exists (select 1 from batch_members m where m.batch_id = b and m.user_id = sid);
    end loop;
    update students x set batch_id = case when x.batch_id = any(bids) then x.batch_id else bids[1] end where x.user_id = sid;
  end if;

  perform private.audit(u, case when ex.id is null then 'create' else 'update' end, 'students', sid::text, jsonb_build_object('full_name', private.jt(d, 'full_name')));
  msg := case when ex.id is null then 'Student added with full details.' else 'Student details saved.' end;
  return jsonb_build_object('row', private.student_row(sid), 'message', msg);
end $$;

-- ---------- student.updatemine (a student keeps their own contact details up to date) ----------
create or replace function private.act_student_updatemine(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare d jsonb := coalesce(p->'data', p); v text;
begin
  perform private.need(u, array['student']);
  foreach v in array array['alt_phone', 'father_phone', 'mother_phone'] loop
    if private.jt(d, v) is not null and regexp_replace(private.jt(d, v), '[^0-9]', '', 'g') !~ '^(91)?[0-9]{10}$' then
      perform private.fail('Please enter a valid 10-digit phone number.'); end if;
  end loop;
  if private.jt(d, 'pincode') is not null and private.jt(d, 'pincode') !~ '^[1-9][0-9]{5}$' then perform private.fail('Please enter a valid 6-digit PIN code.'); end if;
  insert into students(user_id, organization_id) values (u.id, u.organization_id) on conflict (user_id) do nothing;
  update students set alt_phone = private.jt(d, 'alt_phone'), address_line = private.jt(d, 'address_line'), city = private.jt(d, 'city'),
         state = private.jt(d, 'state'), pincode = private.jt(d, 'pincode'), father_phone = private.jt(d, 'father_phone'), mother_phone = private.jt(d, 'mother_phone')
   where user_id = u.id;
  return jsonb_build_object('row', private.student_row(u.id), 'message', 'Your details have been updated.');
end $$;


-- =====================================================================
--  FULL DATA EXPORT per organization (super admin: any / all; other admins: their own scope)
--  export.org  { organization_id?: uuid, include_children?: bool, sheets?: [names] }
-- =====================================================================
create or replace function private.act_export_org(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare oid uuid := private.juuid(p, 'organization_id'); kids boolean := coalesce(private.jbool(p, 'include_children'), true);
        want text[] := private.jarr(p->'sheets'); orgs uuid[]; ttl text; sheets jsonb := '[]'; cols jsonb; rows jsonb;
        fmt_d text := 'DD-Mon-YYYY'; fmt_dt text := 'DD-Mon-YYYY HH24:MI';
begin
  perform private.need(u, private.r_admin());
  -- full data downloads are for the KDRT super admin only; college admins may read the overview numbers on their dashboard
  if u.role <> 'super_admin' and not (cardinality(want) = 1 and want[1] = 'overview') then
    perform private.fail('Only the KDRT super admin can download full data.', '403');
  end if;
  if oid is not null then
    if not private.in_scope(s, oid) then perform private.fail('You can''t export data of this organization.', '403'); end if;
    orgs := array[oid] || case when kids then coalesce(array(select id from organizations where parent_id = oid and private.in_scope(s, id)), '{}') else '{}' end;
    select name into ttl from organizations where id = oid;
  else
    orgs := coalesce(array(select id from organizations where private.in_scope(s, id)), '{}');
    ttl := case when u.role = 'super_admin' then 'All organizations' else 'My organizations' end;
  end if;
  if cardinality(want) = 0 then want := array['overview','staff','students','batches','exams','results','assignments','submissions','engagement']; end if;

  -- 1) overview: one row per organization
  if 'overview' = any(want) then
    cols := '["Organization","Code","Type","Parent","City","Admins","Faculty","Students","Active students (7 days)","Batches","Exams","Live / scheduled","Results","Average %","Pass %","Assignments","Submissions","Fees collected (₹)","Fees due (₹)"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, o.code, initcap(o.type), (select name from organizations x where x.id = o.parent_id), o.city,
        (select string_agg(a.full_name, ', ') from users a where a.organization_id = o.id and a.role in ('college_admin','institute_admin')),
        (select count(*) from users f where f.organization_id = o.id and f.role = 'faculty'),
        (select count(*) from users st where st.organization_id = o.id and st.role = 'student'),
        (select count(*) from users st where st.organization_id = o.id and st.role = 'student' and st.last_login_at > now() - interval '7 days'),
        (select count(*) from batches b where b.organization_id = o.id),
        (select count(*) from exams e where e.organization_id = o.id),
        (select count(*) from exams e where e.organization_id = o.id and e.status in ('live','scheduled')),
        (select count(*) from results r join exams e on e.id = r.exam_id where e.organization_id = o.id),
        (select round(avg(r.percentage), 1) from results r join exams e on e.id = r.exam_id where e.organization_id = o.id),
        (select round(100.0 * count(*) filter (where r.percentage >= coalesce(e.pass_percentage, 33)) / nullif(count(*), 0), 1) from results r join exams e on e.id = r.exam_id where e.organization_id = o.id),
        (select count(*) from assignments a where a.organization_id = o.id),
        (select count(*) from assignment_submissions z join assignments a on a.id = z.assignment_id where a.organization_id = o.id),
        (select coalesce(sum(fee_paid), 0) from students x where x.organization_id = o.id),
        (select coalesce(sum(greatest(coalesce(fee_total,0) - coalesce(fee_paid,0), 0)), 0) from students x where x.organization_id = o.id)
      ) order by o.type, o.name), '[]') into rows from organizations o where o.id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Overview', 'columns', cols, 'rows', rows);
  end if;

  -- 2) staff (admins + faculty)
  if 'staff' = any(want) then
    cols := '["Name","Email","Phone","Role","Organization","Active","Last sign-in","Joined"]';
    select coalesce(jsonb_agg(jsonb_build_array(x.full_name, x.email, x.phone, private.role_label(x.role), o.name, case when coalesce(x.is_active, true) then 'Yes' else 'No' end,
        to_char(x.last_login_at at time zone 'Asia/Kolkata', fmt_dt), to_char(x.created_at at time zone 'Asia/Kolkata', fmt_d)) order by o.name, private.rank(x.role) desc, x.full_name), '[]')
      into rows from users x join organizations o on o.id = x.organization_id where x.organization_id = any(orgs) and x.role <> 'student';
    sheets := sheets || jsonb_build_object('name', 'Staff', 'columns', cols, 'rows', rows);
  end if;

  -- 3) students – full record
  if 'students' = any(want) then
    cols := '["Roll no.","Admission no.","Name","Email","Phone","Organization","Batches","Target exam","Admission date","Date of birth","Gender","Blood group","Category","Address","City","State","PIN","Father","Father phone","Father occupation","Mother","Mother phone","Guardian email","School / college","Board","Class 10 %","Class 12 %","Passing year","Total fee (₹)","Paid (₹)","Due (₹)","Fee status","Status","Login active","Exams taken","Average %","Last sign-in","Notes"]';
    select coalesce(jsonb_agg(jsonb_build_array(coalesce(sx.roll_number, x.roll_number), sx.admission_no, x.full_name, x.email, x.phone, o.name,
        (select string_agg(b.name, ', ' order by b.name) from batch_members m join batches b on b.id = m.batch_id where m.user_id = x.id),
        (select name from exam_categories c where c.id = sx.exam_category_id), to_char(sx.admission_date, fmt_d), to_char(sx.date_of_birth, fmt_d), initcap(sx.gender), sx.blood_group, sx.category,
        sx.address_line, sx.city, sx.state, sx.pincode, sx.father_name, sx.father_phone, sx.father_occupation, sx.mother_name, sx.mother_phone, sx.guardian_email,
        sx.school_name, sx.board, sx.class_10_percent, sx.class_12_percent, sx.passing_year, sx.fee_total, sx.fee_paid, greatest(coalesce(sx.fee_total,0) - coalesce(sx.fee_paid,0), 0),
        initcap(replace(sx.fee_status, '_', ' ')), initcap(replace(sx.status, '_', ' ')), case when coalesce(x.is_active, true) then 'Yes' else 'No' end,
        (select count(*) from results r where r.user_id = x.id), (select round(avg(r.percentage), 1) from results r where r.user_id = x.id),
        to_char(x.last_login_at at time zone 'Asia/Kolkata', fmt_dt), sx.notes) order by o.name, coalesce(sx.roll_number, x.roll_number), x.full_name), '[]')
      into rows from users x join organizations o on o.id = x.organization_id left join students sx on sx.user_id = x.id
     where x.organization_id = any(orgs) and x.role = 'student';
    sheets := sheets || jsonb_build_object('name', 'Students', 'columns', cols, 'rows', rows);
  end if;

  -- 4) batches
  if 'batches' = any(want) then
    cols := '["Organization","Batch","Code","Academic year","Exam type","Start","End","Students","Faculty","Active"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, b.name, b.code, b.academic_year, (select name from exam_categories c where c.id = b.exam_category_id),
        to_char(b.start_date, fmt_d), to_char(b.end_date, fmt_d),
        (select count(*) from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id and x.role = 'student'),
        (select string_agg(x.full_name, ', ') from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id and x.role <> 'student'),
        case when coalesce(b.is_active, true) then 'Yes' else 'No' end) order by o.name, b.name), '[]')
      into rows from batches b join organizations o on o.id = b.organization_id where b.organization_id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Batches', 'columns', cols, 'rows', rows);
  end if;

  -- 5) exams
  if 'exams' = any(want) then
    cols := '["Organization","Exam","Exam type","Status","Starts","Ends","Duration (min)","Questions","Total marks","Pass %","Batches","Attempts","Average %","Highest %","Pass rate %","Created by"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, e.title, (select name from exam_categories c where c.id = e.exam_category_id), initcap(e.status),
        to_char(e.start_time at time zone 'Asia/Kolkata', fmt_dt), to_char(e.end_time at time zone 'Asia/Kolkata', fmt_dt), e.duration_minutes, e.total_questions, e.total_marks, e.pass_percentage,
        (select string_agg(b.name, ', ') from exam_assignments ea join batches b on b.id = ea.batch_id where ea.exam_id = e.id),
        (select count(*) from results r where r.exam_id = e.id), (select round(avg(r.percentage), 1) from results r where r.exam_id = e.id),
        (select max(r.percentage) from results r where r.exam_id = e.id),
        (select round(100.0 * count(*) filter (where r.percentage >= coalesce(e.pass_percentage, 33)) / nullif(count(*), 0), 1) from results r where r.exam_id = e.id),
        (select full_name from users c where c.id = e.created_by)) order by o.name, e.start_time desc nulls last), '[]')
      into rows from exams e join organizations o on o.id = e.organization_id where e.organization_id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Exams', 'columns', cols, 'rows', rows);
  end if;

  -- 6) results – every student's score in every exam
  if 'results' = any(want) then
    cols := '["Organization","Exam","Roll no.","Student","Batch","Score","Max","Percentage","Result","Rank","Percentile","Accuracy %","Time (min)","Tab switches","Submitted"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, e.title, coalesce(sx.roll_number, x.roll_number), x.full_name, (select name from batches b where b.id = sx.batch_id),
        r.total_score, r.max_score, r.percentage, case when r.percentage >= coalesce(e.pass_percentage, 33) then 'Pass' else 'Fail' end, r.rank, r.percentile, r.accuracy,
        round(coalesce(r.time_spent_seconds, 0) / 60.0, 1), (select a.tab_switches from exam_attempts a where a.id = r.exam_attempt_id),
        to_char(r.created_at at time zone 'Asia/Kolkata', fmt_dt)) order by o.name, e.title, r.rank nulls last), '[]')
      into rows from results r join exams e on e.id = r.exam_id join organizations o on o.id = e.organization_id join users x on x.id = r.user_id left join students sx on sx.user_id = x.id
     where e.organization_id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Results', 'columns', cols, 'rows', rows);
  end if;

  -- 7) assignments
  if 'assignments' = any(want) then
    cols := '["Organization","Assignment","Type","Max marks","Deadline","Status","Batches","Submissions","Evaluated","Average marks","Created by"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, a.title, initcap(a.assignment_type), a.max_marks, to_char(a.deadline at time zone 'Asia/Kolkata', fmt_dt), initcap(a.status),
        (select string_agg(b.name, ', ') from assignment_batches ab join batches b on b.id = ab.batch_id where ab.assignment_id = a.id),
        (select count(*) from assignment_submissions z where z.assignment_id = a.id),
        (select count(*) from assignment_submissions z where z.assignment_id = a.id and z.status = 'evaluated'),
        (select round(avg(z.marks_obtained), 1) from assignment_submissions z where z.assignment_id = a.id),
        (select full_name from users c where c.id = a.created_by)) order by o.name, a.created_at desc), '[]')
      into rows from assignments a join organizations o on o.id = a.organization_id where a.organization_id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Assignments', 'columns', cols, 'rows', rows);
  end if;

  -- 8) submissions
  if 'submissions' = any(want) then
    cols := '["Organization","Assignment","Roll no.","Student","Submitted","Status","Marks","Max","Feedback","Evaluated by"]';
    select coalesce(jsonb_agg(jsonb_build_array(o.name, a.title, coalesce(sx.roll_number, x.roll_number), x.full_name, to_char(z.submitted_at at time zone 'Asia/Kolkata', fmt_dt),
        initcap(replace(z.status, '_', ' ')), z.marks_obtained, a.max_marks, z.feedback, (select full_name from users c where c.id = z.evaluated_by)) order by o.name, a.title, x.full_name), '[]')
      into rows from assignment_submissions z join assignments a on a.id = z.assignment_id join organizations o on o.id = a.organization_id
      join users x on x.id = z.user_id left join students sx on sx.user_id = x.id where a.organization_id = any(orgs);
    sheets := sheets || jsonb_build_object('name', 'Submissions', 'columns', cols, 'rows', rows);
  end if;

  -- 9) engagement
  if 'engagement' = any(want) then
    cols := '["Organization","Roll no.","Student","Batch","Engagement score","Level","Days inactive","Logins (14 days)","Exams (30 days)","Submissions (30 days)","Pending work","Last activity"]';
    select coalesce(jsonb_agg(jsonb_build_array(z.org, z.roll, z.full_name, z.batch, z.e->'score', z.e->>'level', z.e->'days_inactive', z.e->'logins_14d', z.e->'exams_30d',
        z.e->'submissions_30d', z.e->'pending', to_char((z.e->>'last_activity')::timestamptz at time zone 'Asia/Kolkata', fmt_dt)) order by z.org, (z.e->>'score')::int), '[]')
      into rows from (select o.name org, coalesce(sx.roll_number, x.roll_number) roll, x.full_name, (select name from batches b where b.id = sx.batch_id) batch, private.engagement_score(x.id) e
                        from users x join organizations o on o.id = x.organization_id left join students sx on sx.user_id = x.id
                       where x.organization_id = any(orgs) and x.role = 'student') z;
    sheets := sheets || jsonb_build_object('name', 'Engagement', 'columns', cols, 'rows', rows);
  end if;

  if not (cardinality(want) = 1 and want[1] = 'overview') then perform private.audit(u, 'export', 'organizations', coalesce(oid::text, 'all'), jsonb_build_object('sheets', want, 'organizations', cardinality(orgs))); end if;
  return jsonb_build_object('title', 'Full data – ' || ttl, 'organization', ttl, 'generated_at', now(), 'sheets', sheets);
end $$;

-- =====================================================================
--  BATCH DETAIL – everything about one batch in one call
--  batch.detail { batch_id }
-- =====================================================================
create or replace function private.act_batch_detail(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare b batches; stu uuid[]; ex uuid[]; res jsonb;
begin
  perform private.need(u, private.r_staff());
  b := private.scoped_batch(s, private.req_uuid(p, 'batch_id', 'batch'));
  if u.role = 'faculty' and not (b.id = any(private.my_batches(u.id))) then
    perform private.fail('You can only open batches you teach.', '403');
  end if;
  stu := coalesce(array(select m.user_id from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id and x.role = 'student'), '{}');
  ex  := coalesce(array(select ea.exam_id from exam_assignments ea where ea.batch_id = b.id), '{}');

  res := jsonb_build_object(
    'batch', to_jsonb(b) || jsonb_build_object('organization', private.nm_org(b.organization_id), 'exam_category', private.nm_cat(b.exam_category_id),
                                               'created_by_name', (select full_name from users where id = b.created_by)),
    'stats', jsonb_build_object(
      'students', cardinality(stu),
      'faculty', (select count(*) from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id and x.role <> 'student'),
      'active_7d', (select count(*) from users x where x.id = any(stu) and x.last_login_at > now() - interval '7 days'),
      'exams', cardinality(ex),
      'exams_completed', (select count(*) from exams e where e.id = any(ex) and e.status = 'completed'),
      'exams_open', (select count(*) from exams e where e.id = any(ex) and e.status in ('live', 'scheduled')),
      'results', (select count(*) from results r where r.exam_id = any(ex) and r.user_id = any(stu)),
      'avg_percent', (select round(avg(r.percentage), 1) from results r where r.exam_id = any(ex) and r.user_id = any(stu)),
      'pass_rate', (select round(100.0 * count(*) filter (where r.percentage >= coalesce(e.pass_percentage, 33)) / nullif(count(*), 0), 1)
                      from results r join exams e on e.id = r.exam_id where r.exam_id = any(ex) and r.user_id = any(stu)),
      'assignments', (select count(*) from assignment_batches ab where ab.batch_id = b.id),
      'submission_rate', (select round(100.0 * count(z.*) / nullif(count(distinct ab.assignment_id) * cardinality(stu), 0), 1)
                            from assignment_batches ab left join assignment_submissions z on z.assignment_id = ab.assignment_id and z.user_id = any(stu) where ab.batch_id = b.id),
      'fee_collected', (select coalesce(sum(fee_paid), 0) from students x where x.user_id = any(stu)),
      'fee_due', (select coalesce(sum(greatest(coalesce(fee_total, 0) - coalesce(fee_paid, 0), 0)), 0) from students x where x.user_id = any(stu))),
    'faculty', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'full_name', x.full_name, 'email', x.email, 'phone', x.phone, 'role', m.role_in_batch,
                    'questions', (select count(*) from questions q where q.created_by = x.id)) order by m.role_in_batch, x.full_name)
                  from batch_members m join users x on x.id = m.user_id where m.batch_id = b.id and x.role <> 'student'), '[]'),
    'students', coalesce((select jsonb_agg(z order by z->>'roll_number' nulls last, z->>'full_name') from (
        select jsonb_build_object('id', x.id, 'full_name', x.full_name, 'email', x.email, 'phone', x.phone, 'avatar_url', x.avatar_url,
          'roll_number', coalesce(sx.roll_number, x.roll_number), 'admission_no', sx.admission_no, 'gender', sx.gender, 'father_phone', sx.father_phone,
          'fee_status', sx.fee_status, 'status', sx.status, 'last_login_at', x.last_login_at,
          'exams_taken', (select count(*) from results r where r.user_id = x.id and r.exam_id = any(ex)),
          'avg_percent', (select round(avg(r.percentage), 1) from results r where r.user_id = x.id and r.exam_id = any(ex)),
          'best_rank', (select min(r.rank) from results r where r.user_id = x.id and r.exam_id = any(ex)),
          'submissions', (select count(*) from assignment_submissions z join assignment_batches ab on ab.assignment_id = z.assignment_id and ab.batch_id = b.id where z.user_id = x.id),
          'engagement', private.engagement_score(x.id)) z
        from users x left join students sx on sx.user_id = x.id where x.id = any(stu)) q), '[]'),
    'exams', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'status', e.status, 'start_time', e.start_time, 'end_time', e.end_time,
          'total_questions', e.total_questions, 'total_marks', e.total_marks, 'duration_minutes', e.duration_minutes,
          'attempts', (select count(*) from results r where r.exam_id = e.id and r.user_id = any(stu)),
          'avg_percent', (select round(avg(r.percentage), 1) from results r where r.exam_id = e.id and r.user_id = any(stu)),
          'pass_rate', (select round(100.0 * count(*) filter (where r.percentage >= coalesce(e.pass_percentage, 33)) / nullif(count(*), 0), 1) from results r where r.exam_id = e.id and r.user_id = any(stu)),
          'topper', (select jsonb_build_object('name', x.full_name, 'percentage', r.percentage) from results r join users x on x.id = r.user_id
                      where r.exam_id = e.id and r.user_id = any(stu) order by r.percentage desc, r.time_spent_seconds limit 1))
        order by e.start_time desc nulls last) from exams e where e.id = any(ex)), '[]'),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'assignment_type', a.assignment_type, 'deadline', a.deadline, 'status', a.status,
          'max_marks', a.max_marks, 'has_file', a.attachment_path is not null or exists (select 1 from assignment_attachments t where t.assignment_id = a.id),
          'submitted', (select count(*) from assignment_submissions z where z.assignment_id = a.id and z.user_id = any(stu)),
          'evaluated', (select count(*) from assignment_submissions z where z.assignment_id = a.id and z.user_id = any(stu) and z.status = 'evaluated'),
          'avg_marks', (select round(avg(z.marks_obtained), 1) from assignment_submissions z where z.assignment_id = a.id and z.user_id = any(stu)))
        order by a.deadline desc nulls last) from assignments a join assignment_batches ab on ab.assignment_id = a.id where ab.batch_id = b.id), '[]'),
    'activities', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'activity_type', t.activity_type, 'points', t.points, 'end_time', t.end_time,
          'completed', (select count(distinct ev.user_id) from activity_events ev where ev.activity_id = t.id and ev.user_id = any(stu) and ev.event_type in ('practice_complete', 'completion')))
        order by t.created_at desc) from activities t where t.organization_id = b.organization_id and coalesce(t.is_active, true)), '[]'),
    'announcements', coalesce((select jsonb_agg(jsonb_build_object('title', n.title, 'priority', n.priority, 'published_at', n.published_at) order by n.published_at desc)
        from (select * from announcements n where n.target_batch = b.id or (n.target_type in ('organization', 'all') and coalesce(n.target_org, n.organization_id) = b.organization_id)
              order by n.published_at desc limit 5) n), '[]'),
    'charts', jsonb_build_object(
      'distribution', (select jsonb_agg(jsonb_build_object('label', lbl, 'count', c) order by o) from (
          select g.o, g.lbl, (select count(*) from results r where r.exam_id = any(ex) and r.user_id = any(stu) and r.percentage >= g.lo and (r.percentage < g.hi or (g.hi = 100 and r.percentage <= 100))) c
          from (values (1, '0–20%', 0, 20), (2, '20–40%', 20, 40), (3, '40–60%', 40, 60), (4, '60–80%', 60, 80), (5, '80–100%', 80, 100)) g(o, lbl, lo, hi)) d),
      'exam_trend', coalesce((select jsonb_agg(jsonb_build_object('label', e.title, 'avg', (select round(avg(r.percentage), 1) from results r where r.exam_id = e.id and r.user_id = any(stu)))
          order by e.end_time) from exams e where e.id = any(ex) and exists (select 1 from results r where r.exam_id = e.id and r.user_id = any(stu))), '[]'),
      'subjects', coalesce((select jsonb_agg(jsonb_build_object('label', k, 'avg', v) order by k) from (
          select sw.key k, round(100.0 * sum((sw.value->>'score')::numeric) / nullif(sum((sw.value->>'max')::numeric), 0), 1) v
          from results r cross join lateral jsonb_each(coalesce(r.subject_wise, '{}')) sw
          where r.exam_id = any(ex) and r.user_id = any(stu) and jsonb_typeof(sw.value) = 'object' group by sw.key) t), '[]'),
      'engagement', coalesce((select jsonb_object_agg(l, c) from (select private.engagement_score(x) ->> 'level' l, count(*) c from unnest(stu) x group by 1) t), '{}'))
  );
  return res;
end $$;

-- =====================================================================
--  ACTIVITY / QUIZ RESPONSES – who completed an activity, with the file they uploaded
--  activity.responses { activity_id }
-- =====================================================================
create or replace function private.act_activity_responses(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare a activities; mine uuid[];
begin
  perform private.need(u, private.r_staff());
  select * into a from activities where id = private.req_uuid(p, 'activity_id', 'activity');
  if a.id is null or not private.in_scope(s, a.organization_id) then perform private.fail('Activity not found or you don''t have access.', '404'); end if;
  mine := case when u.role = 'faculty' then private.my_batches(u.id) end;
  return jsonb_build_object('activity', to_jsonb(a), 'rows', coalesce((select jsonb_agg(z order by z->>'completed_at' desc) from (
    select jsonb_build_object('user_id', x.id, 'full_name', x.full_name, 'email', x.email, 'roll_number', coalesce(sx.roll_number, x.roll_number),
      'batch', (select name from batches b where b.id = sx.batch_id), 'completed_at', ev.created_at,
      'file_path', ev.meta->>'file_path', 'file_name', ev.meta->>'file_name', 'note', ev.meta->>'note') z
    from activity_events ev join users x on x.id = ev.user_id left join students sx on sx.user_id = x.id
    where ev.activity_id = a.id and ev.event_type in ('practice_complete', 'completion')
      and (mine is null or exists (select 1 from batch_members m where m.user_id = x.id and m.batch_id = any(mine)))) q), '[]'));
end $$;

-- =====================================================================
--  ENGAGEMENT OVERVIEW (v3.5) – no temporary tables, so it works in every
--  Supabase connection mode; also returns charts and per-batch numbers
-- =====================================================================
create or replace function private.act_engagement_overview(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare bid uuid := private.juuid(p, 'batch_id'); f text := coalesce(private.jt(p, 'bucket'), 'all'); allr jsonb; rows jsonb; mine uuid[];
begin
  perform private.need(u, private.r_staff());
  mine := case when u.role = 'faculty' then private.my_batches(u.id) end;
  with base as (
    select x.id user_id, x.full_name, x.email, coalesce(sx.roll_number, x.roll_number) roll_number, (select name from organizations where id = x.organization_id) org,
           (select name from batches b where b.id = sx.batch_id) batch, private.engagement_score(x.id) es
    from users x left join students sx on sx.user_id = x.id
    where x.role = 'student' and coalesce(x.is_active, true) and private.in_scope(s, x.organization_id)
      and (bid is null or exists (select 1 from batch_members m where m.batch_id = bid and m.user_id = x.id))
      and (mine is null or exists (select 1 from batch_members m where m.user_id = x.id and m.batch_id = any(mine)))
  ), e as (
    select user_id, full_name, email, roll_number, org, batch, (es->>'last_activity')::timestamptz last_at, coalesce((es->>'days_inactive')::int, 999) days,
           coalesce((es->>'pending')::int, 0) pending, coalesce((es->>'score')::int, 0) score, es->>'level' level,
           coalesce((es->>'logins_14d')::int, 0) logins, coalesce((es->>'exams_30d')::int, 0) exams, coalesce((es->>'submissions_30d')::int, 0) subs
    from base
  )
  select coalesce(jsonb_agg(to_jsonb(z) order by z.score, z.full_name), '[]') into allr from (
    select e.*, case when days >= 30 then '30+' when days >= 15 then '15+' when days >= 7 then '7+' when days >= 3 then '3+' else 'active' end bucket,
           case when days >= 3 then 'inactive' when pending > 0 then 'pending_work' else 'active' end status from e) z;

  -- keep engagement_status in step (3 / 7 / 15 / 30-day inactivity rules)
  insert into engagement_status(user_id, status, last_activity_at, inactivity_days, updated_at)
  select (r->>'user_id')::uuid, r->>'status', (r->>'last_at')::timestamptz, least((r->>'days')::int, 9999), now() from jsonb_array_elements(allr) r
  on conflict (user_id) do update set status = excluded.status, last_activity_at = coalesce(excluded.last_activity_at, engagement_status.last_activity_at),
     inactivity_days = excluded.inactivity_days, updated_at = now();

  select coalesce(jsonb_agg(r), '[]') into rows from jsonb_array_elements(allr) r
   where f = 'all' or r->>'bucket' = f or (f = 'pending' and (r->>'pending')::int > 0) or r->>'level' = f;
  return jsonb_build_object('rows', rows,
    'summary', (select jsonb_build_object('total', count(*), 'active', count(*) filter (where r->>'bucket' = 'active'),
        'd3', count(*) filter (where r->>'bucket' = '3+'), 'd7', count(*) filter (where r->>'bucket' = '7+'), 'd15', count(*) filter (where r->>'bucket' = '15+'),
        'd30', count(*) filter (where r->>'bucket' = '30+'), 'pending', count(*) filter (where (r->>'pending')::int > 0),
        'avg_score', coalesce(round(avg((r->>'score')::int)), 0),
        'high', count(*) filter (where r->>'level' = 'Highly engaged'), 'engaged', count(*) filter (where r->>'level' = 'Engaged'),
        'risk', count(*) filter (where r->>'level' = 'At risk'), 'inactive', count(*) filter (where r->>'level' = 'Inactive')) from jsonb_array_elements(allr) r),
    'by_batch', (select coalesce(jsonb_agg(jsonb_build_object('batch', b, 'students', n, 'avg_score', a) order by a desc), '[]') from (
        select coalesce(r->>'batch', 'No batch') b, count(*) n, round(avg((r->>'score')::int)) a from jsonb_array_elements(allr) r group by 1) t));
end $$;

-- =====================================================================
--  STUDENT IMPORT – many students at once with full details and logins
--  student.import { rows:[{...}], organization_id?, batch_id?, password_mode: 'generate'|'default'|'column', default_password?, update_existing? }
--  Each row → users (login) + students (full record) + batch_members. Returns the login ID and password per row.
-- =====================================================================
create or replace function private.gen_password(nm text) returns text language plpgsql volatile as $$
declare base text := initcap(left(regexp_replace(split_part(coalesce(nm, ''), ' ', 1), '[^A-Za-z]', '', 'g'), 8)); pw text;
begin
  if base = '' then base := 'Student'; end if;
  pw := base || '@' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');
  while length(pw) < 8 loop pw := pw || floor(random() * 10)::int::text; end loop;
  return pw;
end $$;

create or replace function private.act_student_import(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare org uuid := coalesce(case when u.role in ('super_admin', 'college_admin') then private.juuid(p, 'organization_id') end, u.organization_id);
        def_batch uuid := private.juuid(p, 'batch_id'); mode text := coalesce(private.jt(p, 'password_mode'), 'generate'); defpw text := private.jt(p, 'default_password');
        upd boolean := coalesce(private.jbool(p, 'update_existing'), true);
        r jsonb; d jsonb; ln int := 0; em text; nm text; pw text; ex users; bid uuid; bname text; res jsonb; out jsonb := '[]'; created int := 0; updated int := 0; failed int := 0;
        g text; seen text[] := '{}';
begin
  perform private.need(u, private.r_admin());
  if org is null or not private.in_scope(s, org) then perform private.fail('Please choose an organization you manage.'); end if;
  if def_batch is not null and not exists (select 1 from batches where id = def_batch and organization_id = org) then perform private.fail('Please choose a batch of this organization.'); end if;
  if mode = 'default' then perform private.check_pw(defpw); end if;
  if jsonb_typeof(p->'rows') <> 'array' or jsonb_array_length(p->'rows') = 0 then perform private.fail('The file has no student rows.'); end if;
  if jsonb_array_length(p->'rows') > 200 then perform private.fail('Please send at most 200 rows at a time.'); end if;

  for r in select value from jsonb_array_elements(p->'rows') loop
    ln := coalesce(private.jint(r, '_line'), ln + 1);
    em := lower(btrim(coalesce(r->>'email', ''))); nm := btrim(coalesce(r->>'full_name', ''));
    begin
      if nm = '' then perform private.fail('Full name is missing.'); end if;
      if em !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then perform private.fail('Email (login ID) is missing or not valid.'); end if;
      if em = any(seen) then perform private.fail('This email appears twice in the file.'); end if;
      seen := seen || em;
      select * into ex from users where lower(email) = em;
      if ex.id is not null and (ex.role <> 'student' or not private.in_scope(s, ex.organization_id)) then perform private.fail('This email is already used by another account.'); end if;
      if ex.id is not null and not upd then perform private.fail('A student with this email already exists.'); end if;

      -- batch: from the row (code or name), else the batch chosen for the whole file
      bid := def_batch; bname := btrim(coalesce(r->>'batch', r->>'batch_code', ''));
      if bname <> '' then
        select id into bid from batches where organization_id = org and (lower(code) = lower(bname) or lower(name) = lower(bname)) limit 1;
        if bid is null then perform private.fail(format('Batch "%s" was not found in this organization.', bname)); end if;
      end if;

      -- password
      pw := nullif(btrim(coalesce(r->>'password', '')), '');
      if pw is null and ex.id is null then pw := case when mode = 'default' then defpw else private.gen_password(nm) end; end if;
      if pw is not null then perform private.check_pw(pw); end if;

      g := lower(btrim(coalesce(r->>'gender', '')));
      d := jsonb_strip_nulls(jsonb_build_object(
        'id', ex.id, 'full_name', nm, 'email', em, 'password', pw, 'organization_id', org,
        'phone', nullif(btrim(r->>'phone'), ''), 'roll_number', nullif(btrim(r->>'roll_number'), ''), 'admission_no', nullif(btrim(r->>'admission_no'), ''),
        'admission_date', nullif(btrim(r->>'admission_date'), ''), 'date_of_birth', nullif(btrim(r->>'date_of_birth'), ''),
        'gender', case when g in ('m', 'male', 'boy') then 'male' when g in ('f', 'female', 'girl') then 'female' when g in ('o', 'other') then 'other' end,
        'blood_group', nullif(upper(btrim(r->>'blood_group')), ''), 'category', nullif(initcap(btrim(r->>'category')), ''),
        'alt_phone', nullif(btrim(r->>'alt_phone'), ''), 'address_line', nullif(btrim(r->>'address_line'), ''), 'city', nullif(btrim(r->>'city'), ''),
        'state', nullif(btrim(r->>'state'), ''), 'pincode', nullif(btrim(r->>'pincode'), ''),
        'father_name', nullif(btrim(r->>'father_name'), ''), 'father_phone', nullif(btrim(r->>'father_phone'), ''), 'father_occupation', nullif(btrim(r->>'father_occupation'), ''),
        'mother_name', nullif(btrim(r->>'mother_name'), ''), 'mother_phone', nullif(btrim(r->>'mother_phone'), ''), 'guardian_email', nullif(btrim(r->>'guardian_email'), ''),
        'school_name', nullif(btrim(r->>'school_name'), ''), 'board', nullif(btrim(r->>'board'), ''),
        'class_10_percent', nullif(btrim(r->>'class_10_percent'), ''), 'class_12_percent', nullif(btrim(r->>'class_12_percent'), ''),
        'passing_year', nullif(btrim(r->>'passing_year'), ''), 'fee_total', nullif(btrim(r->>'fee_total'), ''), 'fee_paid', nullif(btrim(r->>'fee_paid'), ''),
        'status', 'active', 'is_active', true));
      if bid is not null then d := d || jsonb_build_object('batch_ids', jsonb_build_array(bid)); end if;
      if ex.id is not null then   -- keep what the import doesn't mention
        d := (private.student_row(ex.id) - 'id' - 'student_id' - 'batches' - 'organization' - 'batch' - 'exam_category' - 'age' - 'fee_due' - 'last_login_at' - 'avatar_url')
             || jsonb_build_object('exam_category_id', (select exam_category_id from students where user_id = ex.id)) || (d - 'status' - 'is_active');
        if bid is null then d := d - 'batch_ids'; end if;
      end if;
      res := private.act_student_save(u, s, jsonb_build_object('data', d));
      if ex.id is null then created := created + 1; else updated := updated + 1; end if;
      out := out || jsonb_build_object('line', ln, 'ok', true, 'action', case when ex.id is null then 'created' else 'updated' end,
        'full_name', nm, 'email', em, 'password', pw, 'roll_number', res->'row'->>'roll_number', 'admission_no', res->'row'->>'admission_no',
        'batch', res->'row'->'batch'->>'name', 'id', res->'row'->>'id');
    exception when others then
      failed := failed + 1;
      out := out || jsonb_build_object('line', ln, 'ok', false, 'full_name', nm, 'email', em,
        'message', case when sqlstate = 'P0001' then sqlerrm when sqlstate = '22007' or sqlstate = '22008' then 'A date is not valid – use YYYY-MM-DD.'
                        when sqlstate = '22P02' then 'A number or date is not valid.' else 'This row could not be saved – please check it.' end);
    end;
  end loop;
  if created + updated > 0 then perform private.audit(u, 'import', 'students', null, jsonb_build_object('created', created, 'updated', updated, 'failed', failed)); end if;
  return jsonb_build_object('created', created, 'updated', updated, 'failed', failed, 'rows', out,
    'message', format('%s created, %s updated, %s with problems.', created, updated, failed));
end $$;

-- =====================================================================
--  QUESTION IMPORT (Excel / CSV rows) + question bank summary
--  questions.import { rows:[{question_text, question_type, option_a..option_f, correct, explanation, exam_category, subject, chapter, topic,
--                           difficulty, marks, negative_marks, tags}], status: 'draft'|'approved', organization_id? }
--  questions.summary { }  → counts for the tiles on the Questions page
-- =====================================================================
create or replace function private.act_questions_import(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare org uuid := case when u.role = 'super_admin' then private.juuid(p, 'organization_id')
                         when private.juuid(p, 'organization_id') is not null and private.in_scope(s, private.juuid(p, 'organization_id')) then private.juuid(p, 'organization_id')
                         else u.organization_id end;
        st text := case when p->>'status' = 'approved' then 'approved' else 'draft' end;
        r jsonb; d jsonb; ln int := 0; typ text; o jsonb; k text; corr text; ca jsonb; cat uuid; sid uuid; cid uuid; tid uuid; nid uuid;
        out jsonb := '[]'; saved int := 0; failed int := 0; t text;
begin
  perform private.need(u, private.r_staff());
  if jsonb_typeof(p->'rows') <> 'array' or jsonb_array_length(p->'rows') = 0 then perform private.fail('The file has no question rows.'); end if;
  if jsonb_array_length(p->'rows') > 200 then perform private.fail('Please send at most 200 rows at a time.'); end if;
  for r in select value from jsonb_array_elements(p->'rows') loop
    ln := coalesce(private.jint(r, '_line'), ln + 1);
    begin
      -- type (friendly names accepted)
      t := lower(btrim(coalesce(r->>'question_type', r->>'type', '')));
      typ := case when t in ('', 'mcq', 'single', 'mcq_single', 'single correct', 'mcq single', 'mcq (single)') then 'mcq_single'
                  when t in ('multi', 'multiple', 'mcq_multi', 'mcq_multiple', 'multiple correct', 'mcq multiple', 'mcq (multiple)') then 'mcq_multi'
                  when t in ('numerical', 'numeric', 'number', 'integer') then 'numerical'
                  when t in ('true_false', 'true/false', 'true false', 'tf', 't/f', 'boolean') then 'true_false'
                  when t in ('short', 'short_answer', 'short answer', 'fill in the blank', 'fill') then 'short_answer'
                  when t in ('long', 'long_answer', 'long answer', 'descriptive', 'essay') then 'long_answer'
                  else t end;
      -- options A–F
      o := '[]';
      foreach k in array array['a','b','c','d','e','f'] loop
        if nullif(btrim(coalesce(r->>('option_' || k), r->>k, '')), '') is not null then
          o := o || jsonb_build_object('key', upper(k), 'text', btrim(coalesce(r->>('option_' || k), r->>k)));
        end if;
      end loop;
      corr := btrim(coalesce(r->>'correct', r->>'correct_answer', r->>'answer', ''));
      ca := case when typ = 'mcq_single' then to_jsonb(upper(left(regexp_replace(corr, '[^A-Za-z]', '', 'g'), 1)))
                 when typ = 'mcq_multi' then to_jsonb(array(select upper(btrim(x)) from unnest(regexp_split_to_array(corr, '[,;/ ]+')) x where btrim(x) <> ''))
                 when typ = 'numerical' then jsonb_build_object('value', nullif(regexp_replace(corr, '[^0-9.\-]', '', 'g'), ''), 'tolerance', coalesce(nullif(btrim(r->>'tolerance'), ''), '0'))
                 when typ = 'true_false' then to_jsonb(case when lower(corr) in ('t', 'true', 'yes', '1') then 'true' when lower(corr) in ('f', 'false', 'no', '0') then 'false' else corr end)
                 when typ = 'short_answer' then to_jsonb(corr)
                 else null end;
      -- syllabus by name (exam type optional)
      cat := null; sid := null; cid := null; tid := null;
      if nullif(btrim(coalesce(r->>'exam_category', '')), '') is not null then
        select id into cat from exam_categories where lower(name) = lower(btrim(r->>'exam_category')) or lower(code) = lower(btrim(r->>'exam_category')) limit 1;
      end if;
      if nullif(btrim(coalesce(r->>'subject', '')), '') is not null then
        select id into sid from subjects where lower(name) = lower(btrim(r->>'subject')) and (cat is null or exam_category_id = cat) order by (exam_category_id = cat) desc nulls last limit 1;
        if sid is null then perform private.fail(format('Subject "%s" is not in the syllabus yet – add it on the Syllabus page first.', btrim(r->>'subject'))); end if;
      end if;
      if sid is not null and nullif(btrim(coalesce(r->>'chapter', '')), '') is not null then
        select id into cid from chapters where subject_id = sid and lower(name) = lower(btrim(r->>'chapter')) limit 1;
        if cid is null then perform private.fail(format('Chapter "%s" was not found under %s.', btrim(r->>'chapter'), btrim(r->>'subject'))); end if;
      end if;
      if cid is not null and nullif(btrim(coalesce(r->>'topic', '')), '') is not null then
        select id into tid from topics where chapter_id = cid and lower(name) = lower(btrim(r->>'topic')) limit 1;
      end if;
      d := jsonb_strip_nulls(jsonb_build_object('question_text', btrim(coalesce(r->>'question_text', r->>'question', '')), 'question_type', typ,
        'difficulty', case when lower(btrim(r->>'difficulty')) in ('easy', 'medium', 'hard') then lower(btrim(r->>'difficulty')) else 'medium' end,
        'options', case when o = '[]' then null else o end, 'correct_answer', ca, 'explanation', nullif(btrim(coalesce(r->>'explanation', '')), ''),
        'marks', coalesce(nullif(btrim(r->>'marks'), ''), '1'), 'negative_marks', coalesce(nullif(btrim(r->>'negative_marks'), ''), '0'), 'tags', nullif(btrim(coalesce(r->>'tags', '')), ''),
        'subject_id', sid, 'chapter_id', cid, 'topic_id', tid, 'organization_id', org, 'source', 'import', 'status', st));
      d := private.prepare_question(d, null, u, s, true);
      insert into questions(organization_id, subject_id, chapter_id, topic_id, question_text, question_type, difficulty, language, options, correct_answer, explanation, marks, negative_marks, tags, source, status, created_by, reviewed_by, approved_at)
      select q.organization_id, q.subject_id, q.chapter_id, q.topic_id, q.question_text, q.question_type, q.difficulty, 'en', q.options, q.correct_answer, q.explanation, q.marks, q.negative_marks, q.tags,
             'import', st, u.id, case when st = 'approved' then u.id end, case when st = 'approved' then now() end
      from jsonb_populate_record(null::questions, d) q returning id into nid;
      saved := saved + 1;
      out := out || jsonb_build_object('line', ln, 'ok', true, 'question', left(d->>'question_text', 90), 'type', typ);
    exception when others then
      failed := failed + 1;
      out := out || jsonb_build_object('line', ln, 'ok', false, 'question', left(btrim(coalesce(r->>'question_text', r->>'question', '')), 90),
        'message', case when sqlstate = 'P0001' then sqlerrm when sqlstate in ('22P02', '22003') then 'A number (marks / answer) is not valid.' else 'This row could not be saved – please check it.' end);
    end;
  end loop;
  if saved > 0 then perform private.audit(u, 'import', 'questions', null, jsonb_build_object('saved', saved, 'failed', failed, 'status', st)); end if;
  return jsonb_build_object('saved', saved, 'failed', failed, 'rows', out, 'message', format('%s imported as %s, %s with problems.', private.plural(saved, 'question'), st, failed));
end $$;

create or replace function private.act_questions_summary(u public.users, s uuid[], p jsonb) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform private.need(u, private.r_staff());
  return (select jsonb_build_object('total', count(*), 'approved', count(*) filter (where q.status in ('approved', 'published')),
      'review', count(*) filter (where q.status in ('draft', 'under_review')), 'easy', count(*) filter (where q.difficulty = 'easy'),
      'medium', count(*) filter (where q.difficulty = 'medium'), 'hard', count(*) filter (where q.difficulty = 'hard'),
      'mine', count(*) filter (where q.created_by = u.id), 'with_media', count(*) filter (where exists (select 1 from question_media m where m.question_id = q.id)))
    from questions q where q.organization_id is null or private.in_scope(s, q.organization_id));
end $$;

-- =====================================================================
--  ERROR MESSAGES IN PLAIN WORDS
-- =====================================================================
create or replace function private.friendly(st text, msg text, det text, cons text) returns text language sql immutable as $$
select case
  when st = '23505' then case when coalesce(det,'') || coalesce(cons,'') ~* 'email' then 'This email address is already registered.'
                              when coalesce(cons,'') = 'ux_batch_members' then 'This person is already in the batch.'
                              when coalesce(cons,'') = 'ux_exam_questions' then 'This question is already in the exam.'
                              when coalesce(det,'') || coalesce(cons,'') ~* 'code' then 'This code is already in use. Please choose a different code.'
                              else 'This record already exists.' end
  when st = '23503' then case when msg ~* 'update or delete' then 'This item can''t be deleted because other records use it. Remove those first, or deactivate it instead.'
                              else 'One of the selected linked items no longer exists. Please refresh the page and choose again.' end
  when st = '23514' then 'One of the values you entered isn''t allowed. Please check your selections.'
  when st = '23502' then 'Please fill in all required fields.'
  when st in ('22P02','22007','22008','22003','22023') then 'One of the values has an invalid format (check numbers and dates).'
  when st = '57014' then 'The request took too long. Please try again.'
  when st in ('42703','42P01','42883') then 'This feature isn''t available right now. Please try again later or contact your administrator.'
  else 'Something went wrong while working with the data. Please try again.' end
$$;

-- =====================================================================
--  THE ONE FUNCTION THE WEBSITE CALLS:  POST /rest/v1/rpc/api
-- =====================================================================
create or replace function public.api(p_action text, p_params jsonb default '{}'::jsonb, p_token text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare u public.users; s uuid[]; fn text; r jsonb; st text; msg text; det text; hnt text; cons text;
begin
  p_params := coalesce(p_params, '{}'::jsonb);
  if p_action = 'auth.login' then return private.a_login(p_params); end if;
  if p_action = 'result.verify' then return private.a_verify(p_params); end if;
  if p_action = 'app.ping' then return jsonb_build_object('ok', true, 'message', 'Server is ready.', 'app_name', private.setting('app_name')); end if;
  if p_action is null or p_action !~ '^[a-zA-Z]+(\.[a-zA-Z]+)?$' then return jsonb_build_object('ok', false, 'error', 'Unknown request. Please refresh the page.'); end if;
  fn := 'act_' || lower(replace(p_action, '.', '_'));
  if to_regprocedure('private.' || fn || '(public.users,uuid[],jsonb)') is null then
    return jsonb_build_object('ok', false, 'error', 'This action isn''t available right now. Please refresh the page and try again.');
  end if;
  u := private.get_session_user(p_token);
  if u.id is null then return jsonb_build_object('ok', false, 'error', 'Your session has expired. Please sign in again.', 'code', 'AUTH'); end if;
  s := private.org_scope(u);
  execute format('select private.%I($1, $2, $3)', fn) into r using u, s, p_params || jsonb_build_object('_token', p_token);
  if r ? '_error' then return jsonb_build_object('ok', false, 'error', r->>'_error', 'code', r->>'_code'); end if;
  return jsonb_build_object('ok', true) || coalesce(r, '{}'::jsonb);
exception when others then
  get stacked diagnostics st = returned_sqlstate, msg = message_text, det = pg_exception_detail, hnt = pg_exception_hint, cons = constraint_name;
  if st = 'P0001' then return jsonb_build_object('ok', false, 'error', msg, 'code', nullif(hnt, '')); end if;
  insert into private.error_log(action, state, message, detail) values (p_action, st, msg, det);
  return jsonb_build_object('ok', false, 'error', private.friendly(st, msg, det, cons));
end $$;

-- =====================================================================
--  STORAGE POLICIES (uploads/downloads only with a ticket from api())
-- =====================================================================
do $$ begin
  drop policy if exists "examportal_upload" on storage.objects;
  drop policy if exists "examportal_read" on storage.objects;
  -- uploads: only with a 15-minute ticket from api() (checks role, file type and size first)
  create policy "examportal_upload" on storage.objects for insert to anon, authenticated
    with check (bucket_id = any(private.buckets()) and private.storage_can_upload2(bucket_id, name));
  -- private downloads: only with a 2-minute ticket from api() (checks the user may see the file)
  create policy "examportal_read" on storage.objects for select to anon, authenticated
    using (bucket_id = any(private.buckets()) and private.storage_can_read2(bucket_id, name));
exception when others then raise notice 'Storage policies not created: %', sqlerrm; end $$;

-- =====================================================================
--  PERMISSIONS
-- =====================================================================
revoke all on function public.api(text, jsonb, text) from public;
grant execute on function public.api(text, jsonb, text) to anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.storage_can_upload2(text, text), private.storage_can_read2(text, text), private.buckets() to anon, authenticated;

insert into private.settings(key, value) values ('verify_secret', encode(extensions.gen_random_bytes(16), 'hex')) on conflict (key) do nothing;
insert into private.settings(key, value) values ('groq_model', 'openai/gpt-oss-120b') on conflict (key) do nothing;

notify pgrst, 'reload schema';
notify pgrst, 'reload config';
select 'VidyaSetu backend installed successfully' as status;
