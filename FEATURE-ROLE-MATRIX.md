# SMS Feature and Role Responsibility Matrix

This is the acceptance checklist for the School Management System. A feature is **not complete** merely because its menu or page exists. It is complete only after the UI, server-side authorization, database/RLS policies, and tests all work together.

## 1. Role responsibilities

| Feature / duty | Super Admin | Principal | Teacher | Parent | Acceptance rule |
|---|---|---|---|---|---|
| Create and manage schools | Full platform access | Own school only: view school details | No | No | A user cannot read or change another school's records. |
| Create/invite Principal accounts | Yes; assign to an active school | No | No | No | Principal profile is linked to exactly the authorized school; invitation and first login are tested. |
| Manage teachers | Platform support only when explicitly authorized | Add/edit/deactivate teachers in own school; issue unique teacher code | View own profile; cannot assign roles or school | No | Teacher cannot self-promote or change school/role. |
| Teacher first-time access | No routine access to teacher credentials | Issue/reissue teacher code | Redeem code, verify identity and set own password | No | Codes are unique, expire or become unusable after redemption, and are never treated as a role-selection substitute. |
| Manage students | Platform support only when explicitly authorized | Register/search/update students in own school; system creates unique student number | View only students in assigned classes | View only linked children | Student numbers are unique; access is scoped by school/class/parent-child link. |
| Classes and subjects | Platform oversight only | Create classes, assign teachers and subjects | View assigned classes/subjects | View only information necessary for linked children | Teachers cannot access unassigned classes. |
| Attendance | No routine school-record editing | View/manage school attendance | Mark and view attendance only for assigned classes | View attendance for linked children | Server/database checks enforce class and child scope. |
| Exams and results | No routine result editing | Manage exam setup and school results; authorized corrections | Enter/update results only for assigned classes and permitted periods | View results for linked children; cannot edit | Result changes are authorized and audited; parents/teachers cannot alter protected school settings. |
| Fees and payments | Platform oversight only; no automatic access to school finance records | Set/record/verify fees and payments for own school | No fee/result override privileges by default | View own children's fee balances/receipts and payment status | Only authorized Principal/finance permissions can change financial records; parent sees only linked children. |
| Messages | Platform announcements only if explicitly implemented | Message all school users or selected teachers/recipients | Send/receive permitted school messages | Receive school/child-related messages; reply only if enabled | Recipient selection and school boundaries are enforced on the server. |
| PTA/events/reminders | Platform-level only if explicitly implemented | Create reminder/event, choose date/time and parent recipients | View relevant notices | Receive reminders for their linked children | A reminder such as “PTA 12/04/2027” is stored with date, recipients, delivery status, and timezone rules; sending is tested. |
| Parent-child linking | No routine linking without authorized workflow | Register/link a parent to one or more students | No | View each linked child using the authorized parent account | One parent can access multiple linked children; a parent cannot guess a code to access an unrelated child. |
| Reports/search | Platform reports only within authorized platform scope | Search students and view school-wide reports | Reports limited to assigned classes | Reports limited to linked children | Search and exports obey the same permissions as on-screen records. |
| Account/profile | Manage platform roles and school assignment | Manage own profile and authorized school accounts | Manage own permitted profile/password | Manage own permitted profile/password | No non-Super-Admin can change their role or school assignment. |
| Audit/security | Review platform security events where available | Review school-level audit records where available | No access to restricted audit records | No access to restricted audit records | Sensitive edits record actor, action, record, and timestamp. |

## 2. Required screens and workflows

- Login, sign-out, account recovery, active-account checks, and role-based dashboard/navigation.
- Super Admin: school directory/create school, Principal invitation, platform overview, and any subscription/report/settings screen only if those are confirmed project requirements.
- Principal: school overview, student register/search, teacher register/invitation, class/subject setup, attendance, exams/results, fees/payments, messages, PTA/events/reminders, and school reports.
- Teacher: assigned classes, class roster, attendance entry, permitted results entry, and permitted messages.
- Parent: linked-children selector, each child's attendance/results/fees, and school messages/reminders.
- Responsive layouts for phone and computer.

## 3. Security and acceptance tests required before calling the project complete

1. Sign in as each of the four roles using separate test accounts and verify the correct dashboard and navigation.
2. Attempt direct URL access to every module with each role; forbidden pages/actions must be denied server-side, not merely hidden from the menu.
3. Verify two schools cannot read or change each other's students, teachers, classes, attendance, results, fees, messages, or reminders.
4. Verify a teacher cannot access an unassigned class or change their role/school, fee records, or protected school settings.
5. Verify a parent cannot access another family's child by changing a URL, ID, or student code, and can switch among all of their own linked children.
6. Verify unique student and teacher codes, first-use redemption, invalid/used code rejection, and password setup.
7. Verify Principal can search students, message all or selected recipients, and schedule PTA reminders for selected parents; confirm actual delivery status rather than only a saved form.
8. Verify results and fees are editable only by authorized roles; record/audit sensitive changes.
9. Run database/RLS tests, lint/type-check, a production build, and phone/desktop browser tests. Resolve all critical/high security findings or document and approve remaining risks.
10. Test account recovery and invitation emails with the configured Supabase email provider before production.

## 4. Current implementation status (verified as of 2026-10-20, latest working session)

- **Present in code:** login flow, protected dashboard shell, role-specific navigation, Super Admin school page/form, Principal invitation form, deployed `create-principal` Edge Function, role-specific dashboard count queries, student registration/search UI, class creation/list UI, attendance recording/list UI, staff message form, PTA/event reminder form, and Principal teacher-invitation form with a unique staff number, and parent invitation/child-link form.
- **Partial / not end-to-end tested:** school creation and Principal invitation; invitation email delivery and profile creation have not been exercised with a real test account. Dashboard live counts, student/class/attendance forms, message recipient selection, and reminder forms have source code but have not been verified in a running browser with separate role accounts.
- **Not finished:** teacher first-time access-code redemption (teacher invitation/staff number is only an identifier; code-based password setup is not complete), automated browser tests of subject and parent workflows with separate school-role accounts, exam setup beyond subject/term/year result entry, full fee/payment workflow, parent/teacher invitation email delivery tests, delivery of messages/reminders (email/SMS provider and scheduler), real audit event capture/UI, reports, and the full role-by-role automated/manual test suite. Student/class/attendance/result-entry and Principal result-approval UI now have initial database-backed workflows. Parent result visibility is restricted to approved rows at the database level; edit/deactivate handling and end-to-end tests remain.
- **Database update:** additive migrations are applied to live Supabase for school-scoped unique student/staff codes, messaging, event/reminder recipient records, audit log storage, subject catalogue and class-subject assignments, and RLS policies. Live table listing confirms `subjects` and `class_subjects` exist with RLS enabled. A rolled-back SQL test confirmed cross-school and duplicate subject assignments are blocked. No real school, parent, teacher, or student test data was created.

- **Build/runtime:** TypeScript/TSX syntax transpilation passed for 19 files, but dependency installation has not succeeded in this environment; a full TypeScript check, production build, and browser/device test have not passed yet.

Do not mark any item complete until its acceptance rule and relevant tests pass against the live app and database.
