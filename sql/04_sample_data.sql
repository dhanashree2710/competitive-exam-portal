-- =====================================================================
--  VidyaSetu – INSTITUTE DATA for Sujata Institute of Information And Technology (SIIT03)
--  Run AFTER sql/01_setup_all.sql (Supabase → SQL Editor → paste → Run).
--  Safe to run more than once: nothing is duplicated.
--
--  Keeps your own records: KDRT, ATSS College, Sujata Institute, Super Administrator,
--  Admin (ATSS) and Tejas Navgire (Sujata).  Removes the earlier "*.demo" sample accounts.
--
--  Adds for Sujata Institute:
--    • JEE Main & NEET UG syllabus (subject → unit → chapter → topic) and 43 approved questions
--    • 4 faculty, 24 students, 3 batches
--    • JEE Main Mock Test 1 & NEET Biology Practice Test – completed, with results, ranks & analysis
--    • JEE Main Mock Test 2 (live) and NEET UG Full Mock 1 (scheduled)
--    • assignments with graded submissions, activities, login history, announcements, notifications
--
--  Logins (please change the passwords later):
--    Faculty  : rahul.deshmukh@sujatainstitute.in, meera.apte@…, sandeep.gore@…, kavita.bhide@…   / Faculty@123
--    Students : aarav.patil@sujatainstitute.in … (24 students)                                       / Student@123
-- =====================================================================

do $$ begin
  if to_regproc('private.backend_version') is null then
    raise exception 'Please run sql/01_setup_all.sql first, then run this file again.';
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
  if not exists (select 1 from public.announcements where title = 'Welcome to VidyaSetu') then
    insert into public.announcements(organization_id, title, body, target_type, priority, created_by, published_at)
    values (root, 'Welcome to VidyaSetu', E'Your exams, assignments, results and study plan are now in one place.\nOpen "My Progress & Plan" to see your strengths, weak topics and a 7-day study plan.', 'all', 'normal', sa, now() - interval '20 days');
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

select (select count(*) from public.users where organization_id = (select id from public.organizations where code = 'SIIT03')) as sujata_users,
       (select count(*) from public.batches) as batches, (select count(*) from public.questions) as questions,
       (select count(*) from public.exams) as exams, (select count(*) from public.results) as results,
       (select count(*) from public.assignment_submissions) as submissions, (select count(*) from public.activity_events) as activity_events;
