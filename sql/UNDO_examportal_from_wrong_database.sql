-- =====================================================================
--  UNDO ExamPortal setup from the WRONG database
--  Removes ONLY what 01_setup_all.sql (and the Groq-key script) added.
--  Your own tables, columns and rows are NOT touched.
--
--  HOW TO USE (Supabase > SQL Editor of the WRONG project):
--   1. Run this file as it is.  It runs in PREVIEW mode: nothing is changed,
--      you only see a list of what would be removed.
--   2. If the list looks right, change   v_preview boolean := true;
--      to                                v_preview boolean := false;   and run again.
--   3. Read the "NOTE" lines in the result (about security policies).
--
--  How it knows what is ours: Postgres remembers which transaction created
--  each table, column and function. Only objects created by the same
--  transaction(s) as the ExamPortal setup are removed.
-- =====================================================================
create temp table if not exists undo_report (n serial, action text, item text);
truncate undo_report;

do $$
declare
  v_preview     boolean := true;   -- <<< change to false to really remove
  v_disable_rls boolean := false;  -- <<< set true ONLY if your old app worked with Row Level Security OFF (see note at the end)

  x_err bigint; lo bigint; single_txn boolean; hi1 bigint; hi_all bigint; setup_time timestamptz;
  our_cols jsonb := '{"organizations":["name","code","type","parent_id","is_active","settings","created_at","updated_at","city","contact_email","logo_url","address","id"],"users":["email","password_hash","full_name","phone","role","organization_id","is_active","last_login_at","metadata","created_at","updated_at","roll_number","avatar_url","failed_logins","locked_until","id"],"batches":["organization_id","name","code","academic_year","start_date","end_date","is_active","created_by","created_at","updated_at","description","exam_category_id","id"],"batch_members":["batch_id","user_id","role_in_batch","joined_at","id"],"exam_categories":["name","code","description","is_active","created_by","created_at","updated_at","icon","color","id"],"subjects":["exam_category_id","name","code","order_index","is_active","created_at","id"],"chapters":["subject_id","name","code","order_index","is_active","created_at","weightage","status","id"],"topics":["chapter_id","name","code","order_index","is_active","created_at","id"],"syllabus_imports":["exam_category_id","file_url","file_type","status","imported_by","reviewed_by","review_notes","created_at","updated_at","id"],"questions":["organization_id","subject_id","chapter_id","topic_id","question_text","question_type","difficulty","language","options","correct_answer","explanation","marks","negative_marks","tags","source","status","created_by","reviewed_by","approved_at","is_duplicate","duplicate_of","metadata","created_at","updated_at","review_note","id"],"question_media":["question_id","media_type","file_path","order_index","created_at","id"],"exams":["organization_id","exam_category_id","title","description","total_marks","duration_minutes","total_questions","attempt_limit","shuffle_questions","shuffle_options","show_result_immediately","negative_marking","status","start_time","end_time","created_by","published_by","published_at","settings","created_at","updated_at","instructions","pass_percentage","blueprint","id"],"exam_questions":["exam_id","question_id","order_index","marks","section","is_mandatory","id"],"exam_assignments":["exam_id","batch_id","user_id","assigned_by","assigned_at","created_at","id"],"exam_attempts":["exam_id","user_id","attempt_number","started_at","submitted_at","time_spent_seconds","status","score","max_score","percentage","rank","percentile","answers","auto_save_data","ip_address","user_agent","created_at","updated_at","tab_switches","id"],"assignments":["organization_id","title","description","assignment_type","max_marks","deadline","allow_resubmit","max_resubmits","status","created_by","published_at","settings","created_at","updated_at","allowed_types","attachment_path","id"],"assignment_attachments":["assignment_id","file_path","file_name","file_type","created_at","id"],"assignment_batches":["assignment_id","batch_id","id"],"assignment_submissions":["assignment_id","user_id","attempt_number","submitted_at","status","marks_obtained","feedback","evaluated_by","evaluated_at","created_at","updated_at","content","link_url","id"],"submission_files":["submission_id","file_path","file_name","file_type","created_at","file_size","id"],"activities":["organization_id","title","activity_type","duration_minutes","start_time","end_time","created_by","created_at","description","exam_id","resource_url","points","is_active","id"],"activity_events":["user_id","activity_id","exam_attempt_id","event_type","metadata","created_at","meta","id"],"engagement_status":["user_id","status","last_activity_at","inactivity_days","updated_at","id"],"results":["exam_attempt_id","user_id","exam_id","total_score","max_score","percentage","rank","percentile","subject_wise","chapter_wise","topic_wise","accuracy","is_visible","released_at","scorecard_url","created_at","updated_at","time_spent_seconds","id"],"announcements":["organization_id","title","body","target_type","target_ids","created_by","published_at","expires_at","created_at","priority","target_org","target_batch","target_role","id"],"notifications":["user_id","title","body","type","reference_id","reference_type","is_read","read_at","action_url","created_at","id"],"audit_logs":["user_id","action","entity_type","entity_id","old_data","new_data","ip_address","user_agent","created_at","actor_email","id"],"app_sessions":["user_id","token_hash","user_agent","created_at","last_seen_at","expires_at","id"]}'; r record; t text; private_is_ours boolean;
  our_tables text[] := array['organizations','users','batches','batch_members','exam_categories','subjects','chapters','topics',
    'syllabus_imports','questions','question_media','exams','exam_questions','exam_assignments','exam_attempts',
    'assignments','assignment_attachments','assignment_batches','assignment_submissions','submission_files',
    'activities','activity_events','engagement_status','results','announcements','notifications','audit_logs','app_sessions'];
  our_indexes text[] := array['idx_users_org','idx_users_role','idx_sessions_user','idx_batch_members_batch','idx_batch_members_user',
    'idx_subjects_cat','idx_chapters_subject','idx_topics_chapter','idx_questions_org','idx_questions_subject','idx_exams_org',
    'idx_exam_questions_exam','idx_exam_assign_exam','idx_attempts_exam_user','idx_results_exam','idx_results_user',
    'idx_asg_batches_batch','idx_submissions_asg','idx_notifications_user','idx_questions_hash','idx_exam_assign_batch',
    'idx_exam_assign_user','idx_announcements_pub'];
  created_tables text[] := '{}';
  existing_tables text[] := '{}';
  procedure_log text;
begin
  -- 1) find the transaction id(s) of the ExamPortal setup
  -- (row types are used because permission changes on a later run re-stamp pg_class but never pg_type)
  select ty.xmin::text::bigint into x_err from pg_type ty join pg_class c on c.oid = ty.typrelid join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'private' and c.relname = 'error_log' and c.relkind = 'r';
  if x_err is null or to_regclass('private.settings') is null then
    insert into undo_report(action, item) values ('NOTHING FOUND', 'ExamPortal setup was not found in this database. Nothing to remove.');
    return;
  end if;
  execute $q$select xmin::text::bigint, updated_at from private.settings where key = 'verify_secret'$q$ into hi1, setup_time;
  single_txn := (select count(distinct ty.xmin::text::bigint) = 1 and min(ty.xmin::text::bigint) = x_err from pg_type ty join pg_class c on c.oid = ty.typrelid
                 where c.relnamespace = 'private'::regnamespace and c.relname in ('error_log','file_tickets','settings') and c.relkind = 'r');
  if single_txn then
    -- whole setup ran as ONE transaction: its id, plus the small sub-transaction ids used inside its
    -- error-handling blocks (they come right after it and before any later run)
    lo := x_err;
    select least(x_err + 300, coalesce(min(x) - 1, x_err + 300)) into hi1 from (
      select c.xmin::text::bigint x from pg_class c where c.relnamespace = 'private'::regnamespace and c.relkind = 'r'
      union all select p.xmin::text::bigint from pg_proc p where p.pronamespace = 'private'::regnamespace
      union all select xmin::text::bigint from private.settings) z
     where x > x_err;
  else
    hi1 := coalesce(hi1, x_err);                     -- setup ran statement by statement: follow the chain of
    lo := x_err;                                     -- consecutive setup transactions backwards from error_log
    for r in select distinct x from (
        select a.xmin::text::bigint x from pg_attribute a join pg_class c on c.oid = a.attrelid
         where c.relnamespace = 'public'::regnamespace and c.relname = any(our_tables) and a.attnum > 0
           and coalesce(our_cols->c.relname, '[]'::jsonb) ? a.attname::text
        union all select ty.xmin::text::bigint from pg_type ty join pg_class c on c.oid = ty.typrelid
         where c.relnamespace = 'public'::regnamespace and c.relname = any(our_tables)
        union all select xmin::text::bigint from pg_constraint where conname in ('results_exam_attempt_id_key','engagement_status_user_id_key','app_sessions_token_hash_key')
        union all select xmin::text::bigint from pg_extension where extname in ('http','pgcrypto','uuid-ossp')
      ) z where x < x_err order by x desc loop
      exit when lo - r.x > 50;
      lo := r.x;
    end loop;
  end if;
  select greatest(hi1, coalesce(max(p.xmin::text::bigint), 0)) into hi_all from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where (n.nspname = 'private') or (n.nspname = 'public' and p.proname = 'api');
  private_is_ours := not exists(select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'private' and c.relkind in ('r','v','m','S')
                                  and c.relname not in ('settings','file_tickets','error_log','error_log_id_seq'))
                 and not exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.xmin::text::bigint < lo);

  -- 2) tables that ExamPortal CREATED (their row type was born in the setup transaction)
  for t in select unnest(our_tables) loop
    if to_regclass('public.' || quote_ident(t)) is null then continue; end if;
    if exists(select 1 from pg_type ty where ty.typrelid = to_regclass('public.' || quote_ident(t)) and ty.xmin::text::bigint between lo and hi1
              and (single_txn or (
                -- created by ExamPortal = table started with ONLY ExamPortal's key column(s), everything else was added later
                (select count(*) from pg_attribute a where a.attrelid = ty.typrelid and a.attnum > 0 and not a.attisdropped and a.xmin = ty.xmin)
                  = case when t = 'assignment_batches' then 2 else 1 end
                and (t = 'assignment_batches' or exists(select 1 from pg_attrdef d join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
                      where d.adrelid = ty.typrelid and a.attname = 'id' and pg_get_expr(d.adbin, d.adrelid) like '%uuid_generate_v4()%'))))) then
      created_tables := created_tables || t;
    else
      existing_tables := existing_tables || t;
    end if;
  end loop;

  -- 3) report + remove
  -- 3a. columns added to YOUR existing tables
  for r in
    select c.relname tbl, a.attname col from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = any(existing_tables) and a.attnum > 0 and not a.attisdropped
      and a.attacl is null and a.xmin::text::bigint between lo and hi1
      and coalesce(our_cols->c.relname, '[]'::jsonb) ? a.attname::text
      and a.xmin::text::bigint <> (select ty.xmin::text::bigint from pg_type ty where ty.typrelid = c.oid)
    order by c.relname, a.attnum
  loop
    insert into undo_report(action, item) values ('drop column (added by ExamPortal)', r.tbl || '.' || r.col);
    if not v_preview then execute format('alter table public.%I drop column if exists %I', r.tbl, r.col); end if;
  end loop;

  -- 3b. unique constraints & indexes ExamPortal added
  for r in select conrelid::regclass::text tbl, conname from pg_constraint
           where conname in ('results_exam_attempt_id_key','engagement_status_user_id_key','app_sessions_token_hash_key') and xmin::text::bigint between lo and hi1
             and conrelid::regclass::text not in (select 'public.' || x from unnest(created_tables) x) and conrelid::regclass::text not in (select x from unnest(created_tables) x) loop
    insert into undo_report(action, item) values ('drop constraint', r.tbl || ' ' || r.conname);
    if not v_preview then execute format('alter table %s drop constraint if exists %I', r.tbl, r.conname); end if;
  end loop;
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'i' and c.relname = any(our_indexes) and c.xmin::text::bigint between lo and hi1 loop
    insert into undo_report(action, item) values ('drop index', r.relname);
    if not v_preview then execute format('drop index if exists public.%I', r.relname); end if;
  end loop;

  -- 3c. tables ExamPortal created (did not exist before)
  foreach t in array created_tables loop
    insert into undo_report(action, item) values ('drop table (created by ExamPortal)', 'public.' || t);
    if not v_preview then execute format('drop table if exists public.%I cascade', t); end if;
  end loop;

  -- 3d. the api() function, storage policies, private schema/objects
  insert into undo_report(action, item) values ('drop function', 'public.api(text, jsonb, text)');
  if not v_preview then drop function if exists public.api(text, jsonb, text); end if;
  insert into undo_report(action, item) values ('drop storage policies', 'examportal_upload, examportal_read');
  if not v_preview then
    begin drop policy if exists "examportal_upload" on storage.objects; drop policy if exists "examportal_read" on storage.objects;
    exception when others then null; end;
  end if;
  if exists(select 1 from storage.buckets b where b.id = 'uploads' and b.created_at between setup_time - interval '10 minutes' and setup_time + interval '1 minute')
     and not exists(select 1 from storage.objects o where o.bucket_id = 'uploads') then
    insert into undo_report(action, item) values ('delete storage bucket (created by ExamPortal, empty)', 'uploads');
    if not v_preview then delete from storage.buckets where id = 'uploads'; end if;
  end if;
  if private_is_ours then
    insert into undo_report(action, item) values ('drop schema (created by ExamPortal, incl. Groq key)', 'private');
    if not v_preview then drop schema private cascade; end if;
  else
    for r in select p.oid::regprocedure::text f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'private' and p.xmin::text::bigint between lo and hi_all loop
      insert into undo_report(action, item) values ('drop function', r.f);
      if not v_preview then execute 'drop function if exists ' || r.f || ' cascade'; end if;
    end loop;
    for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'private' and c.relkind = 'r' and c.relname in ('settings','file_tickets','error_log') and c.xmin::text::bigint between lo and hi_all loop
      insert into undo_report(action, item) values ('drop table', 'private.' || r.relname);
      if not v_preview then execute format('drop table if exists private.%I', r.relname); end if;
    end loop;
  end if;

  -- 3e. extensions ExamPortal installed (only if it installed them)
  for r in select extname from pg_extension where extname = 'http' and xmin::text::bigint between lo and hi1 loop
    insert into undo_report(action, item) values ('drop extension (installed by ExamPortal)', r.extname);
    if not v_preview then begin execute format('drop extension if exists %I', r.extname); exception when others then
      insert into undo_report(action, item) values ('kept extension (something else uses it)', r.extname); end; end if;
  end loop;

  -- 3f. give back the normal Supabase permissions on YOUR tables + restore API timeouts
  foreach t in array existing_tables loop
    insert into undo_report(action, item) values ('restore permissions (anon, authenticated, service_role)', 'public.' || t);
    if not v_preview then execute format('grant all on table public.%I to anon, authenticated, service_role', t); end if;
    if v_disable_rls then
      insert into undo_report(action, item) values ('turn Row Level Security OFF', 'public.' || t);
      if not v_preview then execute format('alter table public.%I disable row level security', t); end if;
    end if;
  end loop;
  insert into undo_report(action, item) values ('restore API timeouts', 'anon 3s, authenticated 8s (Supabase defaults)');
  if not v_preview then
    alter role anon set statement_timeout = '3s';
    alter role authenticated set statement_timeout = '8s';
    notify pgrst, 'reload schema'; notify pgrst, 'reload config';
  end if;

  insert into undo_report(action, item) values (case when v_preview then '>>> PREVIEW ONLY' else '>>> DONE' end,
    case when v_preview then 'Nothing was changed. Set v_preview := false and run again to remove the items above.' else 'ExamPortal was removed. Your own data was not touched.' end);
  if array_length(existing_tables, 1) > 0 then
    insert into undo_report(action, item) values ('NOTE – check these tables', array_to_string(existing_tables, ', ')
      || ' : the setup switched Row Level Security ON for them and removed any RLS policies they had. '
      || case when v_disable_rls then 'RLS has been switched OFF again.' else 'If your old app stops reading/writing them, see the instructions.' end);
  end if;
end $$;

select n as "#", action, item from undo_report order by n;
