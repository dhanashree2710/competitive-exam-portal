-- SAFETY CHECK: shows any column in the undo list that holds real, varied data.
-- Columns added by ExamPortal only contain one repeated default value (or nothing).
create temp table if not exists undo_check(tbl text, col text, different_values bigint, sample text);
truncate undo_check;
do $$
declare r record; n bigint; smp text;
begin
  for r in select * from (values
    ('announcements','organization_id'),
    ('announcements','target_type'),
    ('announcements','target_ids'),
    ('announcements','published_at'),
    ('announcements','expires_at'),
    ('announcements','priority'),
    ('announcements','target_org'),
    ('announcements','target_batch'),
    ('announcements','target_role'),
    ('assignment_submissions','user_id'),
    ('assignment_submissions','attempt_number'),
    ('assignment_submissions','status'),
    ('assignment_submissions','marks_obtained'),
    ('assignment_submissions','created_at'),
    ('assignment_submissions','updated_at'),
    ('assignment_submissions','content'),
    ('assignment_submissions','link_url'),
    ('assignments','organization_id'),
    ('assignments','description'),
    ('assignments','assignment_type'),
    ('assignments','allow_resubmit'),
    ('assignments','max_resubmits'),
    ('assignments','status'),
    ('assignments','created_by'),
    ('assignments','published_at'),
    ('assignments','settings'),
    ('assignments','updated_at'),
    ('assignments','allowed_types'),
    ('assignments','attachment_path'),
    ('audit_logs','user_agent'),
    ('audit_logs','actor_email'),
    ('exams','organization_id'),
    ('exams','exam_category_id'),
    ('exams','title'),
    ('exams','description'),
    ('exams','total_marks'),
    ('exams','duration_minutes'),
    ('exams','total_questions'),
    ('exams','attempt_limit'),
    ('exams','shuffle_questions'),
    ('exams','shuffle_options'),
    ('exams','show_result_immediately'),
    ('exams','negative_marking'),
    ('exams','status'),
    ('exams','start_time'),
    ('exams','end_time'),
    ('exams','created_by'),
    ('exams','published_by'),
    ('exams','published_at'),
    ('exams','settings'),
    ('exams','updated_at'),
    ('exams','instructions'),
    ('exams','pass_percentage'),
    ('exams','blueprint'),
    ('subjects','exam_category_id'),
    ('subjects','order_index'),
    ('subjects','is_active'),
    ('users','password_hash'),
    ('users','role'),
    ('users','organization_id'),
    ('users','last_login_at'),
    ('users','metadata'),
    ('users','roll_number'),
    ('users','avatar_url'),
    ('users','failed_logins'),
    ('users','locked_until')
  ) v(t, c) loop
    if exists(select 1 from information_schema.columns where table_schema = 'public' and table_name = r.t and column_name = r.c) then
      execute format('select count(distinct %I::text), min(%I::text) from public.%I', r.c, r.c, r.t) into n, smp;
      insert into undo_check values (r.t, r.c, n, left(smp, 60));
    end if;
  end loop;
end $$;
select case when count(*) filter (where different_values > 1) = 0
            then 'SAFE: none of the 66 columns holds real data – go ahead with the undo'
            else 'CHECK: the columns listed below hold varied data – send me this result before undoing' end as verdict
from undo_check;
select tbl, col, different_values, sample from undo_check where different_values > 1 order by 1, 2;
