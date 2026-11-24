-- =====================================================================
--  02_superadmin_password.sql – use if you can't sign in as Super Admin
--  1. Change the email and password below.  2. Run it in the SQL Editor.
--  Updates the existing account with that email, or creates a new Super Admin.
-- =====================================================================
do $$
declare
  v_email    text := 'admin@example.com';   -- <<< super admin email
  v_password text := 'Admin@12345';         -- <<< new password (8+ chars, letters + numbers)
  v_name     text := 'Super Admin';
begin
  if exists (select 1 from public.users where lower(email) = lower(v_email)) then
    update public.users set password_hash = extensions.crypt(v_password, extensions.gen_salt('bf', 10)),
           role = 'super_admin', is_active = true, failed_logins = 0, locked_until = null, updated_at = now()
     where lower(email) = lower(v_email);
  else
    insert into public.users (email, full_name, role, is_active, password_hash)
    values (lower(v_email), v_name, 'super_admin', true, extensions.crypt(v_password, extensions.gen_salt('bf', 10)));
  end if;
end $$;
select id, email, role, is_active from public.users where role = 'super_admin';
