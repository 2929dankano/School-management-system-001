-- Keep recipient SELECT policies independent of the parent message/event tables to avoid recursive RLS evaluation.
drop policy if exists school_message_recipients_select on public.school_message_recipients;
create policy school_message_recipients_select on public.school_message_recipients for select to authenticated using (
 recipient_profile_id=(select auth.uid()) or public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal')
);
drop policy if exists school_event_recipients_select on public.school_event_recipients;
create policy school_event_recipients_select on public.school_event_recipients for select to authenticated using (
 recipient_profile_id=(select auth.uid()) or public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal')
);
