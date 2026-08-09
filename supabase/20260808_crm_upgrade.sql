-- PlottingBazaar CRM upgrade: call logs, feedback history, admin live activity
-- feed, and assigned-only data scoping for customers & bookings.
-- Run once in Supabase SQL Editor (after 20260713_lead_assignment.sql).

create extension if not exists pgcrypto;

-- ============================================================
-- 1. CALL LOGS  (every call made against a lead is recorded here)
-- ============================================================
create table if not exists public.call_logs (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  called_by uuid not null references auth.users(id) on delete cascade,
  outcome text not null default 'Connected'
    check (outcome in ('Connected', 'Not Answered', 'Busy', 'Switched Off', 'Invalid Number', 'Call Back Later')),
  duration_seconds integer,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists call_logs_lead_id_idx on public.call_logs (lead_id);
create index if not exists call_logs_called_by_idx on public.call_logs (called_by);

alter table public.call_logs enable row level security;

drop policy if exists "Admins manage all call logs" on public.call_logs;
create policy "Admins manage all call logs" on public.call_logs
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Sales view call logs for their leads" on public.call_logs;
create policy "Sales view call logs for their leads" on public.call_logs
for select to authenticated
using (
  lead_id in (select id from public.leads where assigned_to = auth.uid())
);

drop policy if exists "Sales add call logs for their leads" on public.call_logs;
create policy "Sales add call logs for their leads" on public.call_logs
for insert to authenticated
with check (
  called_by = auth.uid()
  and lead_id in (select id from public.leads where assigned_to = auth.uid())
);

-- ============================================================
-- 2. LEAD FEEDBACK  (follow-up notes / remarks history per lead)
-- ============================================================
create table if not exists public.lead_feedback (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  feedback text not null,
  next_follow_up_date timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists lead_feedback_lead_id_idx on public.lead_feedback (lead_id);

alter table public.lead_feedback enable row level security;

drop policy if exists "Admins manage all feedback" on public.lead_feedback;
create policy "Admins manage all feedback" on public.lead_feedback
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Sales view feedback for their leads" on public.lead_feedback;
create policy "Sales view feedback for their leads" on public.lead_feedback
for select to authenticated
using (
  lead_id in (select id from public.leads where assigned_to = auth.uid())
);

drop policy if exists "Sales add feedback for their leads" on public.lead_feedback;
create policy "Sales add feedback for their leads" on public.lead_feedback
for insert to authenticated
with check (
  created_by = auth.uid()
  and lead_id in (select id from public.leads where assigned_to = auth.uid())
);

-- ============================================================
-- 3. ACTIVITY LOG  (admin real-time monitoring feed)
-- ============================================================
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  action_type text not null,
  lead_id uuid references public.leads(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  description text not null,
  created_at timestamptz not null default now()
);

create index if not exists activity_log_created_at_idx on public.activity_log (created_at desc);

alter table public.activity_log enable row level security;

drop policy if exists "Admins read all activity" on public.activity_log;
create policy "Admins read all activity" on public.activity_log
for select to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Users insert their own activity" on public.activity_log;
create policy "Users insert their own activity" on public.activity_log
for insert to authenticated
with check (actor_id = auth.uid());

drop policy if exists "Users read their own activity" on public.activity_log;
create policy "Users read their own activity" on public.activity_log
for select to authenticated
using (actor_id = auth.uid());

-- Enable realtime updates for the admin live monitoring screen.
alter publication supabase_realtime add table public.activity_log;

-- ============================================================
-- 4. CUSTOMERS — scope to assigned employee, same pattern as leads
-- ============================================================
alter table public.customers add column if not exists assigned_to uuid references auth.users(id) on delete set null;
create index if not exists customers_assigned_to_idx on public.customers (assigned_to);

alter table public.customers enable row level security;

drop policy if exists "Admins manage all customers" on public.customers;
create policy "Admins manage all customers" on public.customers
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Sales view assigned customers" on public.customers;
create policy "Sales view assigned customers" on public.customers
for select to authenticated
using (assigned_to = auth.uid());

drop policy if exists "Sales add customers assigned to self" on public.customers;
create policy "Sales add customers assigned to self" on public.customers
for insert to authenticated
with check (assigned_to = auth.uid());

drop policy if exists "Sales update assigned customers" on public.customers;
create policy "Sales update assigned customers" on public.customers
for update to authenticated
using (assigned_to = auth.uid())
with check (assigned_to = auth.uid());

-- ============================================================
-- 5. BOOKINGS — visible only for the customer's assigned employee
-- ============================================================
alter table public.bookings enable row level security;

drop policy if exists "Admins manage all bookings" on public.bookings;
create policy "Admins manage all bookings" on public.bookings
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Sales view bookings for their customers" on public.bookings;
create policy "Sales view bookings for their customers" on public.bookings
for select to authenticated
using (
  customer_id in (select id from public.customers where assigned_to = auth.uid())
);

drop policy if exists "Sales add bookings for their customers" on public.bookings;
create policy "Sales add bookings for their customers" on public.bookings
for insert to authenticated
with check (
  customer_id in (select id from public.customers where assigned_to = auth.uid())
);

-- ============================================================
-- 6. PLOTS & SITES — shared inventory: everyone can read (needed to
--    book against them), only admin can add/edit/delete.
-- ============================================================
alter table public.plots enable row level security;

drop policy if exists "Authenticated users read plots" on public.plots;
create policy "Authenticated users read plots" on public.plots
for select to authenticated using (true);

drop policy if exists "Admins write plots" on public.plots;
create policy "Admins write plots" on public.plots
for insert to authenticated
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Admins update plots" on public.plots;
create policy "Admins update plots" on public.plots
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Admins delete plots" on public.plots;
create policy "Admins delete plots" on public.plots
for delete to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin');

alter table public.sites enable row level security;

drop policy if exists "Authenticated users read sites" on public.sites;
create policy "Authenticated users read sites" on public.sites
for select to authenticated using (true);

drop policy if exists "Admins write sites" on public.sites;
create policy "Admins write sites" on public.sites
for insert to authenticated
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Admins update sites" on public.sites;
create policy "Admins update sites" on public.sites
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Admins delete sites" on public.sites;
create policy "Admins delete sites" on public.sites
for delete to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- ============================================================
-- Notes
-- ============================================================
-- * If your `plots` or `sites` tables use different column names than
--   assumed here, the policies above only reference role/auth.uid(),
--   so they will still apply without changes.
-- * Existing rows in `customers` will have assigned_to = NULL after this
--   migration. Ask an admin to open each customer once and assign it
--   (or bulk-update in the SQL editor), otherwise sales users won't see
--   customers created before this migration until they're assigned.
