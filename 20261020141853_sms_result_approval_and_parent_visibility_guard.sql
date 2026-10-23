-- Parents may see only approved results; staff and parents remain limited by school/class/parent-child scope.
drop policy if exists results_select on public.results;
create policy results_select on public.results for select to authenticated using (
 public.current_user_role()='super_admin'
 or (school_id=public.current_school_id() and public.current_user_role()='principal')
 or (school_id=public.current_school_id() and public.current_user_role()='teacher' and exists(select 1 from public.students s join public.classes c on c.id=s.class_id and c.school_id=s.school_id where s.id=results.student_id and s.school_id=results.school_id and c.class_teacher_id=(select auth.uid())))
 or (approved_at is not null and exists(select 1 from public.parent_students ps join public.parents pa on pa.id=ps.parent_id and pa.school_id=ps.school_id where ps.student_id=results.student_id and ps.school_id=results.school_id and pa.profile_id=(select auth.uid())))
);
create or replace function public.prevent_result_self_approval() returns trigger language plpgsql set search_path = '' as $$
begin
 if public.current_user_role() not in ('principal','super_admin') then
  if tg_op='INSERT' then
   if new.approved_by is not null or new.approved_at is not null then raise exception 'Only a Principal can approve or publish student results'; end if;
  elsif new.approved_by is distinct from old.approved_by or new.approved_at is distinct from old.approved_at then
   raise exception 'Only a Principal can approve or publish student results';
  end if;
 end if;
 return new;
end;
$$;
drop trigger if exists results_prevent_self_approval on public.results;
create trigger results_prevent_self_approval before insert or update on public.results for each row execute function public.prevent_result_self_approval();
