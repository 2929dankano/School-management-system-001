create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  subject_code text not null check (char_length(trim(subject_code)) between 1 and 30),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name),
  unique (school_id, subject_code),
  unique (school_id, id)
);

create table if not exists public.class_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null,
  subject_id uuid not null,
  teacher_profile_id uuid,
  created_at timestamptz not null default now(),
  unique (school_id, class_id, subject_id),
  foreign key (school_id, class_id) references public.classes(school_id, id) on delete cascade,
  foreign key (school_id, subject_id) references public.subjects(school_id, id) on delete cascade,
  foreign key (teacher_profile_id) references public.profiles(id) on delete set null
);

create index if not exists class_subjects_teacher_idx on public.class_subjects (school_id, teacher_profile_id);
create index if not exists class_subjects_class_idx on public.class_subjects (school_id, class_id);

alter table public.subjects enable row level security;
alter table public.class_subjects enable row level security;

create policy subjects_select_school_staff on public.subjects for select to authenticated
using (school_id = (select public.current_school_id()) and (select public.current_user_role()) in ('principal','teacher'));
create policy subjects_principal_insert on public.subjects for insert to authenticated
with check (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');
create policy subjects_principal_update on public.subjects for update to authenticated
using (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal')
with check (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');
create policy subjects_principal_delete on public.subjects for delete to authenticated
using (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');

create policy class_subjects_select_school_staff on public.class_subjects for select to authenticated
using (school_id = (select public.current_school_id()) and (
  (select public.current_user_role()) = 'principal'
  or teacher_profile_id = (select auth.uid())
  or exists (select 1 from public.classes c where c.school_id = class_subjects.school_id and c.id = class_subjects.class_id and c.class_teacher_id = (select auth.uid()))
));
create policy class_subjects_principal_insert on public.class_subjects for insert to authenticated
with check (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');
create policy class_subjects_principal_update on public.class_subjects for update to authenticated
using (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal')
with check (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');
create policy class_subjects_principal_delete on public.class_subjects for delete to authenticated
using (school_id = (select public.current_school_id()) and (select public.current_user_role()) = 'principal');

create or replace function public.validate_class_subject_assignment()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
    raise exception 'Class must belong to the same school.';
  end if;
  if not exists (select 1 from public.subjects s where s.id = new.subject_id and s.school_id = new.school_id and s.is_active = true) then
    raise exception 'Subject must be active and belong to the same school.';
  end if;
  if new.teacher_profile_id is not null and not exists (
    select 1 from public.profiles p join public.teachers t on t.profile_id = p.id and t.school_id = p.school_id
    where p.id = new.teacher_profile_id and p.school_id = new.school_id and p.role = 'teacher' and p.is_active = true and t.employment_status = 'active'
  ) then raise exception 'Assigned teacher must be active and belong to the same school.'; end if;
  return new;
end; $$;
create trigger class_subject_assignment_school_guard before insert or update on public.class_subjects
for each row execute function public.validate_class_subject_assignment();

-- Added during development and removed in a later migration; retained here to match live history.
create table if not exists public.teacher_activation_codes (
  id uuid primary key default gen_random_uuid(),
  teacher_profile_id uuid not null references public.profiles(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.teacher_activation_codes enable row level security;
revoke all on public.teacher_activation_codes from anon, authenticated;
