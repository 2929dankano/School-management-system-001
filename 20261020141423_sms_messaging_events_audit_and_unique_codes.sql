-- Additive SMS feature foundation: uniqueness, school messaging, PTA/events and audit trail.
create unique index if not exists students_school_student_number_uidx on public.students (school_id, student_number);
create unique index if not exists teachers_school_staff_number_uidx on public.teachers (school_id, staff_number);
create unique index if not exists classes_school_name_year_uidx on public.classes (school_id, name, academic_year);

create table if not exists public.school_messages (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  sender_profile_id uuid not null references public.profiles(id), subject text not null check (char_length(trim(subject)) between 1 and 180),
  body text not null check (char_length(trim(body)) between 1 and 10000),
  audience_type text not null default 'selected' check (audience_type in ('all','teachers','parents','selected')),
  status text not null default 'draft' check (status in ('draft','scheduled','sent','failed')),
  scheduled_at timestamptz, sent_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (school_id,id)
);
create table if not exists public.school_message_recipients (
  school_id uuid not null references public.schools(id) on delete cascade, message_id uuid not null,
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  delivery_status text not null default 'pending' check (delivery_status in ('pending','sent','failed','read')),
  delivered_at timestamptz, error_message text, created_at timestamptz not null default now(), primary key (message_id,recipient_profile_id),
  foreign key (school_id,message_id) references public.school_messages(school_id,id) on delete cascade
);
create table if not exists public.school_events (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  created_by uuid not null references public.profiles(id), title text not null check (char_length(trim(title)) between 1 and 180), description text,
  event_type text not null default 'reminder' check (event_type in ('pta','meeting','holiday','exam','event','reminder')),
  event_at timestamptz not null, target_audience text not null default 'parents' check (target_audience in ('all','teachers','parents','selected')),
  status text not null default 'scheduled' check (status in ('draft','scheduled','sent','cancelled')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (school_id,id)
);
create table if not exists public.school_event_recipients (
  school_id uuid not null references public.schools(id) on delete cascade, event_id uuid not null,
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  delivery_status text not null default 'pending' check (delivery_status in ('pending','sent','failed','read')),
  delivered_at timestamptz, error_message text, created_at timestamptz not null default now(), primary key (event_id,recipient_profile_id),
  foreign key (school_id,event_id) references public.school_events(school_id,id) on delete cascade
);
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key, school_id uuid references public.schools(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null, action text not null, entity_type text not null,
  entity_id text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists school_messages_school_created_idx on public.school_messages (school_id,created_at desc);
create index if not exists school_message_recipients_recipient_idx on public.school_message_recipients (recipient_profile_id,delivery_status);
create index if not exists school_events_school_date_idx on public.school_events (school_id,event_at);
create index if not exists school_event_recipients_recipient_idx on public.school_event_recipients (recipient_profile_id,delivery_status);
create index if not exists audit_logs_school_created_idx on public.audit_logs (school_id,created_at desc);

alter table public.school_messages enable row level security;
alter table public.school_message_recipients enable row level security;
alter table public.school_events enable row level security;
alter table public.school_event_recipients enable row level security;
alter table public.audit_logs enable row level security;

create policy school_messages_select on public.school_messages for select to authenticated using (
 public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal') or sender_profile_id=(select auth.uid()) or
 exists(select 1 from public.school_message_recipients r where r.school_id=school_messages.school_id and r.message_id=school_messages.id and r.recipient_profile_id=(select auth.uid()))
);
create policy school_messages_insert on public.school_messages for insert to authenticated with check (
 school_id=public.current_school_id() and sender_profile_id=(select auth.uid()) and public.current_user_role() in ('principal','teacher')
);
create policy school_messages_update on public.school_messages for update to authenticated using (school_id=public.current_school_id() and public.current_user_role()='principal') with check (school_id=public.current_school_id() and public.current_user_role()='principal');
create policy school_messages_delete on public.school_messages for delete to authenticated using (school_id=public.current_school_id() and public.current_user_role()='principal');

create policy school_message_recipients_select on public.school_message_recipients for select to authenticated using (
 recipient_profile_id=(select auth.uid()) or public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal')
);
create policy school_message_recipients_insert on public.school_message_recipients for insert to authenticated with check (
 school_id=public.current_school_id() and exists(select 1 from public.school_messages m where m.id=school_message_recipients.message_id and m.school_id=school_message_recipients.school_id and (m.sender_profile_id=(select auth.uid()) or public.current_user_role()='principal'))
);
create policy school_message_recipients_update on public.school_message_recipients for update to authenticated using (recipient_profile_id=(select auth.uid()) or (school_id=public.current_school_id() and public.current_user_role()='principal')) with check (recipient_profile_id=(select auth.uid()) or (school_id=public.current_school_id() and public.current_user_role()='principal'));

create policy school_events_select on public.school_events for select to authenticated using (
 public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role() in ('principal','teacher')) or
 exists(select 1 from public.school_event_recipients r where r.school_id=school_events.school_id and r.event_id=school_events.id and r.recipient_profile_id=(select auth.uid()))
);
create policy school_events_insert on public.school_events for insert to authenticated with check (school_id=public.current_school_id() and created_by=(select auth.uid()) and public.current_user_role()='principal');
create policy school_events_update on public.school_events for update to authenticated using (school_id=public.current_school_id() and public.current_user_role()='principal') with check (school_id=public.current_school_id() and public.current_user_role()='principal');
create policy school_events_delete on public.school_events for delete to authenticated using (school_id=public.current_school_id() and public.current_user_role()='principal');

create policy school_event_recipients_select on public.school_event_recipients for select to authenticated using (
 recipient_profile_id=(select auth.uid()) or public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal')
);
create policy school_event_recipients_insert on public.school_event_recipients for insert to authenticated with check (
 school_id=public.current_school_id() and public.current_user_role()='principal' and exists(select 1 from public.school_events e where e.id=school_event_recipients.event_id and e.school_id=school_event_recipients.school_id and e.created_by=(select auth.uid()))
);
create policy school_event_recipients_update on public.school_event_recipients for update to authenticated using (recipient_profile_id=(select auth.uid()) or (school_id=public.current_school_id() and public.current_user_role()='principal')) with check (recipient_profile_id=(select auth.uid()) or (school_id=public.current_school_id() and public.current_user_role()='principal'));

create policy audit_logs_select on public.audit_logs for select to authenticated using (public.current_user_role()='super_admin' or (school_id=public.current_school_id() and public.current_user_role()='principal'));
create policy audit_logs_insert on public.audit_logs for insert to authenticated with check (actor_profile_id=(select auth.uid()) and (public.current_user_role()='super_admin' or school_id=public.current_school_id()));

grant select,insert,update,delete on public.school_messages to authenticated;
grant select,insert,update on public.school_message_recipients to authenticated;
grant select,insert,update,delete on public.school_events to authenticated;
grant select,insert,update on public.school_event_recipients to authenticated;
grant select,insert on public.audit_logs to authenticated;
