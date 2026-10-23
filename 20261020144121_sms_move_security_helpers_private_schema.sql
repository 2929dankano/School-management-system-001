create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
alter function public.current_school_id() set schema private;
alter function public.current_user_role() set schema private;
grant execute on function private.current_school_id() to authenticated;
grant execute on function private.current_user_role() to authenticated;
revoke execute on function private.current_school_id() from anon, public;
revoke execute on function private.current_user_role() from anon, public;
