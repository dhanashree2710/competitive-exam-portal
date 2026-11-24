-- =====================================================================
--  KDRT ExamSphere – 100 RECORDS for Sujata Institute of Information And Technology (SIIT03)
--  Run AFTER sql/01_setup_all.sql. This one file is complete: it also includes everything in
--  04_sample_data.sql, so you do not need to run 04 first.
--  (Supabase → SQL Editor → paste → Run).  Safe to run more than once: nothing is duplicated.
--
--  Brings Sujata Institute up to:
--    • 100 students in 4 batches (JEE Main 2027 – A/B, NEET UG 2027 – A/B), with roll numbers
--    • 100+ approved questions (Physics, Chemistry, Mathematics, Biology) with explanations
--    • 2 more completed weekly tests with 100 results, ranks and percentiles
--    • about 100 assignment submissions (graded, pending and "needs correction")
--    • activities, two weeks of logins, announcements and notifications for everyone
--  and for ATSS College: 20 BCA students, an aptitude syllabus, a completed aptitude test,
--  an assignment, an activity – plus notifications for admins/faculty and an audit history.
--
--  New student logins:  <first>.<last>@sujatainstitute.in  /  Student@123
--  Storage buckets (uploads, assignment-files, question-images, avatars, announcements-media,
--  question-media, student-submissions, syllabus-files, assignment-attachments, scorecards)
--  are created by 01_setup_all.sql; files go into them when you upload from the portal.
-- =====================================================================

-- ===================== PART 1 – base data (same as 04_sample_data.sql) =====================

do $$ begin
  if to_regproc('private.backend_version') is null or to_regclass('public.students') is null then
    raise exception 'Please run the latest sql/01_setup_all.sql first, then run this file again.';
  end if;
end $$;

-- ---------- helpers (temporary, removed automatically when the session ends) ----------
create or replace function pg_temp.subj(cat uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.subjects where exam_category_id = cat and lower(name) = lower(nm);
  if i is null then insert into public.subjects(exam_category_id, name, order_index) values (cat, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.unit(sid uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.units where subject_id = sid and lower(name) = lower(nm);
  if i is null then insert into public.units(subject_id, name, order_index) values (sid, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.chap(sid uuid, uid uuid, nm text, ord int, w numeric) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.chapters where subject_id = sid and lower(name) = lower(nm);
  if i is null then insert into public.chapters(subject_id, unit_id, name, order_index, weightage, status) values (sid, uid, nm, ord, w, 'published') returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.topic(cid uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.topics where chapter_id = cid and lower(name) = lower(nm);
  if i is null then insert into public.topics(chapter_id, name, order_index) values (cid, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.q(sid uuid, cid uuid, tid uuid, txt text, typ text, diff text, opts jsonb, ans jsonb, expl text, who uuid) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.questions where question_text = txt;
  if i is null then
    insert into public.questions(organization_id, subject_id, chapter_id, topic_id, question_text, question_type, difficulty, language, options, correct_answer, explanation,
                                 marks, negative_marks, status, source, created_by, reviewed_by, approved_at)
    values (null, sid, cid, tid, txt, typ, diff, 'en', opts, ans, expl, 4, case when typ = 'mcq_single' then 1 else 0 end, 'approved', 'manual', who, who, now())
    returning id into i;
  end if;
  return i; end $$;
create or replace function pg_temp.person(em text, nm text, rl text, org uuid, roll text, ph text, pw text) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.users where lower(email) = lower(em);
  if i is null then
    insert into public.users(email, full_name, role, organization_id, roll_number, phone, is_active, password_hash, created_at)
    values (lower(em), nm, rl, org, roll, ph, true, extensions.crypt(pw, extensions.gen_salt('bf', 10)), now() - interval '45 days') returning id into i;
  end if;
  return i; end $$;
create or replace function pg_temp.member(bid uuid, uid uuid, rl text) returns void language plpgsql as $$
begin
  if not exists (select 1 from public.batch_members where batch_id = bid and user_id = uid) then
    insert into public.batch_members(batch_id, user_id, role_in_batch, joined_at) values (bid, uid, rl, now() - interval '40 days');
  end if; end $$;
create or replace function pg_temp.exam(org uuid, cat uuid, ttl text, dsc text, mins int, st text, t0 timestamptz, t1 timestamptz, instr text, pass numeric, neg boolean, showres boolean, who uuid) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.exams where organization_id = org and title = ttl;
  if i is null then
    insert into public.exams(organization_id, exam_category_id, title, description, duration_minutes, attempt_limit, negative_marking, shuffle_questions, shuffle_options,
                             show_result_immediately, status, start_time, end_time, instructions, pass_percentage, created_by, published_by, published_at, created_at)
    values (org, cat, ttl, dsc, mins, 1, neg, true, true, showres, st, t0, t1, instr, pass, who, who, t0, t0 - interval '3 days') returning id into i;
  elsif not exists (select 1 from public.exam_attempts where exam_id = i) then
    -- an older copy with no attempts yet (e.g. from the previous sample file): bring it in line
    update public.exams set exam_category_id = cat, description = dsc, duration_minutes = mins, status = st, start_time = t0, end_time = t1,
           instructions = instr, pass_percentage = pass, negative_marking = neg, show_result_immediately = showres where id = i;
    delete from public.exam_questions where exam_id = i;
  end if;
  return i; end $$;
create or replace function pg_temp.fill(eid uuid, qs uuid[], who uuid, bid uuid) returns void language plpgsql as $$
declare k int;
begin
  if not exists (select 1 from public.exam_questions where exam_id = eid) then
    for k in 1..cardinality(qs) loop
      insert into public.exam_questions(exam_id, question_id, order_index, marks, section)
      values (eid, qs[k], k, 4, (select s.name from public.questions q join public.subjects s on s.id = q.subject_id where q.id = qs[k]));
    end loop;
  end if;
  if not exists (select 1 from public.exam_assignments where exam_id = eid and batch_id = bid) then
    insert into public.exam_assignments(exam_id, batch_id, assigned_by) values (eid, bid, who);
  end if;
  perform private.recalc_exam(eid);
end $$;

-- realistic completed attempts for every student of a batch (scored by the real scoring engine)
create or replace function pg_temp.simulate(eid uuid, bid uuid) returns void language plpgsql as $$
declare e public.exams; a public.exam_attempts; stu record; q record; ans jsonb; qt jsonb; ability numeric; r numeric; n int := 0; st timestamptz; spent int; wrong text;
begin
  select * into e from public.exams where id = eid;
  if exists (select 1 from public.exam_attempts where exam_id = eid) then return; end if;
  for stu in select u.id, u.roll_number from public.batch_members m join public.users u on u.id = m.user_id
             where m.batch_id = bid and u.role = 'student' order by u.roll_number loop
    n := n + 1;
    ability := 0.38 + ((n * 37) % 50) / 100.0;                       -- 38% … 87%, different for every student
    ans := '{}'; qt := '{}'; spent := 0;
    st := e.start_time + make_interval(hours => n * 3);
    for q in select qq.id, qq.question_type, qq.options, qq.correct_answer, qq.difficulty from public.exam_questions eq join public.questions qq on qq.id = eq.question_id
             where eq.exam_id = eid order by eq.order_index loop
      r := random();
      if q.difficulty = 'hard' then r := r + 0.15; elsif q.difficulty = 'easy' then r := r - 0.1; end if;
      if r < ability then
        ans := ans || jsonb_build_object(q.id, case when q.question_type = 'numerical' then to_jsonb((q.correct_answer->>'value')) else q.correct_answer end);
      elsif r < ability + (1 - ability) * 0.7 then                       -- wrong answer
        if q.question_type = 'numerical' then ans := ans || jsonb_build_object(q.id, to_jsonb(((q.correct_answer->>'value')::numeric + 1)::text));
        elsif q.question_type = 'true_false' then ans := ans || jsonb_build_object(q.id, case when q.correct_answer #>> '{}' = 'true' then 'false' else 'true' end);
        else
          select o->>'key' into wrong from jsonb_array_elements(q.options) o where o->>'key' <> q.correct_answer #>> '{}' order by random() limit 1;
          ans := ans || jsonb_build_object(q.id, wrong);
        end if;
      end if;                                                             -- otherwise: skipped
      qt := qt || jsonb_build_object(q.id, 35 + floor(random() * 110)::int);
    end loop;
    select coalesce(sum((v)::int), 0) into spent from jsonb_each_text(qt) x(k, v);
    insert into public.exam_attempts(exam_id, user_id, attempt_number, status, started_at, answers, auto_save_data, tab_switches, user_agent)
    values (eid, stu.id, 1, 'in_progress', st, ans, jsonb_build_object('qtime', qt), (n % 4 = 0)::int, 'Mozilla/5.0') returning * into a;
    perform private.finalize_attempt(e, a, ans, false);
    update public.exam_attempts set submitted_at = st + make_interval(secs => spent), time_spent_seconds = spent,
           auto_save_data = auto_save_data || jsonb_build_object('qtime', qt) where id = a.id;
    update public.results set time_spent_seconds = spent, created_at = st + make_interval(secs => spent), is_visible = true, released_at = e.end_time
     where exam_attempt_id = a.id;
    insert into public.activity_events(user_id, exam_attempt_id, event_type, created_at, meta) values (stu.id, a.id, 'session_start', st, jsonb_build_object('exam_id', eid));
    update public.activity_events set created_at = st + make_interval(secs => spent) where exam_attempt_id = a.id and event_type = 'completion';
    insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
    values (stu.id, 'Result published', format('Your result for "%s" is now available.', e.title), 'result', eid, 'exam', 'results.html', n % 3 = 0, e.end_time);
  end loop;
  perform private.recalc_ranks(eid);
end $$;

do $$
declare
  root uuid; atss uuid; siit uuid; sa uuid; ca uuid; ia uuid; jee uuid; neet uuid;
  phy uuid; che uuid; mat uuid; nphy uuid; nche uuid; bio uuid;
  u_mech uuid; u_elec uuid; u_phys uuid; u_org uuid; u_alg uuid; u_calc uuid; u_bot uuid; u_zoo uuid;
  c_kin uuid; c_lom uuid; c_cur uuid; c_mole uuid; c_eq uuid; c_hc uuid; c_quad uuid; c_cplx uuid; c_lim uuid; c_int uuid; c_cell uuid; c_div uuid; c_dig uuid; c_bre uuid; c_body uuid;
  t_1d uuid; t_proj uuid; t_newton uuid; t_fric uuid; t_ohm uuid; t_kirch uuid; t_avo uuid; t_stoi uuid; t_lech uuid; t_alk uuid; t_ion uuid; t_alkene uuid;
  t_roots uuid; t_nature uuid; t_iota uuid; t_deriv uuid; t_indef uuid; t_lim uuid; t_org uuid; t_mei uuid; t_mit uuid; t_enz uuid; t_alv uuid; t_trans uuid; t_bile uuid;
  f_phy uuid; f_che uuid; f_mat uuid; f_bio uuid; f_atss uuid;
  b_jee uuid; b_neet uuid; b_atss uuid;
  q1 uuid[] := '{}'; q2 uuid[] := '{}'; qb uuid[] := '{}'; qn uuid[] := '{}';
  e1 uuid; e2 uuid; e3 uuid; e4 uuid; a1 uuid; a2 uuid; act1 uuid; act2 uuid; act3 uuid;
  stu record; n int; d int; sub_id uuid;
  jee_students text[][] := array[
    ['Aarav Patil','aarav.patil'],['Isha Kulkarni','isha.kulkarni'],['Rohan Shinde','rohan.shinde'],['Sakshi Deshpande','sakshi.deshpande'],
    ['Omkar Jadhav','omkar.jadhav'],['Pranav Gaikwad','pranav.gaikwad'],['Tanvi Bhosale','tanvi.bhosale'],['Siddharth Kale','siddharth.kale'],
    ['Neha Pawar','neha.pawar'],['Atharva Joshi','atharva.joshi'],['Riya Chavan','riya.chavan'],['Yash Mane','yash.mane']];
  neet_students text[][] := array[
    ['Ananya More','ananya.more'],['Kabir Salunkhe','kabir.salunkhe'],['Shreya Kadam','shreya.kadam'],['Aditya Lokhande','aditya.lokhande'],
    ['Pooja Shirke','pooja.shirke'],['Vedant Thorat','vedant.thorat'],['Mrunal Gokhale','mrunal.gokhale'],['Harsh Wagh','harsh.wagh'],
    ['Gauri Nikam','gauri.nikam'],['Soham Kulkarni','soham.kulkarni'],['Prachi Sawant','prachi.sawant'],['Sanika Pawar','sanika.pawar']];
  k int; uid_ uuid;
begin
  perform setseed(0.2711);   -- same realistic results every time this file is run on a fresh database

  -- ---------- your organizations & admins ----------
  select id into root from public.organizations where code = 'KDRT';
  select id into atss from public.organizations where code = 'ATSS';
  select id into siit from public.organizations where code = 'SIIT03';
  if root is null or atss is null or siit is null then
    raise exception 'Organizations with codes KDRT, ATSS and SIIT03 are needed. Please create them on the Organizations page first.';
  end if;
  select id into sa from public.users where role = 'super_admin' order by created_at limit 1;
  select id into ca from public.users where role = 'college_admin' and organization_id = atss order by created_at limit 1;
  select id into ia from public.users where role = 'institute_admin' and organization_id = siit order by created_at limit 1;

  -- remove the earlier "*.demo" sample accounts (and everything linked to them)
  delete from public.users where email like '%.demo';

  -- ---------- exam types ----------
  -- reuse your own exam types if they already exist (matched by code or by name)
  select id into jee from public.exam_categories where code = 'JEE_MAIN' or lower(trim(name)) in ('jee main', 'jee mains', 'jee (main)') order by (code = 'JEE_MAIN') desc nulls last limit 1;
  if jee is null then
    insert into public.exam_categories(name, code, description, icon, color, created_by)
    values ('JEE Main', 'JEE_MAIN', 'Joint Entrance Examination (Main) – Physics, Chemistry, Mathematics', 'calculator', '#2563EB', sa) returning id into jee;
  end if;
  select id into neet from public.exam_categories where code = 'NEET_UG' or lower(trim(name)) in ('neet ug', 'neet', 'neet-ug', 'neet (ug)') order by (code = 'NEET_UG') desc nulls last limit 1;
  if neet is null then
    insert into public.exam_categories(name, code, description, icon, color, created_by)
    values ('NEET UG', 'NEET_UG', 'National Eligibility cum Entrance Test (UG) – Physics, Chemistry, Biology', 'heart-pulse', '#0F766E', sa) returning id into neet;
  end if;

  -- ---------- JEE Main syllabus ----------
  phy := pg_temp.subj(jee, 'Physics', 1); che := pg_temp.subj(jee, 'Chemistry', 2); mat := pg_temp.subj(jee, 'Mathematics', 3);
  u_mech := pg_temp.unit(phy, 'Mechanics', 1); u_elec := pg_temp.unit(phy, 'Electrodynamics', 2);
  c_kin := pg_temp.chap(phy, u_mech, 'Kinematics', 1, 6); t_1d := pg_temp.topic(c_kin, 'Motion in a Straight Line', 1); t_proj := pg_temp.topic(c_kin, 'Projectile Motion', 2);
  c_lom := pg_temp.chap(phy, u_mech, 'Laws of Motion', 2, 5); t_newton := pg_temp.topic(c_lom, 'Newton''s Laws of Motion', 1); t_fric := pg_temp.topic(c_lom, 'Friction', 2);
  c_cur := pg_temp.chap(phy, u_elec, 'Current Electricity', 3, 7); t_ohm := pg_temp.topic(c_cur, 'Ohm''s Law', 1); t_kirch := pg_temp.topic(c_cur, 'Kirchhoff''s Laws', 2);
  u_phys := pg_temp.unit(che, 'Physical Chemistry', 1); u_org := pg_temp.unit(che, 'Organic Chemistry', 2);
  c_mole := pg_temp.chap(che, u_phys, 'Some Basic Concepts of Chemistry', 1, 4); t_avo := pg_temp.topic(c_mole, 'Mole Concept & Avogadro Number', 1); t_stoi := pg_temp.topic(c_mole, 'Molar Mass & Stoichiometry', 2);
  c_eq := pg_temp.chap(che, u_phys, 'Chemical Equilibrium', 2, 5); t_lech := pg_temp.topic(c_eq, 'Le Chatelier''s Principle', 1); t_ion := pg_temp.topic(c_eq, 'Ionic Equilibrium & pH', 2);
  c_hc := pg_temp.chap(che, u_org, 'Hydrocarbons', 3, 5); t_alk := pg_temp.topic(c_hc, 'Alkanes', 1); t_alkene := pg_temp.topic(c_hc, 'Alkenes and Alkynes', 2);
  u_alg := pg_temp.unit(mat, 'Algebra', 1); u_calc := pg_temp.unit(mat, 'Calculus', 2);
  c_quad := pg_temp.chap(mat, u_alg, 'Quadratic Equations', 1, 5); t_roots := pg_temp.topic(c_quad, 'Roots of a Quadratic Equation', 1); t_nature := pg_temp.topic(c_quad, 'Nature of Roots', 2);
  c_cplx := pg_temp.chap(mat, u_alg, 'Complex Numbers', 2, 4); t_iota := pg_temp.topic(c_cplx, 'Powers of i and Modulus', 1);
  c_lim := pg_temp.chap(mat, u_calc, 'Limits and Derivatives', 3, 6); t_lim := pg_temp.topic(c_lim, 'Standard Limits', 1); t_deriv := pg_temp.topic(c_lim, 'Derivatives of Standard Functions', 2);
  c_int := pg_temp.chap(mat, u_calc, 'Integrals', 4, 7); t_indef := pg_temp.topic(c_int, 'Indefinite Integrals', 1);

  -- ---------- NEET UG syllabus ----------
  nphy := pg_temp.subj(neet, 'Physics', 1); nche := pg_temp.subj(neet, 'Chemistry', 2); bio := pg_temp.subj(neet, 'Biology', 3);
  perform pg_temp.topic(pg_temp.chap(nphy, pg_temp.unit(nphy, 'Mechanics', 1), 'Laws of Motion', 1, 4), 'Newton''s Laws of Motion', 1);
  perform pg_temp.topic(pg_temp.chap(nche, pg_temp.unit(nche, 'Physical Chemistry', 1), 'Some Basic Concepts of Chemistry', 1, 4), 'Mole Concept', 1);
  u_bot := pg_temp.unit(bio, 'Botany', 1); u_zoo := pg_temp.unit(bio, 'Zoology', 2);
  c_cell := pg_temp.chap(bio, u_bot, 'Cell: The Unit of Life', 1, 6); t_org := pg_temp.topic(c_cell, 'Cell Organelles', 1); perform pg_temp.topic(c_cell, 'Prokaryotic Cells', 2);
  c_div := pg_temp.chap(bio, u_bot, 'Cell Cycle and Cell Division', 2, 5); t_mei := pg_temp.topic(c_div, 'Meiosis', 1); t_mit := pg_temp.topic(c_div, 'Mitosis', 2);
  c_dig := pg_temp.chap(bio, u_zoo, 'Digestion and Absorption', 3, 5); t_enz := pg_temp.topic(c_dig, 'Digestive Enzymes', 1); t_bile := pg_temp.topic(c_dig, 'Digestive Glands', 2);
  c_bre := pg_temp.chap(bio, u_zoo, 'Breathing and Exchange of Gases', 4, 5); t_alv := pg_temp.topic(c_bre, 'Exchange of Gases in Alveoli', 1); t_trans := pg_temp.topic(c_bre, 'Transport of Gases', 2);
  c_body := pg_temp.chap(bio, u_zoo, 'Human Reproduction', 5, 4); perform pg_temp.topic(c_body, 'Gametogenesis', 1);

  -- ---------- faculty & students of Sujata Institute ----------
  f_phy := pg_temp.person('rahul.deshmukh@sujatainstitute.in', 'Prof. Rahul Deshmukh', 'faculty', siit, null, '9822041101', 'Faculty@123');
  f_che := pg_temp.person('meera.apte@sujatainstitute.in', 'Dr. Meera Apte', 'faculty', siit, null, '9822041102', 'Faculty@123');
  f_mat := pg_temp.person('sandeep.gore@sujatainstitute.in', 'Prof. Sandeep Gore', 'faculty', siit, null, '9822041103', 'Faculty@123');
  f_bio := pg_temp.person('kavita.bhide@sujatainstitute.in', 'Dr. Kavita Bhide', 'faculty', siit, null, '9822041104', 'Faculty@123');
  f_atss := pg_temp.person('sneha.joshi@atsscollege.in', 'Prof. Sneha Joshi', 'faculty', atss, null, '9822041201', 'Faculty@123');

  -- ---------- batches ----------
  select id into b_jee from public.batches where organization_id = siit and (name = 'JEE Main 2027 – Batch A' or code = 'JEE27A') order by (name = 'JEE Main 2027 – Batch A') desc limit 1;
  if b_jee is null then insert into public.batches(organization_id, name, code, academic_year, exam_category_id, start_date, end_date, description, created_by, created_at)
    values (siit, 'JEE Main 2027 – Batch A', 'JEE27A', '2026-27', jee, current_date - 40, current_date + 260, 'Morning batch (7:00–11:00 am) – Physics, Chemistry, Mathematics', coalesce(ia, sa), now() - interval '41 days') returning id into b_jee; end if;
  select id into b_neet from public.batches where organization_id = siit and (name = 'NEET UG 2027 – Batch A' or code = 'NEET27A') order by (name = 'NEET UG 2027 – Batch A') desc limit 1;
  if b_neet is null then insert into public.batches(organization_id, name, code, academic_year, exam_category_id, start_date, end_date, description, created_by, created_at)
    values (siit, 'NEET UG 2027 – Batch A', 'NEET27A', '2026-27', neet, current_date - 40, current_date + 260, 'Evening batch (4:00–8:00 pm) – Physics, Chemistry, Biology', coalesce(ia, sa), now() - interval '41 days') returning id into b_neet; end if;
  select id into b_atss from public.batches where organization_id = atss and (name = 'BCA Aptitude 2026' or code = 'BCA26') order by (name = 'BCA Aptitude 2026') desc limit 1;
  if b_atss is null then insert into public.batches(organization_id, name, code, academic_year, exam_category_id, description, created_by)
    values (atss, 'BCA Aptitude 2026', 'BCA26', '2026-27', jee, 'Quantitative aptitude practice', coalesce(ca, sa)) returning id into b_atss; end if;
  perform pg_temp.member(b_jee, f_phy, 'faculty'); perform pg_temp.member(b_jee, f_che, 'faculty'); perform pg_temp.member(b_jee, f_mat, 'faculty');
  perform pg_temp.member(b_neet, f_phy, 'faculty'); perform pg_temp.member(b_neet, f_che, 'faculty'); perform pg_temp.member(b_neet, f_bio, 'faculty');
  perform pg_temp.member(b_atss, f_atss, 'faculty');
  for k in 1..array_length(jee_students, 1) loop
    uid_ := pg_temp.person(jee_students[k][2] || '@sujatainstitute.in', jee_students[k][1], 'student', siit, format('SIIT/JEE/27/%s', lpad(k::text, 3, '0')), '98900' || lpad((41100 + k)::text, 5, '0'), 'Student@123');
    perform pg_temp.member(b_jee, uid_, 'student');
  end loop;
  for k in 1..array_length(neet_students, 1) loop
    uid_ := pg_temp.person(neet_students[k][2] || '@sujatainstitute.in', neet_students[k][1], 'student', siit, format('SIIT/NEET/27/%s', lpad(k::text, 3, '0')), '98900' || lpad((41200 + k)::text, 5, '0'), 'Student@123');
    perform pg_temp.member(b_neet, uid_, 'student');
  end loop;

  -- ---------- question bank: JEE set 1 (used in Mock Test 1) ----------
  q1 := q1 || pg_temp.q(phy, c_kin, t_proj, 'A ball is projected at an angle of 45° to the horizontal with a speed of 20 m/s. What is its horizontal range? (g = 10 m/s²)', 'mcq_single', 'medium', '[{"key":"A","text":"20 m"},{"key":"B","text":"40 m"},{"key":"C","text":"80 m"},{"key":"D","text":"10 m"}]', '"B"', 'R = u² sin 2θ / g = 400 × 1 / 10 = 40 m.', f_phy);
  q1 := q1 || pg_temp.q(phy, c_kin, t_1d, 'A car starts from rest and reaches 20 m/s in 5 s with uniform acceleration. What is its acceleration?', 'mcq_single', 'easy', '[{"key":"A","text":"2 m/s²"},{"key":"B","text":"4 m/s²"},{"key":"C","text":"5 m/s²"},{"key":"D","text":"100 m/s²"}]', '"B"', 'a = (v − u) / t = 20 / 5 = 4 m/s².', f_phy);
  q1 := q1 || pg_temp.q(phy, c_lom, t_newton, 'What is the SI unit of force?', 'mcq_single', 'easy', '[{"key":"A","text":"Newton"},{"key":"B","text":"Joule"},{"key":"C","text":"Watt"},{"key":"D","text":"Pascal"}]', '"A"', '1 N = 1 kg·m/s².', f_phy);
  q1 := q1 || pg_temp.q(phy, c_lom, t_fric, 'The coefficient of friction between two surfaces is:', 'mcq_single', 'easy', '[{"key":"A","text":"Measured in newton"},{"key":"B","text":"Measured in kilogram"},{"key":"C","text":"Dimensionless"},{"key":"D","text":"Measured in m/s"}]', '"C"', 'μ = F / N is a ratio of two forces, so it has no unit.', f_phy);
  q1 := q1 || pg_temp.q(phy, c_cur, t_ohm, 'A potential difference of 5 V is applied across a 10 Ω resistor. What current (in ampere) flows through it?', 'numerical', 'easy', null, '{"value":0.5,"tolerance":0.01}', 'I = V / R = 5 / 10 = 0.5 A.', f_phy);
  q1 := q1 || pg_temp.q(phy, c_cur, t_kirch, 'Kirchhoff''s junction (current) law is based on the conservation of:', 'mcq_single', 'medium', '[{"key":"A","text":"Energy"},{"key":"B","text":"Charge"},{"key":"C","text":"Momentum"},{"key":"D","text":"Mass"}]', '"B"', 'Charge entering a junction equals charge leaving it.', f_phy);
  q1 := q1 || pg_temp.q(che, c_mole, t_avo, 'How many molecules are present in one mole of a substance?', 'mcq_single', 'easy', '[{"key":"A","text":"6.022 × 10²³"},{"key":"B","text":"3.011 × 10²³"},{"key":"C","text":"6.022 × 10²²"},{"key":"D","text":"1.0 × 10²³"}]', '"A"', 'Avogadro number N_A = 6.022 × 10²³ mol⁻¹.', f_che);
  q1 := q1 || pg_temp.q(che, c_mole, t_stoi, 'What is the molar mass of water (H₂O) in g/mol? (H = 1, O = 16)', 'numerical', 'easy', null, '{"value":18,"tolerance":0}', '2 × 1 + 16 = 18 g/mol.', f_che);
  q1 := q1 || pg_temp.q(che, c_eq, t_lech, 'For N₂(g) + 3H₂(g) ⇌ 2NH₃(g), increasing the pressure shifts the equilibrium:', 'mcq_single', 'medium', '[{"key":"A","text":"Forward, towards NH₃"},{"key":"B","text":"Backward, towards N₂ and H₂"},{"key":"C","text":"It does not shift"},{"key":"D","text":"It stops the reaction"}]', '"A"', 'Higher pressure favours the side with fewer gas moles (2 vs 4).', f_che);
  q1 := q1 || pg_temp.q(che, c_hc, t_alk, 'The general formula of alkanes is:', 'mcq_single', 'easy', '[{"key":"A","text":"CₙH₂ₙ"},{"key":"B","text":"CₙH₂ₙ₋₂"},{"key":"C","text":"CₙH₂ₙ₊₂"},{"key":"D","text":"CₙHₙ"}]', '"C"', 'Alkanes are saturated: CₙH₂ₙ₊₂ (e.g. CH₄, C₂H₆).', f_che);
  q1 := q1 || pg_temp.q(mat, c_quad, t_roots, 'The roots of x² − 5x + 6 = 0 are:', 'mcq_single', 'easy', '[{"key":"A","text":"1 and 6"},{"key":"B","text":"2 and 3"},{"key":"C","text":"−2 and −3"},{"key":"D","text":"5 and 6"}]', '"B"', '(x − 2)(x − 3) = 0.', f_mat);
  q1 := q1 || pg_temp.q(mat, c_quad, t_nature, 'The roots of x² + x + 1 = 0 are:', 'mcq_single', 'medium', '[{"key":"A","text":"Real and equal"},{"key":"B","text":"Real and distinct"},{"key":"C","text":"Rational"},{"key":"D","text":"Non-real (complex)"}]', '"D"', 'Discriminant = 1 − 4 = −3 < 0.', f_mat);
  q1 := q1 || pg_temp.q(mat, c_cplx, t_iota, 'If i = √−1, what is the value of i²?', 'mcq_single', 'easy', '[{"key":"A","text":"−1"},{"key":"B","text":"1"},{"key":"C","text":"i"},{"key":"D","text":"0"}]', '"A"', 'By definition i² = −1.', f_mat);
  q1 := q1 || pg_temp.q(mat, c_lim, t_deriv, 'The derivative of sin x with respect to x is:', 'mcq_single', 'easy', '[{"key":"A","text":"−cos x"},{"key":"B","text":"cos x"},{"key":"C","text":"tan x"},{"key":"D","text":"−sin x"}]', '"B"', 'd/dx (sin x) = cos x.', f_mat);
  q1 := q1 || pg_temp.q(mat, c_int, t_indef, '∫ 2x dx is equal to:', 'mcq_single', 'easy', '[{"key":"A","text":"x² + C"},{"key":"B","text":"2x² + C"},{"key":"C","text":"x + C"},{"key":"D","text":"2 + C"}]', '"A"', 'd/dx (x²) = 2x.', f_mat);
  q1 := q1 || pg_temp.q(mat, c_lim, t_lim, 'Find the value of lim (x → 0) of (sin x) / x.', 'numerical', 'medium', null, '{"value":1,"tolerance":0}', 'Standard limit: sin x / x → 1 as x → 0.', f_mat);

  -- ---------- JEE set 2 (used in Mock Test 2) ----------
  q2 := q2 || pg_temp.q(phy, c_kin, t_1d, 'The slope of a velocity–time graph gives the:', 'mcq_single', 'easy', '[{"key":"A","text":"Displacement"},{"key":"B","text":"Acceleration"},{"key":"C","text":"Speed"},{"key":"D","text":"Distance"}]', '"B"', 'a = dv/dt is the slope of the v–t graph.', f_phy);
  q2 := q2 || pg_temp.q(phy, c_kin, t_proj, 'At the highest point of a projectile''s path, its vertical component of velocity is:', 'mcq_single', 'easy', '[{"key":"A","text":"Zero"},{"key":"B","text":"Maximum"},{"key":"C","text":"Equal to the initial speed"},{"key":"D","text":"Equal to g"}]', '"A"', 'At the top the body momentarily stops rising, so v_y = 0.', f_phy);
  q2 := q2 || pg_temp.q(phy, c_lom, t_newton, 'A force of 10 N acts on a body of mass 2 kg. What is its acceleration in m/s²?', 'numerical', 'easy', null, '{"value":5,"tolerance":0}', 'a = F / m = 10 / 2 = 5 m/s².', f_phy);
  q2 := q2 || pg_temp.q(phy, c_lom, t_newton, 'According to Newton''s third law, action and reaction forces act on:', 'mcq_single', 'medium', '[{"key":"A","text":"The same body"},{"key":"B","text":"The same body in the same direction"},{"key":"C","text":"Two different bodies"},{"key":"D","text":"Bodies only at rest"}]', '"C"', 'Action and reaction act on different bodies, so they never cancel.', f_phy);
  q2 := q2 || pg_temp.q(phy, c_cur, t_ohm, 'What is the equivalent resistance (in Ω) of two 6 Ω resistors connected in parallel?', 'numerical', 'medium', null, '{"value":3,"tolerance":0}', '1/R = 1/6 + 1/6 ⇒ R = 3 Ω.', f_phy);
  q2 := q2 || pg_temp.q(phy, c_cur, t_ohm, 'The SI unit of electric charge is the:', 'mcq_single', 'easy', '[{"key":"A","text":"Ampere"},{"key":"B","text":"Coulomb"},{"key":"C","text":"Volt"},{"key":"D","text":"Ohm"}]', '"B"', '1 C = 1 A × 1 s.', f_phy);
  q2 := q2 || pg_temp.q(che, c_mole, t_stoi, 'How many moles are present in 44 g of CO₂? (C = 12, O = 16)', 'numerical', 'easy', null, '{"value":1,"tolerance":0}', 'Molar mass of CO₂ = 44 g/mol, so 44 g = 1 mol.', f_che);
  q2 := q2 || pg_temp.q(che, c_eq, t_lech, 'Adding a catalyst to a reaction mixture at equilibrium:', 'mcq_single', 'medium', '[{"key":"A","text":"Shifts it forward"},{"key":"B","text":"Shifts it backward"},{"key":"C","text":"Does not shift the equilibrium"},{"key":"D","text":"Stops the reaction"}]', '"C"', 'A catalyst speeds up both directions equally; equilibrium is reached faster but not shifted.', f_che);
  q2 := q2 || pg_temp.q(che, c_hc, t_alk, 'The IUPAC name of CH₃–CH₂–CH₃ is:', 'mcq_single', 'easy', '[{"key":"A","text":"Ethane"},{"key":"B","text":"Propane"},{"key":"C","text":"Butane"},{"key":"D","text":"Propene"}]', '"B"', 'Three carbon atoms with single bonds: propane.', f_che);
  q2 := q2 || pg_temp.q(che, c_hc, t_alkene, 'Alkenes contain at least one:', 'mcq_single', 'easy', '[{"key":"A","text":"Carbon–carbon double bond"},{"key":"B","text":"Carbon–carbon triple bond"},{"key":"C","text":"Benzene ring"},{"key":"D","text":"Oxygen atom"}]', '"A"', 'Alkenes are unsaturated hydrocarbons with C=C.', f_che);
  q2 := q2 || pg_temp.q(che, c_eq, t_ion, 'What is the pH of a neutral aqueous solution at 25 °C?', 'numerical', 'easy', null, '{"value":7,"tolerance":0}', '[H⁺] = 10⁻⁷ M at 25 °C, so pH = 7.', f_che);
  q2 := q2 || pg_temp.q(mat, c_quad, t_roots, 'What is the sum of the roots of 2x² − 8x + 3 = 0?', 'numerical', 'medium', null, '{"value":4,"tolerance":0}', 'Sum of roots = −b/a = 8/2 = 4.', f_mat);
  q2 := q2 || pg_temp.q(mat, c_cplx, t_iota, 'If z = 3 + 4i, what is |z|?', 'numerical', 'easy', null, '{"value":5,"tolerance":0}', '|z| = √(3² + 4²) = 5.', f_mat);
  q2 := q2 || pg_temp.q(mat, c_lim, t_deriv, 'd/dx (x³) is equal to:', 'mcq_single', 'easy', '[{"key":"A","text":"x²"},{"key":"B","text":"3x"},{"key":"C","text":"3x²"},{"key":"D","text":"x⁴/4"}]', '"C"', 'd/dx (xⁿ) = n·xⁿ⁻¹.', f_mat);
  q2 := q2 || pg_temp.q(mat, c_int, t_indef, '∫ cos x dx is equal to:', 'mcq_single', 'easy', '[{"key":"A","text":"sin x + C"},{"key":"B","text":"−sin x + C"},{"key":"C","text":"cos x + C"},{"key":"D","text":"tan x + C"}]', '"A"', 'd/dx (sin x) = cos x.', f_mat);
  q2 := q2 || pg_temp.q(mat, c_lim, t_lim, 'Find lim (x → 2) of (x² − 4) / (x − 2).', 'numerical', 'hard', null, '{"value":4,"tolerance":0}', '(x² − 4)/(x − 2) = x + 2 → 4.', f_mat);

  -- ---------- NEET Biology ----------
  qb := qb || pg_temp.q(bio, c_cell, t_org, 'Which organelle is known as the powerhouse of the cell?', 'mcq_single', 'easy', '[{"key":"A","text":"Mitochondria"},{"key":"B","text":"Ribosome"},{"key":"C","text":"Golgi apparatus"},{"key":"D","text":"Lysosome"}]', '"A"', 'Mitochondria produce ATP by cellular respiration.', f_bio);
  qb := qb || pg_temp.q(bio, c_div, t_mei, 'Gametes are produced by which type of cell division?', 'mcq_single', 'easy', '[{"key":"A","text":"Mitosis"},{"key":"B","text":"Meiosis"},{"key":"C","text":"Binary fission"},{"key":"D","text":"Budding"}]', '"B"', 'Meiosis halves the chromosome number to form gametes.', f_bio);
  qb := qb || pg_temp.q(bio, c_dig, t_enz, 'Digestion of proteins begins in the:', 'mcq_single', 'medium', '[{"key":"A","text":"Mouth"},{"key":"B","text":"Small intestine"},{"key":"C","text":"Stomach"},{"key":"D","text":"Large intestine"}]', '"C"', 'Pepsin starts protein digestion in the stomach.', f_bio);
  qb := qb || pg_temp.q(bio, c_bre, t_alv, 'In humans, the exchange of gases takes place in the:', 'mcq_single', 'easy', '[{"key":"A","text":"Trachea"},{"key":"B","text":"Bronchi"},{"key":"C","text":"Larynx"},{"key":"D","text":"Alveoli"}]', '"D"', 'Alveoli are the site of O₂–CO₂ exchange.', f_bio);
  qb := qb || pg_temp.q(bio, c_cell, t_org, 'Ribosomes are present in prokaryotic cells.', 'true_false', 'easy', '[{"key":"true","text":"True"},{"key":"false","text":"False"}]', '"true"', 'Prokaryotes have 70S ribosomes.', f_bio);
  qb := qb || pg_temp.q(bio, c_dig, t_enz, 'The enzyme pepsin works best in a/an:', 'mcq_single', 'medium', '[{"key":"A","text":"Acidic medium"},{"key":"B","text":"Alkaline medium"},{"key":"C","text":"Neutral medium"},{"key":"D","text":"Any medium"}]', '"A"', 'Pepsin is active in the acidic stomach (HCl, pH ~2).', f_bio);
  qb := qb || pg_temp.q(bio, c_cell, t_org, 'Which cell organelle is the site of protein synthesis?', 'mcq_single', 'easy', '[{"key":"A","text":"Lysosome"},{"key":"B","text":"Ribosome"},{"key":"C","text":"Vacuole"},{"key":"D","text":"Centrosome"}]', '"B"', 'Ribosomes translate mRNA into proteins.', f_bio);
  qb := qb || pg_temp.q(bio, c_div, t_mei, 'How many chromosomes are present in a normal human gamete?', 'numerical', 'easy', null, '{"value":23,"tolerance":0}', 'Gametes are haploid: 46 / 2 = 23.', f_bio);
  qb := qb || pg_temp.q(bio, c_dig, t_bile, 'Bile is produced by the:', 'mcq_single', 'medium', '[{"key":"A","text":"Liver"},{"key":"B","text":"Gall bladder"},{"key":"C","text":"Pancreas"},{"key":"D","text":"Stomach"}]', '"A"', 'The liver produces bile; the gall bladder only stores it.', f_bio);
  qb := qb || pg_temp.q(bio, c_bre, t_trans, 'Most of the oxygen in blood is transported by:', 'mcq_single', 'medium', '[{"key":"A","text":"Plasma"},{"key":"B","text":"White blood cells"},{"key":"C","text":"Haemoglobin"},{"key":"D","text":"Platelets"}]', '"C"', 'About 97% of O₂ is carried as oxyhaemoglobin.', f_bio);
  qb := qb || pg_temp.q(bio, c_div, t_mit, 'Mitosis results in the formation of:', 'mcq_single', 'easy', '[{"key":"A","text":"Four haploid cells"},{"key":"B","text":"Two haploid cells"},{"key":"C","text":"Four diploid cells"},{"key":"D","text":"Two identical daughter cells"}]', '"D"', 'Mitosis is equational division: two genetically identical cells.', f_bio);
  qn := qb;

  -- ---------- exams ----------
  e1 := pg_temp.exam(siit, jee, 'JEE Main Mock Test 1', 'Physics, Chemistry and Mathematics – 16 questions, 64 marks', 60, 'completed', now() - interval '18 days', now() - interval '11 days',
    E'1. Each correct answer: +4 marks.\n2. Each wrong MCQ answer: −1 mark. Numerical questions have no negative marking.\n3. Do not switch tabs – it is recorded.\n4. The exam submits automatically when time is up.', 33, true, false, f_phy);
  perform pg_temp.fill(e1, q1, f_phy, b_jee);
  e3 := pg_temp.exam(siit, neet, 'NEET Biology Practice Test', 'Cell biology, cell division, digestion and breathing – 11 questions', 30, 'completed', now() - interval '12 days', now() - interval '6 days',
    E'1. +4 for each correct answer, −1 for each wrong MCQ.\n2. Results are released by your teacher.', 40, true, false, f_bio);
  update public.exams set status = 'completed', start_time = now() - interval '12 days', end_time = now() - interval '6 days'
   where id = e3 and not exists (select 1 from public.exam_attempts where exam_id = e3);
  perform pg_temp.fill(e3, qb, f_bio, b_neet);
  e2 := pg_temp.exam(siit, jee, 'JEE Main Mock Test 2', 'Physics, Chemistry and Mathematics – 16 new questions', 60, 'live', now() - interval '1 day', now() + interval '14 days',
    E'1. Each correct answer: +4 marks.\n2. Each wrong MCQ answer: −1 mark.\n3. Your score is shown right after you submit.', 33, true, true, f_mat);
  perform pg_temp.fill(e2, q2, f_mat, b_jee);
  e4 := pg_temp.exam(siit, neet, 'NEET UG Full Mock 1', 'Biology section – full syllabus revision', 45, 'scheduled', date_trunc('hour', now()) + interval '2 days', date_trunc('hour', now()) + interval '9 days',
    E'1. +4 for each correct answer, −1 for each wrong MCQ.\n2. Keep a pen and paper ready for rough work.', 40, true, false, f_bio);
  perform pg_temp.fill(e4, qn, f_bio, b_neet);

  -- realistic results for the two completed exams
  perform pg_temp.simulate(e1, b_jee);
  perform pg_temp.simulate(e3, b_neet);

  -- ---------- assignments with submissions ----------
  select id into a1 from public.assignments where organization_id = siit and title = 'Physics Numericals – Set 1 (Kinematics)';
  if a1 is null then
    insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
    values (siit, 'Physics Numericals – Set 1 (Kinematics)', E'Solve the 10 numericals on Kinematics given in class.\nShow every step and write units. Upload a clear PDF or photo of your work.', 'homework', 20,
            now() + interval '5 days', true, 2, 'published', f_phy, now() - interval '9 days', 'pdf,jpg,jpeg,png,docx', now() - interval '9 days') returning id into a1;
    insert into public.assignment_batches(assignment_id, batch_id) values (a1, b_jee);
    n := 0;
    for stu in select u.id, u.full_name from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_jee and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      continue when n > 9;
      insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content, marks_obtained, feedback, evaluated_by, evaluated_at)
      values (a1, stu.id, 1, now() - make_interval(days => 8 - (n % 6)), case when n <= 6 then 'evaluated' else 'submitted' end,
              'All 10 numericals solved with steps. Answers: 1) 4 m/s² 2) 40 m 3) 20 m/s 4) 2 s 5) 45 m …',
              case when n <= 6 then 12 + (n * 3) % 9 end,
              case when n <= 6 then (array['Good work – write units in every final answer.','Neat and correct. Check question 7 again.','Well done! Excellent presentation.',
                                            'Good attempt. Revise equations of motion for Q4.','Correct method, small calculation slip in Q9.','Very good – keep it up.'])[n] end,
              case when n <= 6 then f_phy end, case when n <= 6 then now() - make_interval(days => 3) end);
    end loop;
  end if;
  select id into a2 from public.assignments where organization_id = siit and title = 'Practical: Labelled Diagram of an Animal Cell';
  if a2 is null then
    insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
    values (siit, 'Practical: Labelled Diagram of an Animal Cell', E'Draw a neat, labelled diagram of an animal cell showing at least 10 organelles.\nWrite one function of each organelle. Upload a photo or PDF.', 'practical', 10,
            now() + interval '3 days', true, 1, 'published', f_bio, now() - interval '6 days', 'pdf,jpg,jpeg,png', now() - interval '6 days') returning id into a2;
    insert into public.assignment_batches(assignment_id, batch_id) values (a2, b_neet);
    n := 0;
    for stu in select u.id from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_neet and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      continue when n > 8;
      insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content, marks_obtained, feedback, evaluated_by, evaluated_at)
      values (a2, stu.id, 1, now() - make_interval(days => 5 - (n % 4)), case when n <= 4 then 'evaluated' when n = 5 then 'needs_correction' else 'submitted' end,
              'Diagram drawn with nucleus, mitochondria, ER, Golgi body, ribosomes, lysosomes, centrosome, vacuole, cell membrane and cytoplasm, with functions.',
              case when n <= 4 then 6 + n end,
              case when n <= 4 then 'Clear diagram and correct labels.' when n = 5 then 'Please label the Golgi apparatus and centrosome and upload again.' end,
              case when n <= 5 then f_bio end, case when n <= 5 then now() - interval '1 day' end);
    end loop;
  end if;

  -- ---------- activities ----------
  select id into act1 from public.activities where organization_id = siit and title = 'Daily Revision Challenge – Laws of Motion';
  if act1 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (siit, 'Daily Revision Challenge – Laws of Motion', 'challenge', 20, now() - interval '5 days', now() + interval '9 days',
            'Revise Newton''s three laws and friction. Write two real-life examples of each law.', 15, true, f_phy, now() - interval '5 days') returning id into act1; end if;
  select id into act2 from public.activities where organization_id = siit and title = 'Organic Chemistry Naming Quiz';
  if act2 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (siit, 'Organic Chemistry Naming Quiz', 'quiz', 15, now() - interval '3 days', now() + interval '11 days',
            'Name 20 alkanes, alkenes and alkynes using IUPAC rules. Check your answers with the key shared in class.', 10, true, f_che, now() - interval '3 days') returning id into act2; end if;
  select id into act3 from public.activities where organization_id = siit and title = 'Human Physiology Rapid Revision';
  if act3 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (siit, 'Human Physiology Rapid Revision', 'revision', 30, now() - interval '2 days', now() + interval '12 days',
            'Revise digestion and breathing using the NCERT summary tables. Make a one-page flowchart.', 20, true, f_bio, now() - interval '2 days') returning id into act3; end if;
  if not exists (select 1 from public.activity_events where activity_id in (act1, act2, act3)) then
    insert into public.activity_events(user_id, activity_id, event_type, created_at, meta)
    select m.user_id, case when m.batch_id = b_jee then (case when random() < .5 then act1 else act2 end) else act3 end, 'practice_complete', now() - make_interval(days => (random() * 3)::int), '{}'::jsonb
    from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id in (b_jee, b_neet) and u.role = 'student' and random() < 0.6;
  end if;

  -- ---------- login history (drives the engagement score) ----------
  if not exists (select 1 from public.activity_events e join public.users u on u.id = e.user_id where u.email like '%@sujatainstitute.in' and e.event_type = 'login') then
    n := 0;
    for stu in select u.id from public.users u where u.organization_id = siit and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      if n in (5, 17) then        -- two students who stopped logging in
        insert into public.activity_events(user_id, event_type, created_at) values (stu.id, 'login', now() - interval '19 days');
        update public.users set last_login_at = now() - interval '19 days' where id = stu.id;
      elsif n in (9, 21) then     -- two students away for a week
        insert into public.activity_events(user_id, event_type, created_at) select stu.id, 'login', now() - make_interval(days => gs.dd) from generate_series(8, 14, 3) gs(dd);
        update public.users set last_login_at = now() - interval '8 days' where id = stu.id;
      else
        insert into public.activity_events(user_id, event_type, created_at)
        select stu.id, 'login', now() - make_interval(days => gs.dd, hours => (random() * 10)::int) from generate_series(0, 13) gs(dd) where random() < 0.65;
        update public.users set last_login_at = now() - make_interval(hours => 2 + (n % 30)) where id = stu.id;
      end if;
    end loop;
    insert into public.activity_events(user_id, event_type, created_at)
    select u.id, 'login', now() - make_interval(days => gs.dd) from public.users u, generate_series(0, 6) gs(dd) where u.organization_id = siit and u.role = 'faculty';
    update public.users set last_login_at = now() - interval '3 hours' where organization_id = siit and role = 'faculty';
  end if;

  -- ---------- realistic "last seen" for every student ----------
  -- the two students who stopped logging in keep only their old history
  delete from public.activity_events e using public.users u
   where u.id = e.user_id and u.organization_id = siit and u.role = 'student' and u.last_login_at < now() - interval '18 days'
     and e.created_at > now() - interval '18 days' and e.event_type <> 'login';
  insert into public.engagement_status(user_id, status, last_activity_at, inactivity_days)
  select u.id, 'active', null, 0 from public.users u where u.organization_id = siit and u.role = 'student'
  on conflict (user_id) do nothing;
  update public.engagement_status es
     set last_activity_at = x.last_at,
         inactivity_days  = floor(extract(epoch from now() - x.last_at) / 86400)::int,
         status = case when x.last_at < now() - interval '7 days' then 'inactive' else 'active' end
    from (select u.id, greatest(u.last_login_at, (select max(created_at) from public.activity_events e where e.user_id = u.id),
                                (select max(submitted_at) from public.assignment_submissions z where z.user_id = u.id)) last_at
            from public.users u where u.organization_id = siit and u.role = 'student') x
   where es.user_id = x.id and x.last_at is not null;

  -- ---------- announcements ----------
  if not exists (select 1 from public.announcements where title = 'Welcome to KDRT ExamSphere') then
    insert into public.announcements(organization_id, title, body, target_type, priority, created_by, published_at)
    values (root, 'Welcome to KDRT ExamSphere', E'Your exams, assignments, results and study plan are now in one place.\nOpen "My Progress & Plan" to see your strengths, weak topics and a 7-day study plan.', 'all', 'normal', sa, now() - interval '20 days');
  end if;
  if not exists (select 1 from public.announcements where title = 'JEE Main Mock Test 2 is now live') then
    insert into public.announcements(organization_id, title, body, target_type, target_batch, priority, created_by, published_at)
    values (siit, 'JEE Main Mock Test 2 is now live', E'Mock Test 2 is open for the next 14 days. Duration 60 minutes, negative marking applies.\nYour score is shown immediately after you submit. All the best!', 'batch', b_jee, 'high', f_mat, now() - interval '1 day');
  end if;
  if not exists (select 1 from public.announcements where title = 'NEET UG Full Mock 1 – this week') then
    insert into public.announcements(organization_id, title, body, target_type, target_batch, priority, created_by, published_at)
    values (siit, 'NEET UG Full Mock 1 – this week', E'The full Biology mock opens in two days. Revise Cell Biology, Digestion and Breathing.\nReport 15 minutes early to the computer lab, Parihar Chowk, Aundh.', 'batch', b_neet, 'normal', f_bio, now() - interval '6 hours');
  end if;
  if not exists (select 1 from public.announcements where title = 'Parent–teacher meeting on Saturday') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (siit, 'Parent–teacher meeting on Saturday', E'A parent–teacher meeting will be held this Saturday at 11:00 am in the institute hall.\nMock test reports will be shared with parents.', 'organization', siit, 'normal', coalesce(ia, sa), now() - interval '2 days');
  end if;

  -- ---------- notifications ----------
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
  select m.user_id, 'New exam assigned', '"JEE Main Mock Test 2" is open now.', 'exam', e2, 'exam', 'my-exams.html', now() - interval '1 day'
  from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_jee and u.role = 'student'
    and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = e2);
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
  select m.user_id, 'Exam scheduled', '"NEET UG Full Mock 1" opens in two days.', 'exam', e4, 'exam', 'my-exams.html', now() - interval '6 hours'
  from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_neet and u.role = 'student'
    and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = e4);
end $$;


-- ===================== PART 2 – up to 100 records =====================

-- ---------- helpers (temporary, removed automatically when the session ends) ----------
create or replace function pg_temp.subj(cat uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.subjects where exam_category_id = cat and lower(name) = lower(nm);
  if i is null then insert into public.subjects(exam_category_id, name, order_index) values (cat, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.unit(sid uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.units where subject_id = sid and lower(name) = lower(nm);
  if i is null then insert into public.units(subject_id, name, order_index) values (sid, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.chap(sid uuid, uid uuid, nm text, ord int, w numeric) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.chapters where subject_id = sid and lower(name) = lower(nm);
  if i is null then insert into public.chapters(subject_id, unit_id, name, order_index, weightage, status) values (sid, uid, nm, ord, w, 'published') returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.topic(cid uuid, nm text, ord int) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.topics where chapter_id = cid and lower(name) = lower(nm);
  if i is null then insert into public.topics(chapter_id, name, order_index) values (cid, nm, ord) returning id into i; end if;
  return i; end $$;
create or replace function pg_temp.q(sid uuid, cid uuid, tid uuid, txt text, typ text, diff text, opts jsonb, ans jsonb, expl text, who uuid) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.questions where question_text = txt;
  if i is null then
    insert into public.questions(organization_id, subject_id, chapter_id, topic_id, question_text, question_type, difficulty, language, options, correct_answer, explanation,
                                 marks, negative_marks, status, source, created_by, reviewed_by, approved_at)
    values (null, sid, cid, tid, txt, typ, diff, 'en', opts, ans, expl, 4, case when typ = 'mcq_single' then 1 else 0 end, 'approved', 'manual', who, who, now())
    returning id into i;
  end if;
  return i; end $$;
create or replace function pg_temp.person(em text, nm text, rl text, org uuid, roll text, ph text, pw text) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.users where lower(email) = lower(em);
  if i is null then
    insert into public.users(email, full_name, role, organization_id, roll_number, phone, is_active, password_hash, created_at)
    values (lower(em), nm, rl, org, roll, ph, true, extensions.crypt(pw, extensions.gen_salt('bf', 10)), now() - interval '45 days') returning id into i;
  end if;
  return i; end $$;
create or replace function pg_temp.member(bid uuid, uid uuid, rl text) returns void language plpgsql as $$
begin
  if not exists (select 1 from public.batch_members where batch_id = bid and user_id = uid) then
    insert into public.batch_members(batch_id, user_id, role_in_batch, joined_at) values (bid, uid, rl, now() - interval '40 days');
  end if; end $$;
create or replace function pg_temp.exam(org uuid, cat uuid, ttl text, dsc text, mins int, st text, t0 timestamptz, t1 timestamptz, instr text, pass numeric, neg boolean, showres boolean, who uuid) returns uuid language plpgsql as $$
declare i uuid; begin
  select id into i from public.exams where organization_id = org and title = ttl;
  if i is null then
    insert into public.exams(organization_id, exam_category_id, title, description, duration_minutes, attempt_limit, negative_marking, shuffle_questions, shuffle_options,
                             show_result_immediately, status, start_time, end_time, instructions, pass_percentage, created_by, published_by, published_at, created_at)
    values (org, cat, ttl, dsc, mins, 1, neg, true, true, showres, st, t0, t1, instr, pass, who, who, t0, t0 - interval '3 days') returning id into i;
  elsif not exists (select 1 from public.exam_attempts where exam_id = i) then
    -- an older copy with no attempts yet (e.g. from the previous sample file): bring it in line
    update public.exams set exam_category_id = cat, description = dsc, duration_minutes = mins, status = st, start_time = t0, end_time = t1,
           instructions = instr, pass_percentage = pass, negative_marking = neg, show_result_immediately = showres where id = i;
    delete from public.exam_questions where exam_id = i;
  end if;
  return i; end $$;
create or replace function pg_temp.fill(eid uuid, qs uuid[], who uuid, bid uuid) returns void language plpgsql as $$
declare k int;
begin
  if not exists (select 1 from public.exam_questions where exam_id = eid) then
    for k in 1..cardinality(qs) loop
      insert into public.exam_questions(exam_id, question_id, order_index, marks, section)
      values (eid, qs[k], k, 4, (select s.name from public.questions q join public.subjects s on s.id = q.subject_id where q.id = qs[k]));
    end loop;
  end if;
  if not exists (select 1 from public.exam_assignments where exam_id = eid and batch_id = bid) then
    insert into public.exam_assignments(exam_id, batch_id, assigned_by) values (eid, bid, who);
  end if;
  perform private.recalc_exam(eid);
end $$;

-- realistic completed attempts for every student of a batch (scored by the real scoring engine)

-- results for every student of the given batches who hasn't taken the exam yet (scored by the real engine)
create or replace function pg_temp.simulate2(eid uuid, bids uuid[]) returns void language plpgsql as $$
declare e public.exams; a public.exam_attempts; stu record; q record; ans jsonb; qt jsonb; ability numeric; r numeric; n int := 0; st timestamptz; spent int; wrong text; slot int;
begin
  select * into e from public.exams where id = eid;
  slot := greatest(1, floor(extract(epoch from (least(e.end_time, now()) - e.start_time)) / 3600 / 60)::int);   -- spread attempts over the exam window
  for stu in select distinct u.id, u.roll_number from public.batch_members m join public.users u on u.id = m.user_id
             where m.batch_id = any(bids) and u.role = 'student' order by u.roll_number loop
    n := n + 1;
    continue when exists (select 1 from public.exam_attempts x where x.exam_id = eid and x.user_id = stu.id);
    continue when (select last_login_at from public.users where id = stu.id) < now() - interval '15 days';   -- students who stopped coming were absent
    ability := 0.32 + ((n * 29) % 55) / 100.0;                     -- 32% … 86%
    ans := '{}'; qt := '{}';
    st := e.start_time + make_interval(hours => (n * slot) % greatest(1, floor(extract(epoch from (least(e.end_time, now()) - e.start_time)) / 3600)::int - 2), mins => (n * 7) % 60);
    for q in select qq.id, qq.question_type, qq.options, qq.correct_answer, qq.difficulty from public.exam_questions eq join public.questions qq on qq.id = eq.question_id
             where eq.exam_id = eid order by eq.order_index loop
      r := random();
      if q.difficulty = 'hard' then r := r + 0.15; elsif q.difficulty = 'easy' then r := r - 0.1; end if;
      if r < ability then
        ans := ans || jsonb_build_object(q.id, case when q.question_type = 'numerical' then to_jsonb((q.correct_answer->>'value')) else q.correct_answer end);
      elsif r < ability + (1 - ability) * 0.7 then
        if q.question_type = 'numerical' then ans := ans || jsonb_build_object(q.id, to_jsonb(((q.correct_answer->>'value')::numeric + 1)::text));
        elsif q.question_type = 'true_false' then ans := ans || jsonb_build_object(q.id, case when q.correct_answer #>> '{}' = 'true' then 'false' else 'true' end);
        else
          select o->>'key' into wrong from jsonb_array_elements(q.options) o where o->>'key' <> q.correct_answer #>> '{}' order by random() limit 1;
          ans := ans || jsonb_build_object(q.id, wrong);
        end if;
      end if;
      qt := qt || jsonb_build_object(q.id, 30 + floor(random() * 100)::int);
    end loop;
    select coalesce(sum((v)::int), 0) into spent from jsonb_each_text(qt) x(k, v);
    insert into public.exam_attempts(exam_id, user_id, attempt_number, status, started_at, answers, auto_save_data, tab_switches, user_agent)
    values (eid, stu.id, 1, 'in_progress', st, ans, jsonb_build_object('qtime', qt), (n % 5 = 0)::int + (n % 11 = 0)::int * 2, 'Mozilla/5.0') returning * into a;
    perform private.finalize_attempt(e, a, ans, false);
    update public.exam_attempts set submitted_at = st + make_interval(secs => spent), time_spent_seconds = spent,
           auto_save_data = auto_save_data || jsonb_build_object('qtime', qt) where id = a.id;
    update public.results set time_spent_seconds = spent, created_at = st + make_interval(secs => spent), is_visible = true, released_at = e.end_time
     where exam_attempt_id = a.id;
    insert into public.activity_events(user_id, exam_attempt_id, event_type, created_at, meta) values (stu.id, a.id, 'session_start', st, jsonb_build_object('exam_id', eid));
    update public.activity_events set created_at = st + make_interval(secs => spent) where exam_attempt_id = a.id and event_type = 'completion';
    insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
    values (stu.id, 'Result published', format('Your result for "%s" is now available.', e.title), 'result', eid, 'exam', 'results.html', n % 3 = 0, e.end_time);
  end loop;
  perform private.recalc_ranks(eid);
end $$;

-- the decimal shown in question text (2.0 → "2", 0.50 → "0.5")
create or replace function pg_temp.fmt(x numeric) returns text language sql immutable as $$ select regexp_replace(regexp_replace(round(x, 6)::text, '(\.[0-9]*?)0+$', '\1'), '\.$', '') $$;
-- a numerical question (answer checked with zero tolerance)
create or replace function pg_temp.qn(sid uuid, cid uuid, tid uuid, txt text, diff text, val numeric, expl text, who uuid) returns uuid language sql as $$
  select pg_temp.q(sid, cid, tid, txt, 'numerical', diff, null, jsonb_build_object('value', pg_temp.fmt(val)::numeric, 'tolerance', 0), expl, who) $$;
-- a single-correct MCQ from four option texts; the correct one is given by its letter
create or replace function pg_temp.qm(sid uuid, cid uuid, tid uuid, txt text, diff text, a text, b text, c text, d text, ans text, expl text, who uuid) returns uuid language sql as $$
  select pg_temp.q(sid, cid, tid, txt, 'mcq_single', diff,
    jsonb_build_array(jsonb_build_object('key','A','text',a), jsonb_build_object('key','B','text',b), jsonb_build_object('key','C','text',c), jsonb_build_object('key','D','text',d)),
    to_jsonb(ans), expl, who) $$;
-- the decimal shown in question text (2.0 → "2", 0.50 → "0.5")
-- MCQ whose correct answer sits at position p (0–3) so answers are spread over A–D
create or replace function pg_temp.qrot(sid uuid, cid uuid, tid uuid, txt text, diff text, correct text, d1 text, d2 text, d3 text, p int, expl text, who uuid) returns uuid language plpgsql as $$
declare o text[] := array[d1, d2, d3]; begin
  o := o[1:p] || correct || o[p + 1:3];
  return pg_temp.qm(sid, cid, tid, txt, diff, o[1], o[2], o[3], o[4], chr(65 + p), expl, who); end $$;
create or replace function pg_temp.sup(n int) returns text language sql immutable as $$ select translate(n::text, '0123456789', '⁰¹²³⁴⁵⁶⁷⁸⁹') $$;

do $$
declare
  siit uuid; atss uuid; root uuid; sa uuid; ia uuid; jee uuid; neet uuid;
  phy uuid; che uuid; mat uuid; bio uuid;
  c_kin uuid; c_cur uuid; c_mole uuid; c_eq uuid; c_quad uuid; c_cplx uuid; c_lim uuid;
  t_1d uuid; t_ohm uuid; t_avo uuid; t_ion uuid; t_roots uuid; t_nature uuid; t_iota uuid; t_deriv uuid;
  u_bot uuid; u_zoo uuid; u_gen uuid; c_dig uuid; t_bile uuid; t_enz uuid;
  c_circ uuid; c_exc uuid; c_neu uuid; c_endo uuid; c_biom uuid; c_ps uuid; c_inh uuid; c_mol uuid; c_pk uuid;
  t_heart uuid; t_blood uuid; t_kid uuid; t_neuron uuid; t_brain uuid; t_glands uuid; t_carb uuid; t_prot uuid; t_vit uuid;
  t_light uuid; t_pig uuid; t_mendel uuid; t_rep uuid; t_chrom uuid; t_pter uuid;
  f_phy uuid; f_che uuid; f_mat uuid; f_bio uuid;
  b_jee uuid; b_neet uuid; b_jeeb uuid; b_neetb uuid;
  e2 uuid; e4 uuid; e5 uuid; e6 uuid; a3 uuid; a4 uuid; act4 uuid; act5 uuid;
  qj uuid[] := '{}'; qbio uuid[] := '{}'; i uuid; k int; n int; uid_ uuid; stu record;
  pk numeric[]; pv text[];
  jee_first text[] := array['Aditi','Akash','Amruta','Aniket','Anushka','Aryan','Bhakti','Chaitanya','Darshan','Devika','Dhruv','Gargi','Gaurav','Hrishikesh',
    'Janhavi','Jay','Ketaki','Kunal','Manasi','Mihir','Nikhil','Nidhi','Ojas','Parth','Payal','Pratik','Rachana','Rajvardhan','Rutuja','Sahil','Samruddhi',
    'Sarthak','Shravani','Shubham','Swara','Tejaswini','Tushar','Vaishnavi'];
  neet_first text[] := array['Abhishek','Aishwarya','Ajinkya','Apurva','Bhushan','Chinmay','Damini','Disha','Ganesh','Harshada','Ishaan','Jui','Kartik','Kshitija',
    'Madhura','Mayur','Nachiket','Namrata','Nishant','Pallavi','Prathamesh','Rasika','Rohit','Sampada','Saurabh','Shruti','Snehal','Sujay','Supriya','Tanmay',
    'Urvi','Varad','Vidya','Vinay','Yogesh','Yashashri','Komal','Ruturaj'];
  last_names text[] := array['Kulkarni','Deshmukh','Patil','Pawar','Jadhav','Shinde','Gaikwad','Chavan','Bhosale','Kale','Joshi','Mane','Deshpande','Sawant',
    'Kadam','Kamble','Thakur','Gokhale','Rane','Phadke','Naik','Karande','Mohite'];
  nm text; em text;
begin
  perform setseed(0.4127);

  select id into root from public.organizations where code = 'KDRT';
  select id into atss from public.organizations where code = 'ATSS';
  select id into siit from public.organizations where code = 'SIIT03';
  select id into sa from public.users where role = 'super_admin' order by created_at limit 1;
  select id into ia from public.users where role = 'institute_admin' and organization_id = siit order by created_at limit 1;
  select id into jee from public.exam_categories where code = 'JEE_MAIN' or lower(trim(name)) in ('jee main', 'jee mains', 'jee (main)') order by (code = 'JEE_MAIN') desc nulls last limit 1;
  select id into neet from public.exam_categories where code = 'NEET_UG' or lower(trim(name)) in ('neet ug', 'neet', 'neet-ug', 'neet (ug)') order by (code = 'NEET_UG') desc nulls last limit 1;
  select id into f_phy from public.users where email = 'rahul.deshmukh@sujatainstitute.in';
  select id into f_che from public.users where email = 'meera.apte@sujatainstitute.in';
  select id into f_mat from public.users where email = 'sandeep.gore@sujatainstitute.in';
  select id into f_bio from public.users where email = 'kavita.bhide@sujatainstitute.in';
  select id into b_jee from public.batches where organization_id = siit and (name = 'JEE Main 2027 – Batch A' or code = 'JEE27A') order by (name = 'JEE Main 2027 – Batch A') desc limit 1;
  select id into b_neet from public.batches where organization_id = siit and (name = 'NEET UG 2027 – Batch A' or code = 'NEET27A') order by (name = 'NEET UG 2027 – Batch A') desc limit 1;
  select id into e2 from public.exams where organization_id = siit and title = 'JEE Main Mock Test 2';
  select id into e4 from public.exams where organization_id = siit and title = 'NEET UG Full Mock 1';

  -- ---------- syllabus (existing chapters are found by name; a few new Biology chapters are added) ----------
  phy := pg_temp.subj(jee, 'Physics', 1); che := pg_temp.subj(jee, 'Chemistry', 2); mat := pg_temp.subj(jee, 'Mathematics', 3); bio := pg_temp.subj(neet, 'Biology', 3);
  c_kin := pg_temp.chap(phy, null, 'Kinematics', 1, 6); t_1d := pg_temp.topic(c_kin, 'Motion in a Straight Line', 1);
  c_cur := pg_temp.chap(phy, null, 'Current Electricity', 3, 7); t_ohm := pg_temp.topic(c_cur, 'Ohm''s Law', 1);
  c_mole := pg_temp.chap(che, null, 'Some Basic Concepts of Chemistry', 1, 4); t_avo := pg_temp.topic(c_mole, 'Mole Concept & Avogadro Number', 1);
  c_eq := pg_temp.chap(che, null, 'Chemical Equilibrium', 2, 5); t_ion := pg_temp.topic(c_eq, 'Ionic Equilibrium & pH', 2);
  c_quad := pg_temp.chap(mat, null, 'Quadratic Equations', 1, 5); t_roots := pg_temp.topic(c_quad, 'Roots of a Quadratic Equation', 1);
  c_cplx := pg_temp.chap(mat, null, 'Complex Numbers', 2, 4); t_iota := pg_temp.topic(c_cplx, 'Powers of i and Modulus', 1);
  c_lim := pg_temp.chap(mat, null, 'Limits and Derivatives', 3, 6); t_deriv := pg_temp.topic(c_lim, 'Derivatives of Standard Functions', 2);
  u_bot := pg_temp.unit(bio, 'Botany', 1); u_zoo := pg_temp.unit(bio, 'Zoology', 2); u_gen := pg_temp.unit(bio, 'Genetics and Evolution', 3);
  c_dig := pg_temp.chap(bio, u_zoo, 'Digestion and Absorption', 3, 5); t_enz := pg_temp.topic(c_dig, 'Digestive Enzymes', 1); t_bile := pg_temp.topic(c_dig, 'Digestive Glands', 2);
  c_biom := pg_temp.chap(bio, u_bot, 'Biomolecules', 6, 4);
    t_carb := pg_temp.topic(c_biom, 'Carbohydrates', 1); t_prot := pg_temp.topic(c_biom, 'Proteins and Amino Acids', 2); t_vit := pg_temp.topic(c_biom, 'Vitamins', 3);
  c_ps := pg_temp.chap(bio, u_bot, 'Photosynthesis in Higher Plants', 7, 5);
    t_light := pg_temp.topic(c_ps, 'Light Reaction', 1); t_pig := pg_temp.topic(c_ps, 'Photosynthetic Pigments', 2);
  c_pk := pg_temp.chap(bio, u_bot, 'Plant Kingdom', 8, 3); t_pter := pg_temp.topic(c_pk, 'Pteridophytes', 1);
  c_circ := pg_temp.chap(bio, u_zoo, 'Body Fluids and Circulation', 9, 5);
    t_heart := pg_temp.topic(c_circ, 'Human Heart', 1); t_blood := pg_temp.topic(c_circ, 'Blood and Blood Groups', 2);
  c_exc := pg_temp.chap(bio, u_zoo, 'Excretory Products and their Elimination', 10, 4); t_kid := pg_temp.topic(c_exc, 'Human Kidney and Nephron', 1);
  c_neu := pg_temp.chap(bio, u_zoo, 'Neural Control and Coordination', 11, 4);
    t_neuron := pg_temp.topic(c_neu, 'Neuron', 1); t_brain := pg_temp.topic(c_neu, 'Human Brain', 2);
  c_endo := pg_temp.chap(bio, u_zoo, 'Chemical Coordination and Integration', 12, 4); t_glands := pg_temp.topic(c_endo, 'Human Endocrine Glands', 1);
  c_inh := pg_temp.chap(bio, u_gen, 'Principles of Inheritance and Variation', 13, 7);
    t_mendel := pg_temp.topic(c_inh, 'Mendelian Inheritance', 1); t_chrom := pg_temp.topic(c_inh, 'Chromosomes', 2);
  c_mol := pg_temp.chap(bio, u_gen, 'Molecular Basis of Inheritance', 14, 7); t_rep := pg_temp.topic(c_mol, 'DNA Replication', 1);

  -- ---------- two more batches ----------
  select id into b_jeeb from public.batches where organization_id = siit and (code = 'JEE27B' or name = 'JEE Main 2027 – Batch B') limit 1;
  if b_jeeb is null then insert into public.batches(organization_id, name, code, academic_year, exam_category_id, start_date, end_date, description, created_by, created_at)
    values (siit, 'JEE Main 2027 – Batch B', 'JEE27B', '2026-27', jee, current_date - 32, current_date + 260, 'Afternoon batch (12:00–4:00 pm) – Physics, Chemistry, Mathematics', coalesce(ia, sa), now() - interval '33 days') returning id into b_jeeb; end if;
  select id into b_neetb from public.batches where organization_id = siit and (code = 'NEET27B' or name = 'NEET UG 2027 – Batch B') limit 1;
  if b_neetb is null then insert into public.batches(organization_id, name, code, academic_year, exam_category_id, start_date, end_date, description, created_by, created_at)
    values (siit, 'NEET UG 2027 – Batch B', 'NEET27B', '2026-27', neet, current_date - 32, current_date + 260, 'Weekend batch (Sat–Sun, 8:00 am–2:00 pm) – Physics, Chemistry, Biology', coalesce(ia, sa), now() - interval '33 days') returning id into b_neetb; end if;
  perform pg_temp.member(b_jeeb, f_phy, 'faculty'); perform pg_temp.member(b_jeeb, f_che, 'faculty'); perform pg_temp.member(b_jeeb, f_mat, 'coordinator');
  perform pg_temp.member(b_neetb, f_phy, 'faculty'); perform pg_temp.member(b_neetb, f_che, 'faculty'); perform pg_temp.member(b_neetb, f_bio, 'coordinator');

  -- ---------- 76 more students (100 in all) ----------
  for k in 1..38 loop
    nm := jee_first[k] || ' ' || last_names[1 + (k * 7) % 23]; em := lower(jee_first[k] || '.' || last_names[1 + (k * 7) % 23]) || '@sujatainstitute.in';
    uid_ := pg_temp.person(em, nm, 'student', siit, format('SIIT/JEE/27/%s', lpad((12 + k)::text, 3, '0')), '98900' || lpad((41112 + k)::text, 5, '0'), 'Student@123');
    perform pg_temp.member(b_jeeb, uid_, 'student');
    nm := neet_first[k] || ' ' || last_names[1 + (k * 11) % 23]; em := lower(neet_first[k] || '.' || last_names[1 + (k * 11) % 23]) || '@sujatainstitute.in';
    uid_ := pg_temp.person(em, nm, 'student', siit, format('SIIT/NEET/27/%s', lpad((12 + k)::text, 3, '0')), '98900' || lpad((41212 + k)::text, 5, '0'), 'Student@123');
    perform pg_temp.member(b_neetb, uid_, 'student');
  end loop;
  update public.users set created_at = now() - interval '34 days'
   where id in (select user_id from public.batch_members where batch_id in (b_jeeb, b_neetb)) and role = 'student' and created_at > now() - interval '34 days';

  -- ---------- login history for students who have none yet ----------
  n := 0;
  for stu in select u.id from public.users u where u.organization_id = siit and u.role = 'student'
               and not exists (select 1 from public.activity_events e where e.user_id = u.id and e.event_type = 'login') order by u.roll_number loop
    n := n + 1;
    if n % 13 = 0 then          -- stopped coming
      insert into public.activity_events(user_id, event_type, created_at) values (stu.id, 'login', now() - interval '21 days');
      update public.users set last_login_at = now() - interval '21 days' where id = stu.id;
    elsif n % 9 = 0 then        -- away for over a week
      insert into public.activity_events(user_id, event_type, created_at) select stu.id, 'login', now() - make_interval(days => gs.dd) from generate_series(9, 15, 2) gs(dd);
      update public.users set last_login_at = now() - interval '9 days' where id = stu.id;
    elsif n % 5 = 0 then        -- comes now and then
      insert into public.activity_events(user_id, event_type, created_at) select stu.id, 'login', now() - make_interval(days => gs.dd, hours => 3) from generate_series(4, 14, 3) gs(dd);
      update public.users set last_login_at = now() - interval '4 days 3 hours' where id = stu.id;
    else                        -- regular
      insert into public.activity_events(user_id, event_type, created_at)
      select stu.id, 'login', now() - make_interval(days => gs.dd, hours => (random() * 10)::int) from generate_series(0, 13) gs(dd) where random() < 0.7;
      update public.users set last_login_at = now() - make_interval(hours => 1 + (n % 30)) where id = stu.id;
    end if;
  end loop;

  -- ---------- question bank: Physics ----------
  pk := array[2,5, 3,4, 5,6, 4,7, 1.5,8];
  for k in 0..4 loop
    i := pg_temp.qn(phy, c_kin, t_1d, format('A body starts from rest and moves with a uniform acceleration of %s m/s². What is its velocity (in m/s) after %s s?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])),
                    'easy', pk[2*k+1] * pk[2*k+2], format('v = u + at = 0 + %s × %s = %s m/s.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] * pk[2*k+2])), f_phy);
    if k < 3 then qj := qj || i; end if;
  end loop;
  pk := array[2,5, 4,3, 6,4, 3,6];
  for k in 0..3 loop
    perform pg_temp.qrot(phy, c_kin, t_1d, format('A car starts from rest with a uniform acceleration of %s m/s². How far does it travel in the first %s s?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])), 'medium',
      pg_temp.fmt(pk[2*k+1] * pk[2*k+2]^2 / 2) || ' m', pg_temp.fmt(pk[2*k+1] * pk[2*k+2]^2) || ' m', pg_temp.fmt(pk[2*k+1] * pk[2*k+2]) || ' m', pg_temp.fmt(pk[2*k+1] * pk[2*k+2]^2 / 2 + pk[2*k+1]) || ' m',
      (k + 1) % 4, format('s = ut + ½at² = 0 + ½ × %s × %s² = %s m.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] * pk[2*k+2]^2 / 2)), f_phy);
  end loop;
  pk := array[2,5, 0.5,20, 3,4, 1.5,6, 4,2.5, 2,11];
  for k in 0..5 loop
    i := pg_temp.qn(phy, c_cur, t_ohm, format('A current of %s A flows through a resistor of %s Ω. What is the potential difference (in volts) across it?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])),
                    'easy', pk[2*k+1] * pk[2*k+2], format('V = IR = %s × %s = %s V.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] * pk[2*k+2])), f_phy);
    if k < 2 then qj := qj || i; end if;
  end loop;

  -- ---------- Chemistry ----------
  pv := array['water (H₂O)','carbon dioxide (CO₂)','sodium hydroxide (NaOH)','methane (CH₄)','ammonia (NH₃)','glucose (C₆H₁₂O₆)'];
  pk := array[18,36, 44,88, 40,20, 16,64, 17,51, 180,90];
  for k in 0..5 loop
    i := pg_temp.qn(che, c_mole, t_avo, format('How many moles are present in %s g of %s? (Molar mass = %s g/mol)', pg_temp.fmt(pk[2*k+2]), pv[k+1], pg_temp.fmt(pk[2*k+1])),
                    case when k < 3 then 'easy' else 'medium' end, pk[2*k+2] / pk[2*k+1],
                    format('Moles = mass ÷ molar mass = %s ÷ %s = %s mol.', pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2] / pk[2*k+1])), f_che);
    if k < 3 then qj := qj || i; end if;
  end loop;
  pv := array['0.01 M HCl','0.001 M HCl','0.1 M HCl','0.01 M NaOH'];
  pk := array[2, 3, 1, 12];
  for k in 0..3 loop
    i := pg_temp.qn(che, c_eq, t_ion, format('What is the pH of a %s solution at 25 °C? (Assume complete dissociation.)', pv[k+1]),
                    case when k = 3 then 'hard' else 'medium' end, pk[k+1],
                    case when k = 3 then '[OH⁻] = 10⁻² M, so pOH = 2 and pH = 14 − 2 = 12.'
                         else format('[H⁺] = %s M, so pH = −log[H⁺] = %s.', split_part(pv[k+1], ' ', 1), pg_temp.fmt(pk[k+1])) end, f_che);
    if k < 2 then qj := qj || i; end if;
  end loop;

  -- ---------- Mathematics ----------
  pk := array[2,3, 3,4, 1,6];
  for k in 0..2 loop
    i := pg_temp.qrot(mat, c_quad, t_roots, format('For the equation x² − %sx + %s = 0, what is the sum of the roots?', pk[2*k+1] + pk[2*k+2], pk[2*k+1] * pk[2*k+2]), 'easy',
           (pk[2*k+1] + pk[2*k+2])::text, (-(pk[2*k+1] + pk[2*k+2]))::text, (pk[2*k+1] * pk[2*k+2])::text, (-(pk[2*k+1] * pk[2*k+2]))::text, k % 4,
           format('Sum of roots = −b/a = %s. (The roots are %s and %s.)', pk[2*k+1] + pk[2*k+2], pk[2*k+1], pk[2*k+2]), f_mat);
    if k = 0 then qj := qj || i; end if;
  end loop;
  pk := array[2,5, 3,5, 4,6];
  for k in 0..2 loop
    i := pg_temp.qrot(mat, c_quad, t_roots, format('For the equation x² − %sx + %s = 0, what is the product of the roots?', pk[2*k+1] + pk[2*k+2], pk[2*k+1] * pk[2*k+2]), 'easy',
           (pk[2*k+1] * pk[2*k+2])::text, (-(pk[2*k+1] * pk[2*k+2]))::text, (pk[2*k+1] + pk[2*k+2])::text, (-(pk[2*k+1] + pk[2*k+2]))::text, (k + 2) % 4,
           format('Product of roots = c/a = %s. (The roots are %s and %s.)', pk[2*k+1] * pk[2*k+2], pk[2*k+1], pk[2*k+2]), f_mat);
    if k = 0 then qj := qj || i; end if;
  end loop;
  pk := array[2,3, 3,2, 4,1, 3,3, 2,7, 5,1];
  for k in 0..5 loop
    i := pg_temp.qn(mat, c_lim, t_deriv, format('If f(x) = x%s, what is the value of f′(%s)?', pg_temp.sup(pk[2*k+1]::int), pk[2*k+2]),
                    case when k < 2 then 'easy' else 'medium' end, pk[2*k+1] * pk[2*k+2] ^ (pk[2*k+1] - 1),
                    format('f′(x) = %s·x%s, so f′(%s) = %s.', pk[2*k+1], pg_temp.sup((pk[2*k+1] - 1)::int), pk[2*k+2], pg_temp.fmt(pk[2*k+1] * pk[2*k+2] ^ (pk[2*k+1] - 1))), f_mat);
    if k < 2 then qj := qj || i; end if;
  end loop;
  pk := array[7, 10, 13, 20];
  for k in 0..3 loop
    i := pg_temp.qm(mat, c_cplx, t_iota, format('What is the value of i%s, where i = √−1?', pg_temp.sup(pk[k+1]::int)), 'medium', 'i', '−1', '−i', '1',
                    (array['D','A','B','C'])[(pk[k+1]::int % 4) + 1],
                    format('i⁴ = 1, so i%s = i%s = %s.', pg_temp.sup(pk[k+1]::int), pg_temp.sup(pk[k+1]::int % 4), (array['1','i','−1','−i'])[(pk[k+1]::int % 4) + 1]), f_mat);
    if k = 0 then qj := qj || i; end if;
  end loop;

  -- ---------- Biology ----------
  qbio := qbio || pg_temp.qm(bio, c_circ, t_heart, 'Which blood vessel carries oxygenated blood from the lungs to the heart?', 'easy', 'Pulmonary artery', 'Pulmonary vein', 'Vena cava', 'Aorta', 'B', 'Pulmonary veins bring oxygen-rich blood from the lungs to the left atrium.', f_bio);
  qbio := qbio || pg_temp.qn(bio, c_circ, t_heart, 'How many chambers are there in the human heart?', 'easy', 4, 'Two atria and two ventricles.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_circ, t_heart, 'The pacemaker of the human heart is the:', 'medium', 'AV node', 'Bundle of His', 'SA node', 'Purkinje fibres', 'C', 'The sino-atrial (SA) node starts each heartbeat.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_circ, t_blood, 'Which blood group is known as the universal donor?', 'easy', 'A', 'B', 'AB', 'O', 'D', 'Group O red cells carry neither A nor B antigens.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_circ, t_blood, 'Which vitamin is needed for normal clotting of blood?', 'medium', 'Vitamin A', 'Vitamin C', 'Vitamin D', 'Vitamin K', 'D', 'Vitamin K is needed to make prothrombin and other clotting factors.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_exc, t_kid, 'The structural and functional unit of the kidney is the:', 'easy', 'Nephron', 'Neuron', 'Alveolus', 'Villus', 'A', 'Each kidney has about one million nephrons.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_neu, t_brain, 'Which part of the brain maintains balance and posture?', 'medium', 'Cerebrum', 'Medulla oblongata', 'Cerebellum', 'Hypothalamus', 'C', 'The cerebellum coordinates movement and balance.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_endo, t_glands, 'Insulin is secreted by which cells of the pancreas?', 'medium', 'α-cells', 'β-cells', 'δ-cells', 'Acinar cells', 'B', 'β-cells of the islets of Langerhans secrete insulin.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_dig, t_enz, 'Salivary amylase breaks down starch into:', 'medium', 'Glucose', 'Sucrose', 'Fructose', 'Maltose', 'D', 'Salivary amylase (ptyalin) hydrolyses starch into maltose.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_biom, t_carb, 'Which of the following is a polysaccharide?', 'easy', 'Glucose', 'Sucrose', 'Cellulose', 'Fructose', 'C', 'Cellulose is a polymer of glucose; the others are mono- or disaccharides.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_ps, t_light, 'The light reactions of photosynthesis take place in the:', 'medium', 'Stroma', 'Thylakoid membranes', 'Cytoplasm', 'Mitochondrial matrix', 'B', 'Photosystems I and II are located in the thylakoid membranes.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_inh, t_mendel, 'Mendel performed his experiments on the:', 'easy', 'Fruit fly', 'Maize plant', 'Garden pea', 'Snapdragon', 'C', 'Mendel used the garden pea (Pisum sativum).', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_inh, t_mendel, 'The phenotypic ratio in the F₂ generation of a monohybrid cross is:', 'medium', '1 : 2 : 1', '3 : 1', '9 : 3 : 3 : 1', '1 : 1', 'B', 'Dominant : recessive phenotypes appear in a 3 : 1 ratio.', f_bio);
  qbio := qbio || pg_temp.qm(bio, c_mol, t_rep, 'DNA replication is:', 'hard', 'Conservative', 'Dispersive', 'Non-conservative', 'Semi-conservative', 'D', 'Meselson and Stahl showed each new DNA keeps one parent strand.', f_bio);
  qbio := qbio || pg_temp.qn(bio, c_inh, t_chrom, 'How many pairs of chromosomes are present in a normal human body cell?', 'easy', 23, '46 chromosomes = 23 pairs (22 pairs of autosomes + 1 pair of sex chromosomes).', f_bio);
  -- in the question bank only
  perform pg_temp.qm(bio, c_neu, t_neuron, 'The structural and functional unit of the nervous system is the:', 'easy', 'Nephron', 'Sarcomere', 'Nucleus', 'Neuron', 'D', 'Neurons carry nerve impulses.', f_bio);
  perform pg_temp.qm(bio, c_dig, t_bile, 'The largest gland in the human body is the:', 'easy', 'Pancreas', 'Thyroid', 'Liver', 'Pituitary', 'C', 'The liver weighs about 1.2–1.5 kg in an adult.', f_bio);
  perform pg_temp.qm(bio, c_biom, t_prot, 'Proteins are polymers of:', 'easy', 'Amino acids', 'Nucleotides', 'Fatty acids', 'Monosaccharides', 'A', 'Amino acids are joined by peptide bonds.', f_bio);
  perform pg_temp.qm(bio, c_biom, t_vit, 'Which vitamin is made in the skin in the presence of sunlight?', 'easy', 'Vitamin D', 'Vitamin A', 'Vitamin C', 'Vitamin B₁₂', 'A', 'UV light converts 7-dehydrocholesterol in the skin into vitamin D.', f_bio);
  perform pg_temp.qm(bio, c_ps, t_pig, 'The main photosynthetic pigment in green plants is:', 'easy', 'Chlorophyll a', 'Carotene', 'Xanthophyll', 'Anthocyanin', 'A', 'Chlorophyll a is the primary pigment at the reaction centre.', f_bio);
  perform pg_temp.qm(bio, c_pk, t_pter, 'Plants that have vascular tissue but do not produce seeds are:', 'medium', 'Bryophytes', 'Pteridophytes', 'Gymnosperms', 'Angiosperms', 'B', 'Pteridophytes (ferns) are the first vascular plants; they reproduce by spores.', f_bio);
  perform pg_temp.q(bio, c_circ, t_blood, 'Mature human red blood cells have no nucleus.', 'true_false', 'easy', '[{"key":"true","text":"True"},{"key":"false","text":"False"}]', '"true"', 'Mammalian RBCs lose their nucleus to carry more haemoglobin.', f_bio);

  -- tidy numerical answers (6.0000 → 6)
  update public.questions set correct_answer = jsonb_set(correct_answer, '{value}', to_jsonb(pg_temp.fmt((correct_answer->>'value')::numeric)::numeric))
   where question_type = 'numerical' and correct_answer->>'value' ~ '^-?[0-9]+\.[0-9]*0$';

  -- ---------- two more completed weekly tests (both batches each) ----------
  e5 := pg_temp.exam(siit, jee, 'JEE Weekly Test 3 – Mixed Practice', 'Kinematics, current electricity, mole concept, pH, quadratics, derivatives and complex numbers – 15 questions', 45, 'completed',
                     now() - interval '10 days', now() - interval '3 days', E'1. +4 for each correct answer, −1 for each wrong MCQ.\n2. Numerical answers: type the number only.\n3. Do not switch tabs.', 35, true, false, f_phy);
  perform pg_temp.fill(e5, qj, f_phy, b_jee); perform pg_temp.fill(e5, qj, f_phy, b_jeeb);
  e6 := pg_temp.exam(siit, neet, 'NEET Weekly Test 2 – Human Physiology & Genetics', 'Circulation, excretion, neural and chemical coordination, digestion, photosynthesis and genetics – 15 questions', 30, 'completed',
                     now() - interval '9 days', now() - interval '2 days', E'1. +4 for each correct answer, −1 for each wrong MCQ.\n2. Results are released by your teacher.', 40, true, false, f_bio);
  perform pg_temp.fill(e6, qbio, f_bio, b_neet); perform pg_temp.fill(e6, qbio, f_bio, b_neetb);
  perform pg_temp.simulate2(e5, array[b_jee, b_jeeb]);
  perform pg_temp.simulate2(e6, array[b_neet, b_neetb]);

  -- the live and scheduled mocks are for Batch B too
  if e2 is not null and not exists (select 1 from public.exam_assignments where exam_id = e2 and batch_id = b_jeeb) then
    insert into public.exam_assignments(exam_id, batch_id, assigned_by) values (e2, b_jeeb, f_mat); end if;
  if e4 is not null and not exists (select 1 from public.exam_assignments where exam_id = e4 and batch_id = b_neetb) then
    insert into public.exam_assignments(exam_id, batch_id, assigned_by) values (e4, b_neetb, f_bio); end if;

  -- ---------- assignments with ~100 submissions ----------
  select id into a3 from public.assignments where organization_id = siit and title = 'Chemistry Worksheet – Mole Concept & Stoichiometry';
  if a3 is null then
    insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
    values (siit, 'Chemistry Worksheet – Mole Concept & Stoichiometry', E'Solve all 15 problems on the worksheet given in class (moles, molar mass, limiting reagent).\nWrite each step with units and upload a PDF or clear photos.',
            'homework', 25, now() - interval '2 days', true, 2, 'published', f_che, now() - interval '12 days', 'pdf,jpg,jpeg,png,docx', now() - interval '12 days') returning id into a3;
    insert into public.assignment_batches(assignment_id, batch_id) values (a3, b_jee), (a3, b_jeeb);
    n := 0;
    for stu in select distinct u.id, u.roll_number, u.last_login_at from public.batch_members m join public.users u on u.id = m.user_id
                where m.batch_id in (b_jee, b_jeeb) and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      continue when n % 8 = 0 or stu.last_login_at < now() - interval '15 days';      -- did not submit
      insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content, marks_obtained, feedback, evaluated_by, evaluated_at)
      values (a3, stu.id, 1, now() - make_interval(days => case when n % 10 = 0 then 1 else 3 + n % 7 end, hours => n % 12),
              case when n % 10 = 0 then 'late' when n % 4 = 0 then 'submitted' when n % 17 = 0 then 'needs_correction' else 'evaluated' end,
              'Worksheet solved – all 15 problems with steps and units.',
              case when n % 4 <> 0 and n % 10 <> 0 and n % 17 <> 0 then 12 + (n * 7) % 14 end,
              case when n % 17 = 0 then 'Problems 11–15 (limiting reagent) are missing. Please complete and upload again.'
                   when n % 4 <> 0 and n % 10 <> 0 then (array['Excellent – every step is clear.','Good work. Write units in final answers.','Correct method; check the molar mass of H₂SO₄.',
                                                              'Well presented. Revise limiting reagent problems.','Good attempt – recheck Q9.','Very neat work.'])[1 + n % 6] end,
              case when n % 4 <> 0 and n % 10 <> 0 then f_che end, case when n % 4 <> 0 and n % 10 <> 0 then now() - interval '1 day' end);
    end loop;
  end if;
  select id into a4 from public.assignments where organization_id = siit and title = 'Biology Chart – Human Digestive System';
  if a4 is null then
    insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
    values (siit, 'Biology Chart – Human Digestive System', E'Prepare a labelled chart of the human digestive system with the glands and the enzymes each one secretes.\nUpload a photo or PDF of the chart.',
            'project', 15, now() + interval '4 days', true, 1, 'published', f_bio, now() - interval '8 days', 'pdf,jpg,jpeg,png', now() - interval '8 days') returning id into a4;
    insert into public.assignment_batches(assignment_id, batch_id) values (a4, b_neet), (a4, b_neetb);
    n := 0;
    for stu in select distinct u.id, u.roll_number, u.last_login_at from public.batch_members m join public.users u on u.id = m.user_id
                where m.batch_id in (b_neet, b_neetb) and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      continue when n % 6 = 0 or stu.last_login_at < now() - interval '15 days';
      insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content, marks_obtained, feedback, evaluated_by, evaluated_at)
      values (a4, stu.id, 1, now() - make_interval(days => 1 + n % 6, hours => n % 10),
              case when n % 3 = 0 then 'submitted' when n % 13 = 0 then 'needs_correction' else 'evaluated' end,
              'Chart shows mouth, oesophagus, stomach, liver, pancreas, small and large intestine with enzymes (amylase, pepsin, trypsin, lipase).',
              case when n % 3 <> 0 and n % 13 <> 0 then 8 + (n * 5) % 8 end,
              case when n % 13 = 0 then 'Please add the enzymes of the pancreas and upload again.'
                   when n % 3 <> 0 then (array['Neat chart with correct labels.','Good – add the bile duct.','Excellent colour coding.','Labels are clear; write enzyme names fully.'])[1 + n % 4] end,
              case when n % 3 <> 0 then f_bio end, case when n % 3 <> 0 then now() - interval '12 hours' end);
    end loop;
  end if;

  -- ---------- activities ----------
  select id into act4 from public.activities where organization_id = siit and title = 'Mock Test Analysis – Find Your Weak Topics';
  if act4 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (siit, 'Mock Test Analysis – Find Your Weak Topics', 'practice', 25, now() - interval '4 days', now() + interval '10 days',
            'Open your latest result, list the three weakest topics and solve 10 questions from each.', 15, true, f_mat, now() - interval '4 days') returning id into act4; end if;
  select id into act5 from public.activities where organization_id = siit and title = 'Biology Diagram Practice – 10 Minute Sprint';
  if act5 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (siit, 'Biology Diagram Practice – 10 Minute Sprint', 'timed_test', 10, now() - interval '3 days', now() + interval '11 days',
            'Draw and label the human heart, nephron and neuron – 10 minutes each.', 10, true, f_bio, now() - interval '3 days') returning id into act5; end if;
  if not exists (select 1 from public.activity_events where activity_id in (act4, act5)) then
    insert into public.activity_events(user_id, activity_id, event_type, created_at, meta)
    select distinct on (m.user_id) m.user_id, case when m.batch_id in (b_jee, b_jeeb) then act4 else act5 end, 'practice_complete', now() - make_interval(days => (random() * 3)::int, hours => (random() * 8)::int), '{}'::jsonb
    from public.batch_members m join public.users u on u.id = m.user_id
    where m.batch_id in (b_jee, b_jeeb, b_neet, b_neetb) and u.role = 'student' and u.last_login_at > now() - interval '8 days' and random() < 0.6;
  end if;

  -- ---------- realistic "last seen" for every student ----------
  insert into public.engagement_status(user_id, status, last_activity_at, inactivity_days)
  select u.id, 'active', null, 0 from public.users u where u.organization_id = siit and u.role = 'student'
  on conflict (user_id) do nothing;
  update public.engagement_status es
     set last_activity_at = x.last_at,
         inactivity_days  = floor(extract(epoch from now() - x.last_at) / 86400)::int,
         status = case when x.last_at < now() - interval '7 days' then 'inactive' else 'active' end
    from (select u.id, greatest(u.last_login_at, (select max(created_at) from public.activity_events e where e.user_id = u.id),
                                (select max(submitted_at) from public.assignment_submissions z where z.user_id = u.id)) last_at
            from public.users u where u.organization_id = siit and u.role = 'student') x
   where es.user_id = x.id and x.last_at is not null;

  -- ---------- announcements ----------
  if not exists (select 1 from public.announcements where title = 'Welcome, Batch B!') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (siit, 'Welcome, Batch B!', E'A warm welcome to the students of JEE Main 2027 – Batch B and NEET UG 2027 – Batch B.\nYour timetable, study material and weekly tests are now on the portal.', 'organization', siit, 'normal', coalesce(ia, sa), now() - interval '30 days');
  end if;
  if not exists (select 1 from public.announcements where title = 'Weekly test results released') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (siit, 'Weekly test results released', E'Results of JEE Weekly Test 3 and NEET Weekly Test 2 are out.\nOpen Results to see your rank, subject-wise analysis and the solutions.', 'organization', siit, 'high', coalesce(ia, sa), now() - interval '2 days');
  end if;
  if not exists (select 1 from public.announcements where title = 'Doubt-clearing sessions every Wednesday') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (siit, 'Doubt-clearing sessions every Wednesday', E'Physics, Chemistry, Mathematics and Biology faculty will take doubts every Wednesday, 5:00–7:00 pm, Room 3.\nBring your weekly test papers.', 'organization', siit, 'normal', f_phy, now() - interval '5 days');
  end if;
  if not exists (select 1 from public.announcements where title = 'Library hours extended for exam season') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (siit, 'Library hours extended for exam season', E'The institute library at Parihar Chowk, Aundh will stay open from 7:00 am to 9:00 pm, Monday to Saturday, until the board exams.', 'organization', siit, 'low', coalesce(ia, sa), now() - interval '7 days');
  end if;

  -- ---------- notifications ----------
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
  select m.user_id, 'New assignment', format('"%s" has been assigned to you.', a.title), 'assignment', a.id, 'assignment', 'my-assignments.html', random() < 0.5, a.published_at
  from public.assignments a join public.assignment_batches ab on ab.assignment_id = a.id join public.batch_members m on m.batch_id = ab.batch_id join public.users u on u.id = m.user_id
  where a.id in (a3, a4) and u.role = 'student' and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = a.id);
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
  select m.user_id, 'New exam assigned', '"JEE Main Mock Test 2" is open now.', 'exam', e2, 'exam', 'my-exams.html', now() - interval '1 day'
  from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_jeeb and u.role = 'student' and e2 is not null
    and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = e2);
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
  select m.user_id, 'Exam scheduled', '"NEET UG Full Mock 1" opens in two days.', 'exam', e4, 'exam', 'my-exams.html', now() - interval '6 hours'
  from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_neetb and u.role = 'student' and e4 is not null
    and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = e4);
end $$;

-- ===================== PART 3 – ATSS College data, staff notifications, audit history =====================
do $$
declare
  root uuid; atss uuid; siit uuid; sa uuid; ca uuid; ia uuid; apt uuid; qa uuid; u_ar uuid;
  c_pct uuid; c_si uuid; c_pl uuid; c_avg uuid; c_rat uuid; t_pct uuid; t_si uuid; t_pl uuid; t_avg uuid; t_rat uuid;
  f_atss uuid; b_atss uuid; e7 uuid; a5 uuid; act6 uuid; qs uuid[] := '{}'; i uuid; k int; n int; uid_ uuid; stu record; pk numeric[]; nm text; em text;
  bca_first text[] := array['Aakanksha','Atharv','Bhagyashree','Chetan','Diksha','Gayatri','Hemant','Kaveri','Lalit','Mansi','Nilesh','Omkar','Pradnya','Rahul',
                            'Sayali','Shantanu','Tejas','Vrushali','Yashwant','Rutika'];
  bca_last text[] := array['Wagh','Lokhande','Shirke','Nikam','Thorat','Salunkhe','More','Kadam','Sawant','Pawar','Bhosale','Mane','Gaikwad','Jagtap','Dhumal',
                           'Kale','Shelar','Pingale','Ghule','Borate'];
begin
  perform setseed(0.5531);
  select id into root from public.organizations where code = 'KDRT';
  select id into atss from public.organizations where code = 'ATSS';
  select id into siit from public.organizations where code = 'SIIT03';
  select id into sa from public.users where role = 'super_admin' order by created_at limit 1;
  select id into ca from public.users where role = 'college_admin' and organization_id = atss order by created_at limit 1;
  select id into ia from public.users where role = 'institute_admin' and organization_id = siit order by created_at limit 1;
  select id into f_atss from public.users where email = 'sneha.joshi@atsscollege.in';
  select id into b_atss from public.batches where organization_id = atss and (name = 'BCA Aptitude 2026' or code = 'BCA26') order by (name = 'BCA Aptitude 2026') desc limit 1;

  -- ---------- Aptitude exam type and syllabus ----------
  select id into apt from public.exam_categories where code = 'APTITUDE' or lower(trim(name)) in ('aptitude', 'aptitude & reasoning', 'aptitude and reasoning') order by (code = 'APTITUDE') desc nulls last limit 1;
  if apt is null then
    insert into public.exam_categories(name, code, description, icon, color, created_by)
    values ('Aptitude & Reasoning', 'APTITUDE', 'Quantitative aptitude and logical reasoning for campus placements', 'calculator', '#4F46E5', sa) returning id into apt;
  end if;
  update public.batches set exam_category_id = apt, start_date = coalesce(start_date, current_date - 35), end_date = coalesce(end_date, current_date + 150),
         description = 'BCA final year – quantitative aptitude for campus placements (Mon/Wed/Fri, 2:00–4:00 pm)' where id = b_atss;
  qa := pg_temp.subj(apt, 'Quantitative Aptitude', 1);
  u_ar := pg_temp.unit(qa, 'Arithmetic', 1);
  c_pct := pg_temp.chap(qa, u_ar, 'Percentages', 1, 20); t_pct := pg_temp.topic(c_pct, 'Percentage of a Number', 1);
  c_si := pg_temp.chap(qa, u_ar, 'Simple Interest', 2, 20); t_si := pg_temp.topic(c_si, 'Simple Interest Formula', 1);
  c_pl := pg_temp.chap(qa, u_ar, 'Profit and Loss', 3, 20); t_pl := pg_temp.topic(c_pl, 'Profit Percentage', 1);
  c_avg := pg_temp.chap(qa, u_ar, 'Averages', 4, 20); t_avg := pg_temp.topic(c_avg, 'Average of Numbers', 1);
  c_rat := pg_temp.chap(qa, u_ar, 'Ratio and Proportion', 5, 20); t_rat := pg_temp.topic(c_rat, 'Dividing in a Ratio', 1);

  -- ---------- 20 BCA students ----------
  for k in 1..20 loop
    nm := bca_first[k] || ' ' || bca_last[k]; em := lower(bca_first[k] || '.' || bca_last[k]) || '@atsscollege.in';
    uid_ := pg_temp.person(em, nm, 'student', atss, format('ATSS/BCA/26/%s', lpad(k::text, 3, '0')), '97650' || lpad((32100 + k)::text, 5, '0'), 'Student@123');
    perform pg_temp.member(b_atss, uid_, 'student');
  end loop;
  n := 0;
  for stu in select u.id from public.users u where u.organization_id = atss and u.role = 'student'
               and not exists (select 1 from public.activity_events e where e.user_id = u.id and e.event_type = 'login') order by u.roll_number loop
    n := n + 1;
    if n % 10 = 0 then
      insert into public.activity_events(user_id, event_type, created_at) values (stu.id, 'login', now() - interval '18 days');
      update public.users set last_login_at = now() - interval '18 days' where id = stu.id;
    else
      insert into public.activity_events(user_id, event_type, created_at)
      select stu.id, 'login', now() - make_interval(days => gs.dd, hours => (random() * 8)::int) from generate_series(0, 13) gs(dd) where random() < 0.6;
      update public.users set last_login_at = now() - make_interval(hours => 2 + n * 3) where id = stu.id;
    end if;
  end loop;
  update public.users set last_login_at = coalesce(last_login_at, now() - interval '5 hours') where id in (f_atss, ca);

  -- ---------- aptitude questions (answers worked out) ----------
  pk := array[10,250, 15,400, 25,320, 12,150];
  for k in 0..3 loop
    i := pg_temp.qn(qa, c_pct, t_pct, format('What is %s%% of %s?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])), 'easy', pk[2*k+1] * pk[2*k+2] / 100,
                    format('%s%% of %s = %s × %s ÷ 100 = %s.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] * pk[2*k+2] / 100)), f_atss);
    if k < 3 then qs := qs || i; end if;
  end loop;
  pk := array[5000,8,3, 2000,5,4, 12000,10,2];
  for k in 0..2 loop
    i := pg_temp.qrot(qa, c_si, t_si, format('What is the simple interest on ₹%s at %s%% per annum for %s years?', pg_temp.fmt(pk[3*k+1]), pg_temp.fmt(pk[3*k+2]), pg_temp.fmt(pk[3*k+3])), 'medium',
           '₹' || pg_temp.fmt(pk[3*k+1] * pk[3*k+2] * pk[3*k+3] / 100), '₹' || pg_temp.fmt(pk[3*k+1] * pk[3*k+2] / 100), '₹' || pg_temp.fmt(pk[3*k+1] * pk[3*k+2] * pk[3*k+3] / 50),
           '₹' || pg_temp.fmt(pk[3*k+1] + pk[3*k+1] * pk[3*k+2] * pk[3*k+3] / 100), k + 1,
           format('SI = P × R × T ÷ 100 = %s × %s × %s ÷ 100 = ₹%s.', pg_temp.fmt(pk[3*k+1]), pg_temp.fmt(pk[3*k+2]), pg_temp.fmt(pk[3*k+3]), pg_temp.fmt(pk[3*k+1] * pk[3*k+2] * pk[3*k+3] / 100)), f_atss);
    qs := qs || i;
  end loop;
  pk := array[400,500, 250,300, 1200,1500, 600,690];
  for k in 0..3 loop
    i := pg_temp.qn(qa, c_pl, t_pl, format('An article bought for ₹%s is sold for ₹%s. What is the profit percentage?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])), 'medium',
                    (pk[2*k+2] - pk[2*k+1]) * 100 / pk[2*k+1],
                    format('Profit = %s − %s = ₹%s; Profit %% = %s ÷ %s × 100 = %s%%.', pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2] - pk[2*k+1]),
                           pg_temp.fmt(pk[2*k+2] - pk[2*k+1]), pg_temp.fmt(pk[2*k+1]), pg_temp.fmt((pk[2*k+2] - pk[2*k+1]) * 100 / pk[2*k+1])), f_atss);
    if k < 3 then qs := qs || i; end if;
  end loop;
  qs := qs || pg_temp.qn(qa, c_avg, t_avg, 'What is the average of 12, 18, 24 and 30?', 'easy', 21, '(12 + 18 + 24 + 30) ÷ 4 = 84 ÷ 4 = 21.', f_atss);
  qs := qs || pg_temp.qn(qa, c_avg, t_avg, 'What is the average of 45, 55 and 65?', 'easy', 55, '(45 + 55 + 65) ÷ 3 = 165 ÷ 3 = 55.', f_atss);
  qs := qs || pg_temp.qn(qa, c_avg, t_avg, 'What is the average of the first five odd numbers after 5 (7, 9, 11, 13, 15)?', 'medium', 11, '(7 + 9 + 11 + 13 + 15) ÷ 5 = 55 ÷ 5 = 11.', f_atss);
  qs := qs || pg_temp.qm(qa, c_rat, t_rat, '₹1,200 is divided between A and B in the ratio 1 : 3. What is B''s share?', 'easy', '₹300', '₹400', '₹900', '₹800', 'C', 'B gets 3/4 × 1200 = ₹900.', f_atss);
  qs := qs || pg_temp.qm(qa, c_rat, t_rat, '₹1,500 is divided between A and B in the ratio 2 : 3. What is A''s share?', 'easy', '₹600', '₹900', '₹500', '₹750', 'A', 'A gets 2/5 × 1500 = ₹600.', f_atss);
  qs := qs || pg_temp.qm(qa, c_rat, t_rat, '₹2,400 is divided between P and Q in the ratio 3 : 5. What is Q''s share?', 'medium', '₹900', '₹1,440', '₹1,200', '₹1,500', 'D', 'Q gets 5/8 × 2400 = ₹1,500.', f_atss);

  -- the aptitude questions belong to ATSS (so Sujata's JEE / NEET faculty don't see them)
  update public.questions set organization_id = atss where subject_id = qa and organization_id is null;

  -- ---------- completed aptitude test with results ----------
  e7 := pg_temp.exam(atss, apt, 'BCA Aptitude Test 1 – Arithmetic', 'Percentages, simple interest, profit and loss, averages and ratios – 15 questions', 30, 'completed',
                     now() - interval '8 days', now() - interval '2 days', E'1. +4 for each correct answer, −1 for each wrong MCQ.\n2. Calculators are not allowed.', 40, true, false, f_atss);
  perform pg_temp.fill(e7, qs, f_atss, b_atss);
  perform pg_temp.simulate2(e7, array[b_atss]);

  -- ---------- assignment with submissions ----------
  select id into a5 from public.assignments where organization_id = atss and title = 'Aptitude Practice Sheet – Percentages & Interest';
  if a5 is null then
    insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
    values (atss, 'Aptitude Practice Sheet – Percentages & Interest', E'Solve the 20 questions on percentages, simple interest and compound interest.\nShow the short-cut method you used. Upload a PDF or photo.',
            'homework', 20, now() + interval '2 days', true, 1, 'published', f_atss, now() - interval '7 days', 'pdf,jpg,jpeg,png', now() - interval '7 days') returning id into a5;
    insert into public.assignment_batches(assignment_id, batch_id) values (a5, b_atss);
    n := 0;
    for stu in select u.id, u.last_login_at from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_atss and u.role = 'student' order by u.roll_number loop
      n := n + 1;
      continue when n % 7 = 0 or stu.last_login_at < now() - interval '15 days';
      insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content, marks_obtained, feedback, evaluated_by, evaluated_at)
      values (a5, stu.id, 1, now() - make_interval(days => 1 + n % 5, hours => n % 9), case when n % 3 = 0 then 'submitted' else 'evaluated' end,
              'All 20 questions solved; short-cuts shown for percentage change and simple interest.',
              case when n % 3 <> 0 then 11 + (n * 7) % 10 end,
              case when n % 3 <> 0 then (array['Good use of short-cuts.','Correct – show the formula once.','Well done, very quick methods.','Check Q14 (successive discounts).'])[1 + n % 4] end,
              case when n % 3 <> 0 then f_atss end, case when n % 3 <> 0 then now() - interval '10 hours' end);
    end loop;
  end if;

  -- ---------- activity, announcement, notifications for ATSS ----------
  select id into act6 from public.activities where organization_id = atss and title = 'Placement Aptitude Sprint – 20 Questions';
  if act6 is null then insert into public.activities(organization_id, title, activity_type, duration_minutes, start_time, end_time, description, points, is_active, created_by, created_at)
    values (atss, 'Placement Aptitude Sprint – 20 Questions', 'timed_test', 20, now() - interval '3 days', now() + interval '11 days',
            'Twenty mixed aptitude questions in twenty minutes – the format used in campus placement tests.', 15, true, f_atss, now() - interval '3 days') returning id into act6;
    insert into public.activity_events(user_id, activity_id, event_type, created_at, meta)
    select m.user_id, act6, 'practice_complete', now() - make_interval(days => (random() * 3)::int, hours => (random() * 6)::int), '{}'::jsonb
    from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_atss and u.role = 'student' and u.last_login_at > now() - interval '8 days' and random() < 0.65;
  end if;
  if not exists (select 1 from public.announcements where title = 'Campus placement drive – aptitude round') then
    insert into public.announcements(organization_id, title, body, target_type, target_org, priority, created_by, published_at)
    values (atss, 'Campus placement drive – aptitude round', E'The aptitude round of the campus placement drive is on the 5th of next month.\nPractise daily with the aptitude sprint and the weekly tests.', 'organization', atss, 'high', coalesce(ca, sa), now() - interval '4 days');
  end if;
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
  select m.user_id, 'New assignment', '"Aptitude Practice Sheet – Percentages & Interest" has been assigned to you.', 'assignment', a5, 'assignment', 'my-assignments.html', random() < 0.5, now() - interval '7 days'
  from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_atss and u.role = 'student'
    and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = a5);


  -- ---------- a live aptitude test (open now) ----------
  declare c_sp uuid; c_tw uuid; t_sp uuid; t_tw uuid; q2s uuid[] := '{}'; e8 uuid; begin
    c_sp := pg_temp.chap(qa, u_ar, 'Speed, Time and Distance', 6, 10); t_sp := pg_temp.topic(c_sp, 'Average Speed', 1);
    c_tw := pg_temp.chap(qa, u_ar, 'Time and Work', 7, 10); t_tw := pg_temp.topic(c_tw, 'Working Together', 1);
    pk := array[120,2, 150,3, 210,3.5];
    for k in 0..2 loop
      q2s := q2s || pg_temp.qn(qa, c_sp, t_sp, format('A bus covers %s km in %s hours. What is its average speed in km/h?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])), 'easy', pk[2*k+1] / pk[2*k+2],
                               format('Speed = distance ÷ time = %s ÷ %s = %s km/h.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] / pk[2*k+2])), f_atss);
    end loop;
    pk := array[10,15, 12,24, 20,30];
    for k in 0..2 loop
      q2s := q2s || pg_temp.qn(qa, c_tw, t_tw, format('A can finish a job in %s days and B in %s days. Working together, in how many days will they finish it?', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2])), 'medium',
                               pk[2*k+1] * pk[2*k+2] / (pk[2*k+1] + pk[2*k+2]),
                               format('Together = (%s × %s) ÷ (%s + %s) = %s days.', pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1]), pg_temp.fmt(pk[2*k+2]), pg_temp.fmt(pk[2*k+1] * pk[2*k+2] / (pk[2*k+1] + pk[2*k+2]))), f_atss);
    end loop;
    q2s := q2s || (select array_agg(id) from (select id from public.questions where question_text in ('What is 12% of 150?', 'An article bought for ₹600 is sold for ₹690. What is the profit percentage?')) z);
    e8 := pg_temp.exam(atss, apt, 'BCA Aptitude Test 2 – Speed, Time and Work', 'Speed, time and work, with two revision questions – 8 questions', 20, 'live',
                       now() - interval '6 hours', now() + interval '6 days', E'1. +4 for each correct answer.\n2. Type numerical answers as numbers only.', 40, false, true, f_atss);
    perform pg_temp.fill(e8, q2s, f_atss, b_atss);
    insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
    select m.user_id, 'New exam assigned', '"BCA Aptitude Test 2" is open now.', 'exam', e8, 'exam', 'my-exams.html', now() - interval '6 hours'
    from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = b_atss and u.role = 'student'
      and not exists (select 1 from public.notifications x where x.user_id = m.user_id and x.reference_id = e8);
  end;

  -- ---------- new assignments that are open now (so every student has work due) ----------
  declare b uuid[]; a uuid; r record; begin
    for r in select * from (values
        ('JEE', 'Mathematics Problem Set – Limits & Derivatives', E'Solve the 12 problems on limits and derivatives from the class sheet.\nWrite every step and box the final answer.', 'homework', 20, interval '6 days', 'sandeep.gore@sujatainstitute.in'),
        ('NEET', 'Physics Numericals – Laws of Motion', E'Solve the 10 numericals on Newton''s laws and friction.\nDraw a free-body diagram for each problem.', 'homework', 20, interval '5 days', 'rahul.deshmukh@sujatainstitute.in'),
        ('BCA', 'Reasoning Worksheet – Series & Coding', E'Complete the 25 number-series and coding–decoding questions.\nWrite the rule you found for each series.', 'homework', 25, interval '4 days', 'sneha.joshi@atsscollege.in')
      ) v(grp, title, dsc, typ, mx, due, author) loop
      b := case r.grp when 'JEE' then array(select id from public.batches where code in ('JEE27A', 'JEE27B'))
                      when 'NEET' then array(select id from public.batches where code in ('NEET27A', 'NEET27B'))
                      else array[b_atss] end;
      select id into a from public.assignments where title = r.title;
      if a is null then
        insert into public.assignments(organization_id, title, description, assignment_type, max_marks, deadline, allow_resubmit, max_resubmits, status, created_by, published_at, allowed_types, created_at)
        values (case when r.grp = 'BCA' then atss else siit end, r.title, r.dsc, r.typ, r.mx, now() + r.due, true, 2, 'published',
                (select id from public.users where email = r.author), now() - interval '1 day', 'pdf,jpg,jpeg,png,docx', now() - interval '1 day') returning id into a;
        insert into public.assignment_batches(assignment_id, batch_id) select a, x from unnest(b) x;
        -- a few early submissions
        insert into public.assignment_submissions(assignment_id, user_id, attempt_number, submitted_at, status, content)
        select a, z.user_id, 1, now() - make_interval(hours => (2 + (z.rn * 3) % 20)::int), 'submitted', 'Submitted early – all questions attempted.'
        from (select m.user_id, row_number() over (order by u.roll_number) rn from public.batch_members m join public.users u on u.id = m.user_id
              where m.batch_id = any(b) and u.role = 'student' and u.last_login_at > now() - interval '3 days') z where z.rn % 6 = 3;
        insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, created_at)
        select distinct m.user_id, 'New assignment', format('"%s" has been assigned to you.', r.title), 'assignment', a, 'assignment', 'my-assignments.html', now() - interval '1 day'
        from public.batch_members m join public.users u on u.id = m.user_id where m.batch_id = any(b) and u.role = 'student';
      end if;
    end loop;
  end;

  -- engagement "last seen" for ATSS students
  insert into public.engagement_status(user_id, status, last_activity_at, inactivity_days)
  select u.id, 'active', null, 0 from public.users u where u.organization_id = atss and u.role = 'student' on conflict (user_id) do nothing;
  update public.engagement_status es
     set last_activity_at = x.last_at, inactivity_days = floor(extract(epoch from now() - x.last_at) / 86400)::int,
         status = case when x.last_at < now() - interval '7 days' then 'inactive' else 'active' end
    from (select u.id, greatest(u.last_login_at, (select max(created_at) from public.activity_events e where e.user_id = u.id),
                                (select max(submitted_at) from public.assignment_submissions z where z.user_id = u.id)) last_at
            from public.users u where u.organization_id = atss and u.role = 'student') x
   where es.user_id = x.id and x.last_at is not null;

  -- ---------- notifications for admins and faculty ----------
  insert into public.notifications(user_id, title, body, type, action_url, is_read, created_at)
  select v.uid, v.title, v.body, v.typ, v.url, v.rd, now() - v.ago
  from (
    select ia uid, 'Weekly test results released' title, 'JEE Weekly Test 3 and NEET Weekly Test 2 results are now visible to students.' body, 'result' typ, 'results.html' url, false rd, interval '2 days' ago union all
    select ia, '76 new students added', 'Batch B students for JEE and NEET were added to Sujata Institute.', 'info', 'users.html', true, interval '33 days' union all
    select ia, 'Students need attention', 'Some students have not logged in for more than a week. Open Engagement to send reminders.', 'warning', 'engagement.html', false, interval '1 day' union all
    select ia, 'Assignment deadline passed', '"Chemistry Worksheet – Mole Concept & Stoichiometry" closed with late submissions.', 'assignment', 'assignments.html', false, interval '2 days' union all
    select ca, 'Aptitude test completed', '"BCA Aptitude Test 1 – Arithmetic" has finished. Results are ready.', 'result', 'results.html', false, interval '2 days' union all
    select ca, 'Partner institute activity', 'Sujata Institute ran two weekly tests for 100 students this week.', 'info', 'dashboard.html', true, interval '3 days' union all
    select ca, 'Campus placement drive', 'The aptitude round announcement has been published to all ATSS students.', 'info', 'announcements.html', true, interval '4 days' union all
    select sa, 'New organization admin', 'Tejas Navgire is the admin of Sujata Institute of Information And Technology.', 'info', 'organizations.html', true, interval '40 days' union all
    select sa, 'Platform summary', 'Two organizations are active this week with 120 students and 7 exams.', 'info', 'dashboard.html', false, interval '1 day' union all
    select sa, 'Security check', 'No locked accounts this week. All admins signed in successfully.', 'info', 'audit.html', false, interval '6 hours'
  ) v where v.uid is not null and not exists (select 1 from public.notifications x where x.user_id = v.uid and x.title = v.title);
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
  select a.created_by, 'New submissions to review', format('%s submission(s) for "%s" are waiting for evaluation.', count(*), a.title), 'assignment', a.id, 'assignment', 'assignments.html', false, now() - interval '5 hours'
  from public.assignments a join public.assignment_submissions z on z.assignment_id = a.id
  where z.status in ('submitted', 'late') and a.created_by is not null
    and not exists (select 1 from public.notifications x where x.user_id = a.created_by and x.reference_id = a.id and x.title = 'New submissions to review')
  group by a.id, a.created_by, a.title;
  insert into public.notifications(user_id, title, body, type, reference_id, reference_type, action_url, is_read, created_at)
  select e.created_by, 'Exam finished', format('"%s" has ended – %s students attempted it.', e.title, (select count(*) from public.results r where r.exam_id = e.id)), 'exam', e.id, 'exam', 'results.html?exam=' || e.id, random() < 0.4, e.end_time
  from public.exams e where e.status = 'completed' and e.created_by is not null
    and not exists (select 1 from public.notifications x where x.user_id = e.created_by and x.reference_id = e.id and x.title = 'Exam finished');

  -- ---------- audit history ----------
  if (select count(*) from public.audit_logs) < 20 then
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, ip_address, user_agent, created_at)
    select u.id, u.email, 'login', 'users', u.id::text, null, ('103.21.58.' || (10 + (row_number() over ()) % 200))::inet, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131',
           now() - make_interval(days => d.dd, hours => (d.dd * 3) % 10)
    from public.users u cross join generate_series(0, 6) d(dd) where u.role <> 'student';
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select e.created_by, (select email from public.users where id = e.created_by), 'create', 'exams', e.id::text, jsonb_build_object('title', e.title), e.created_at from public.exams e where e.created_by is not null;
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select e.created_by, (select email from public.users where id = e.created_by), 'exam_status', 'exams', e.id::text, jsonb_build_object('title', e.title, 'status', e.status), coalesce(e.published_at, e.created_at) + interval '1 hour'
    from public.exams e where e.created_by is not null;
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select a.created_by, (select email from public.users where id = a.created_by), 'create', 'assignments', a.id::text, jsonb_build_object('title', a.title), a.created_at from public.assignments a where a.created_by is not null;
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select b.created_by, (select email from public.users where id = b.created_by), 'create', 'batches', b.id::text, jsonb_build_object('name', b.name), b.created_at from public.batches b where b.created_by is not null;
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select coalesce(ia, sa), (select email from public.users where id = coalesce(ia, sa)), 'bulk_create', 'users', null, jsonb_build_object('students', 76, 'batches', array['JEE27B', 'NEET27B']), now() - interval '33 days';
    insert into public.audit_logs(user_id, actor_email, action, entity_type, entity_id, new_data, created_at)
    select coalesce(ca, sa), (select email from public.users where id = coalesce(ca, sa)), 'bulk_create', 'users', null, jsonb_build_object('students', 20, 'batch', 'BCA26'), now() - interval '35 days';
  end if;
end $$;

-- ===================== PART 4 – full student details (students table) =====================
do $$
declare
  r record; n int := 0; k int := 0; prev text := ''; fn text; ln text; female boolean; area int; cat text; base date; fee numeric; paid numeric;
  girls text[] := array['Isha','Sakshi','Tanvi','Neha','Riya','Ananya','Shreya','Pooja','Mrunal','Gauri','Prachi','Sanika','Aditi','Amruta','Anushka','Bhakti',
                        'Devika','Gargi','Janhavi','Ketaki','Manasi','Nidhi','Payal','Rachana','Rutuja','Samruddhi','Shravani','Swara','Tejaswini','Vaishnavi',
                        'Aishwarya','Apurva','Damini','Disha','Harshada','Jui','Kshitija','Madhura','Namrata','Pallavi','Rasika','Sampada','Shruti','Snehal',
                        'Supriya','Urvi','Vidya','Yashashri','Komal','Aakanksha','Bhagyashree','Diksha','Gayatri','Kaveri','Mansi','Pradnya','Sayali','Vrushali','Rutika'];
  fathers text[] := array['Suresh','Ramesh','Mahesh','Prakash','Vijay','Sanjay','Anil','Sunil','Rajesh','Dilip','Ashok','Santosh','Nitin','Ravindra','Vinod','Sachin','Deepak','Milind'];
  mothers text[] := array['Sunita','Anita','Sangeeta','Vandana','Manisha','Kavita','Swati','Jyoti','Rekha','Seema','Shubhangi','Archana','Vaishali','Meenal','Asha','Smita'];
  jobs text[] := array['Software engineer','Businessman','Bank officer','Teacher','Farmer','Government employee','Doctor','Shop owner','Civil engineer','Accountant','Police officer','Pharmacist'];
  areas text[] := array['Aundh','Baner','Pashan','Wakad','Kothrud','Pimple Saudagar','Shivajinagar','Hinjewadi','Balewadi','Bavdhan','Sangvi','Viman Nagar'];
  pins text[] := array['411007','411045','411008','411057','411038','411027','411005','411057','411045','411021','411027','411014'];
  roads text[] := array['Parihar Chowk','ITI Road','Sus Road','Datta Mandir Road','Karve Road','Kunal Icon Road','FC Road','Phase 1','Balewadi High Street','Chandni Chowk','Old Sangvi','Nagar Road'];
  socs text[] := array['Sai Shraddha Apartments','Shubham Residency','Ganga Heights','Kumar Parisar','Pristine Greens','Mantri Avenue','Rohan Mithila','Vision Gardens','Siddhivinayak Society','Shivam Park'];
  schools text[] := array['Abhinav Vidyalaya, Pune','Modern Junior College, Pune','D. A. V. Public School, Aundh','Kendriya Vidyalaya, Pashan','Vidya Valley School, Sus',
                          'New English School, Pune','St. Joseph''s High School, Pune','Jnana Prabodhini, Pune','Symbiosis School, Pune','Fergusson College Junior Wing, Pune'];
  bloods text[] := array['B+','O+','A+','O+','B+','AB+','A+','O-','B-','A-'];
begin
  perform setseed(0.6173);
  for r in select u.id, u.full_name, u.email, u.phone, u.created_at, o.code org_code, s.batch_id, b.code batch_code, s.admission_no
             from public.users u join public.students s on s.user_id = u.id left join public.organizations o on o.id = u.organization_id
             left join public.batches b on b.id = s.batch_id
            where u.role = 'student' order by o.code, u.roll_number loop
    n := n + 1;
    if r.org_code is distinct from prev then k := 0; prev := r.org_code; end if;
    k := k + 1;                                              -- running number inside each organization
    continue when r.admission_no is not null;                 -- details already filled (keep any changes you made)
    fn := split_part(r.full_name, ' ', 1); ln := split_part(r.full_name, ' ', 2);
    female := fn = any(girls); area := 1 + (n * 5) % 12;
    cat := (array['General','General','OBC','General','OBC','SC','General','EWS','OBC','ST'])[1 + n % 10];
    if r.org_code = 'ATSS' then
      base := date '2004-06-01'; fee := 45000;
    elsif r.batch_code like 'NEET%' then
      base := date '2008-07-01'; fee := 105000;
    else
      base := date '2008-07-01'; fee := 95000;
    end if;
    paid := case when n % 5 = 0 then 0 when n % 3 = 0 then round(fee * 0.5) else fee end;
    update public.students set
      admission_no      = case when r.org_code = 'ATSS' then format('ATSS/BCA/2023/%s', lpad(k::text, 4, '0')) else format('SIIT/2026/%s', lpad(k::text, 4, '0')) end,
      admission_date    = coalesce(admission_date, r.created_at::date),
      date_of_birth     = base + ((n * 37) % 420),
      gender            = case when female then 'female' else 'male' end,
      blood_group       = bloods[1 + (n * 3) % 10],
      category          = cat,
      nationality       = 'Indian',
      alt_phone         = '9' || lpad(((n * 7919) % 1000000000)::text, 9, '0'),
      address_line      = format('Flat %s, %s, %s, %s', 100 + (n * 13) % 800, socs[1 + n % 10], roads[area], areas[area]),
      city              = 'Pune',
      state             = 'Maharashtra',
      pincode           = pins[area],
      father_name       = fathers[1 + (n * 7) % 18] || ' ' || ln,
      father_phone      = '98' || lpad(((n * 104729) % 100000000)::text, 8, '0'),
      father_occupation = jobs[1 + (n * 5) % 12],
      mother_name       = mothers[1 + (n * 11) % 16] || ' ' || ln,
      mother_phone      = '97' || lpad(((n * 130363) % 100000000)::text, 8, '0'),
      guardian_email    = lower(fathers[1 + (n * 7) % 18] || '.' || ln || n) || '@gmail.com',
      school_name       = schools[1 + (n * 3) % 10],
      board             = (array['CBSE','Maharashtra State Board','CBSE','ICSE','Maharashtra State Board'])[1 + n % 5],
      class_10_percent  = round(68 + ((n * 17) % 29) + ((n % 4) * 0.25), 2),
      class_12_percent  = case when r.org_code = 'ATSS' then round(62 + ((n * 13) % 30) + ((n % 3) * 0.33), 2) end,
      passing_year      = case when r.org_code = 'ATSS' then 2023 else 2027 end,
      fee_total         = fee,
      fee_paid          = paid,
      fee_status        = case when paid >= fee then 'paid' when paid > 0 then 'partial' else 'pending' end,
      status            = case when (select last_login_at from public.users where id = r.id) < now() - interval '17 days' then 'on_hold' else 'active' end,
      notes             = case when n % 9 = 0 then 'Needs extra support in numerical problems – parents informed.'
                               when n % 7 = 0 then 'Scholarship candidate (merit).' end
    where user_id = r.id;
  end loop;
end $$;

select (select count(*) from public.users u join public.organizations o on o.id = u.organization_id where o.code = 'SIIT03' and u.role = 'student') as sujata_students,
       (select count(*) from public.users u join public.organizations o on o.id = u.organization_id where o.code = 'ATSS' and u.role = 'student') as atss_students,
       (select count(*) from public.students where admission_no is not null) as student_records, (select count(*) from public.batches) as batches, (select count(*) from public.questions) as questions, (select count(*) from public.exams) as exams,
       (select count(*) from public.results) as results, (select count(*) from public.assignment_submissions) as submissions,
       (select count(*) from public.notifications) as notifications, (select count(*) from public.activity_events) as activity_events;
