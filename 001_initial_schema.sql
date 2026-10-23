-- Initial SMS schema. Review and run only in a NEW, empty Supabase project.
-- Roles are assigned only through trusted administrative workflows.
create extension if not exists pgcrypto;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school_code text not null unique,
  address text,
  phone text,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  role text not null default 'parent' check (role in ('super_admin','principal','teacher','parent')),
  school_id uuid references public.schools(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  level text,
  academic_year text not null,
  class_teacher_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (school_id, name, academic_year),
  unique (school_id, id)
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_number text not null,
  first_name text not null,
  last_name text not null,
  middle_name text,
  date_of_birth date,
  gender text check (gender in ('male','female','other')),
  class_id uuid,
  enrollment_date date not null default current_date,
  status text not null default 'active' check (status in ('active','inactive','graduated','transferred')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, student_number),
  foreign key (school_id, class_id) references public.classes(school_id, id) on delete set null
);

create table if not exists public.parent_students (
  school_id uuid not null references public.schools(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  relationship text not null default 'parent',
  created_at timestamptz not null default now(),
  primary key (parent_id, student_id),
  foreign key (school_id, student_id) references public.students(school_id, id) on delete cascade
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  code text,
  created_at timestamptz not null default now(),
  unique (school_id, name),
  unique (school_id, id)
);

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null,
  subject_id uuid not null,
  created_at timestamptz not null default now(),
  foreign key (school_id, class_id) references public.classes(school_id, id) on delete cascade,
  foreign key (school_id, subject_id) references public.subjects(school_id, id) on delete cascade,
  unique (teacher_id, class_id, subject_id)
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null,
  class_id uuid not null,
  attendance_date date not null default current_date,
  status text not null check (status in ('present','absent','late','excused')),
  recorded_by uuid not null references public.profiles(id),
  note text,
  created_at timestamptz not null default now(),
  foreign key (school_id, student_id) references public.students(school_id, id) on delete cascade,
  foreign key (school_id, class_id) references public.classes(school_id, id) on delete cascade,
  unique (student_id, attendance_date)
);

create table if not exists public.examinations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  term text not null,
  academic_year text not null,
  starts_on date,
  ends_on date,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.results (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  examination_id uuid not null references public.examinations(id) on delete cascade,
  student_id uuid not null,
  subject_id uuid not null,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  grade text,
  remarks text,
  is_finalized boolean not null default false,
  entered_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (school_id, student_id) references public.students(school_id, id) on delete cascade,
  foreign key (school_id, subject_id) references public.subjects(school_id, id) on delete cascade,
  unique (examination_id, student_id, subject_id)
);

create table if not exists public.fee_structures (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  amount numeric(12,2) not null check (amount >= 0),
  academic_year text not null,
  term text not null,
  class_id uuid,
  due_date date,
  created_at timestamptz not null default now(),
  foreign key (school_id, class_id) references public.classes(school_id, id) on delete set null
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null,
  fee_structure_id uuid not null references public.fee_structures(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  payment_reference text,
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  paid_at timestamptz,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (school_id, student_id) references public.students(school_id, id) on delete cascade
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  body text not null,
  audience text not null default 'all' check (audience in ('all','teachers','parents')),
  published_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  subject text,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text,
  record_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_profiles_school_role on public.profiles(school_id, role);
create index if not exists idx_students_school_class on public.students(school_id, class_id);
create index if not exists idx_attendance_school_date on public.attendance(school_id, attendance_date);
create index if not exists idx_results_school_exam on public.results(school_id, examination_id);
create index if not exists idx_payments_school_status on public.payments(school_id, status);
create index if not exists idx_messages_recipient_created on public.messages(recipient_id, created_at desc);

create or replace function public.current_user_role()
returns text language sql stable security invoker
set search_path = ''
as $$ select role from public.profiles where id = (select auth.uid()) and is_active = true $$;

create or replace function public.current_user_school_id()
returns uuid language sql stable security invoker
set search_path = ''
as $$ select school_id from public.profiles where id = (select auth.uid()) and is_active = true $$;

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.parent_students enable row level security;
alter table public.subjects enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.attendance enable row level security;
alter table public.examinations enable row level security;
alter table public.results enable row level security;
alter table public.fee_structures enable row level security;
alter table public.payments enable row level security;
alter table public.announcements enable row level security;
alter table public.messages enable row level security;
alter table public.audit_logs enable row level security;

-- Policies deliberately use school scope and role checks. Account provisioning should be
-- implemented as a trusted server workflow after schema/security review.
create policy "profiles_read_self_or_school_admin" on public.profiles for select to authenticated
using (id = (select auth.uid()) or (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin')));
create policy "profiles_update_self_limited" on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()) and role = public.current_user_role() and school_id is not distinct from public.current_user_school_id());

create policy "schools_read_member" on public.schools for select to authenticated
using (id = public.current_user_school_id() or public.current_user_role() = 'super_admin');
create policy "schools_super_admin_all" on public.schools for all to authenticated
using (public.current_user_role() = 'super_admin')
with check (public.current_user_role() = 'super_admin');

create policy "classes_school_read" on public.classes for select to authenticated using (school_id = public.current_user_school_id() or public.current_user_role() = 'super_admin');
create policy "classes_admin_write" on public.classes for all to authenticated using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin')) with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "students_school_read" on public.students for select to authenticated
using (school_id = public.current_user_school_id() and (public.current_user_role() in ('principal','teacher') or exists (select 1 from public.parent_students ps where ps.student_id = students.id and ps.parent_id = (select auth.uid()))) or public.current_user_role() = 'super_admin');
create policy "students_admin_write" on public.students for all to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'))
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "parent_students_read_linked" on public.parent_students for select to authenticated
using (parent_id = (select auth.uid()) or (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin')));
create policy "parent_students_admin_write" on public.parent_students for all to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'))
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "subjects_school_read" on public.subjects for select to authenticated using (school_id = public.current_user_school_id() or public.current_user_role() = 'super_admin');
create policy "subjects_admin_write" on public.subjects for all to authenticated using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin')) with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "teacher_assignments_school_read" on public.teacher_assignments for select to authenticated
using (school_id = public.current_user_school_id() and (public.current_user_role() in ('principal','super_admin') or teacher_id = (select auth.uid())) or public.current_user_role() = 'super_admin');
create policy "teacher_assignments_admin_write" on public.teacher_assignments for all to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'))
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "attendance_school_read" on public.attendance for select to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','teacher') or public.current_user_role() = 'super_admin' or exists (select 1 from public.parent_students ps where ps.student_id = attendance.student_id and ps.parent_id = (select auth.uid())));
create policy "attendance_teacher_write" on public.attendance for insert to authenticated
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','teacher'));
create policy "attendance_admin_update" on public.attendance for update to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'))
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "examinations_school_read" on public.examinations for select to authenticated using (school_id = public.current_user_school_id() or public.current_user_role() = 'super_admin');
create policy "examinations_admin_write" on public.examinations for all to authenticated using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin')) with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "results_school_read" on public.results for select to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','teacher') or public.current_user_role() = 'super_admin' or exists (select 1 from public.parent_students ps where ps.student_id = results.student_id and ps.parent_id = (select auth.uid())));
create policy "results_teacher_insert" on public.results for insert to authenticated
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','teacher') and is_finalized = false);
create policy "results_admin_update" on public.results for update to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() = 'principal' and is_finalized = false)
with check (school_id = public.current_user_school_id() and public.current_user_role() = 'principal' and is_finalized = false);

create policy "fee_structures_school_read" on public.fee_structures for select to authenticated using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','parent') or public.current_user_role() = 'super_admin');
create policy "fee_structures_admin_write" on public.fee_structures for all to authenticated using (school_id = public.current_user_school_id() and public.current_user_role() = 'principal') with check (school_id = public.current_user_school_id() and public.current_user_role() = 'principal');

create policy "payments_parent_or_admin_read" on public.payments for select to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','parent') or public.current_user_role() = 'super_admin');
create policy "payments_admin_insert" on public.payments for insert to authenticated
with check (school_id = public.current_user_school_id() and public.current_user_role() = 'principal');
create policy "payments_no_update" on public.payments for update to authenticated using (false) with check (false);
create policy "payments_no_delete" on public.payments for delete to authenticated using (false);

create policy "announcements_school_read" on public.announcements for select to authenticated
using ((school_id = public.current_user_school_id() and (audience = 'all' or audience = public.current_user_role() || 's')) or public.current_user_role() = 'super_admin');
create policy "announcements_admin_write" on public.announcements for all to authenticated
using (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'))
with check (school_id = public.current_user_school_id() and public.current_user_role() in ('principal','super_admin'));

create policy "messages_sender_or_recipient_read" on public.messages for select to authenticated
using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));
create policy "messages_sender_insert" on public.messages for insert to authenticated
with check (sender_id = (select auth.uid()) and school_id = public.current_user_school_id());
create policy "messages_recipient_update" on public.messages for update to authenticated
using (recipient_id = (select auth.uid())) with check (recipient_id = (select auth.uid()));

create policy "audit_logs_school_admin_read" on public.audit_logs for select to authenticated
using ((school_id = public.current_user_school_id() and public.current_user_role() = 'principal') or public.current_user_role() = 'super_admin');
create policy "audit_logs_insert" on public.audit_logs for insert to authenticated
with check (actor_id = (select auth.uid()) and school_id = public.current_user_school_id());
create policy "audit_logs_no_update" on public.audit_logs for update to authenticated using (false) with check (false);
create policy "audit_logs_no_delete" on public.audit_logs for delete to authenticated using (false);
