-- Ensure a class cannot be assigned to a teacher from another school or to an inactive/non-teacher account.
create or replace function public.validate_class_teacher_school() returns trigger language plpgsql set search_path = '' as $$
declare teacher_school uuid; declare teacher_role text; declare teacher_active boolean;
begin
 if new.class_teacher_id is null then return new; end if;
 select p.school_id,p.role,p.is_active into teacher_school,teacher_role,teacher_active from public.profiles p where p.id=new.class_teacher_id;
 if teacher_school is distinct from new.school_id or teacher_role is distinct from 'teacher' or teacher_active is distinct from true then
  raise exception 'Class teacher must be an active teacher in the same school';
 end if;
 return new;
end;
$$;
drop trigger if exists classes_validate_teacher_school on public.classes;
create trigger classes_validate_teacher_school before insert or update of class_teacher_id,school_id on public.classes for each row execute function public.validate_class_teacher_school();
