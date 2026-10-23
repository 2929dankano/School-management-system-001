# School Management System (SMS) — Fresh Start

A new starter project built with Next.js 14, TypeScript, and Supabase Auth.

## Current stage
- Responsive overview and login UI.
- Supabase browser and server clients using the public anon/publishable key.
- Email/password login flow.
- Protected `/dashboard` route and server-side profile lookup.
- Server sign-out route.
- Super Admin Schools page with school directory and a school-registration form.
- Principal student-registration/search, class-creation/list, attendance-recording/list, result entry/Principal approval, fee creation/payment updates, Principal teacher invitation, and parent invitations with multi-child linking connected to Supabase; database RLS remains the final access boundary.
- Initial school messaging and PTA/event reminder forms that save message/event and recipient records; automatic delivery is not enabled yet.
- Principal invitation form linked to an active school.
- `supabase/functions/create-principal/index.ts` contains the protected Edge Function used to create and link Principal accounts; the function has been deployed to the connected Supabase project.

## Setup
1. Use Node.js 20 or later.
2. Copy `.env.example` to `.env.local`.
3. Add your Supabase project URL and anon/publishable key.
4. Do not run `supabase/migrations/001_initial_schema.sql` against the existing SCHOOL MANAGEMENT SYSTEM Supabase project. The live database schema was created by separate migrations and is not identical to this starter SQL.
5. Run `npm install`, then `npm run dev`.

## Important security notes
- This starter does not include or need a service-role key.
- Never put a service-role key in `NEXT_PUBLIC_*` variables or browser code.
- The SQL migration is a starting draft and must be reviewed/tested against a new, empty Supabase project before use. Do not run it in a database containing existing data.
- Principal invitation flow is coded and the Edge Function is deployed, but end-to-end invitation email delivery and profile creation have not yet been tested with a real invitation. Auth email configuration must be checked before production use. Full per-role permissions, parent-child linking, and runtime security testing are not complete yet.
- A production Next.js build has not been verified in this environment because dependencies could not be installed within the available network/time limit.
- Do not enter real credentials until Supabase is configured and the app has been deployed/tested in a trusted environment.


## Live database update (2026-10-20)
The live Supabase project has migration `sms_teacher_scope_and_profile_guard` applied. Its source is in `supabase/migrations/20261020132949_sms_teacher_scope_and_profile_guard.sql`. This update restricts teacher student/attendance/results access to the class assigned to that teacher and prevents non-Super-Admins from changing profile roles or school assignments. Do not rerun the original starter migration against the live project.

## Dashboard update (2026-10-20)
- The role-specific dashboard summary now requests live counts from Supabase rather than displaying hard-coded demo statistics.
- Counts are queried through the signed-in user's Supabase session and therefore depend on the current Row Level Security policies.
- A `—` is shown when an individual count query fails; zero means the query succeeded and no matching rows were visible.
- The module pages remain foundations/placeholders and must not be considered finished CRUD workflows.
- `npm install` and a production build were attempted during verification but dependency installation timed out in this environment. TypeScript/TSX syntax transpilation passed for all 16 source files; this is not a substitute for a full type-check or production build.

## Feature ownership and completion checklist
See [`docs/FEATURE-ROLE-MATRIX.md`](docs/FEATURE-ROLE-MATRIX.md) for the role-by-role responsibilities, all planned workflows, and acceptance/security tests required before declaring the SMS project complete. It also records which parts are implemented, partial, or not yet finished.


## Additional live database changes (2026-10-20)
- Applied additive migrations for messaging/events/audit storage, recipient RLS scope, delivery-state protection, attendance uniqueness, result approval/parent visibility, and same-school class-teacher assignment.
- Added school-scoped uniqueness indexes for student numbers, staff numbers, and class names per academic year.
- Added `school_messages`, `school_message_recipients`, `school_events`, `school_event_recipients`, and `audit_logs`, with RLS enabled. Added `create-teacher` and `create-parent` Edge Functions; both are deployed and active. Neither invitation flow has been invoked end-to-end. Recipient policies check school membership.
- The forms currently save records and recipient status as pending. Email/SMS delivery, scheduled dispatch, and automatic audit logging are not implemented/tested; do not treat these as complete notification or audit features.
- The student/class workflows have not yet been tested in a real browser using separate accounts.

## Subject management update (2026-10-20)
- Added `subjects` and `class_subjects` tables to the connected Supabase project, with RLS enabled.
- Principals can create, edit, deactivate/reactivate subjects, assign subjects to classes and active same-school teachers, and remove assignments from the Classes & Subjects workspace.
- Teachers can read subjects and assignments allowed by school/class scope; only Principals can change the subject catalogue or assignments.
- A live database validation test confirmed that cross-school subject assignment and duplicate class-subject assignment are rejected. Temporary test rows were rolled back; no school/test data was retained.
- Teacher `staff_number` remains an identifier, not a login/access code. The requested one-time teacher access-code redemption and password setup flow is not implemented yet and must not be described as complete.
- Current verification: TypeScript/TSX syntax transpilation passed for 19 source files. Full type-check/build and browser tests remain blocked because app dependencies are not installed in this environment.
- Parent dashboard now renders all linked children as separate cards, with recent attendance, Principal-approved results, and fee balances. Database RLS remains the boundary that determines which child records can be returned; this UI has not yet been browser-tested with real parent accounts.
- Security hardening moved the `current_school_id()` and `current_user_role()` SECURITY DEFINER helpers into a non-exposed `private` schema. A signed-in-role SQL check confirmed the helper still returns the current account role; Supabase Security Advisor no longer reports these two callable public functions. One Auth warning remains: leaked-password protection is disabled and must be enabled in Supabase Auth settings before production.
