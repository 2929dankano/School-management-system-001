-- Extend the approval guard so a teacher cannot bypass approval on INSERT either.
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
