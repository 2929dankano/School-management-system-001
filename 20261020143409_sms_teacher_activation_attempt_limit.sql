alter table public.teacher_activation_codes add column if not exists failed_attempts integer not null default 0 check (failed_attempts >= 0 and failed_attempts <= 5);
