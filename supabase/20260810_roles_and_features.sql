-- PlottingBazaar CRM: roles expansion (admin/manager/sales/telecaller)
-- + lead purpose & budget fields + role-scoped delete permissions.
-- Run once in Supabase SQL Editor (after 20260809_professional_features.sql).

-- ============================================================
-- 1. FOUR ROLES — widen the allowed values on profiles.role.
--    Manager is treated exactly like Admin everywhere below (full
--    access, including managing users). Telecaller is treated like
--    Sales (assigned-only access) EXCEPT it cannot delete records.
-- ============================================================
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin', 'manager', 'sales', 'telecaller'));

-- ============================================================
-- 2. LEAD PURPOSE & BUDGET
-- ============================================================
alter table public.leads add column if not exists purpose text;
alter table public.leads add column if not exists budget numeric;

-- ============================================================
-- 3. WIDEN EVERY "ADMIN-ONLY" POLICY TO "ADMIN OR MANAGER"
-- ============================================================

-- profiles: role changes (Manage Users screen)
drop policy if exists "Admins manage profiles" on public.profiles;
create policy "Admins manage profiles" on public.profiles
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- leads
drop policy if exists "Admins manage all leads" on public.leads;
create policy "Admins manage all leads" on public.leads
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- call_logs
drop policy if exists "Admins manage all call logs" on public.call_logs;
create policy "Admins manage all call logs" on public.call_logs
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- lead_feedback
drop policy if exists "Admins manage all feedback" on public.lead_feedback;
create policy "Admins manage all feedback" on public.lead_feedback
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- activity_log
drop policy if exists "Admins read all activity" on public.activity_log;
create policy "Admins read all activity" on public.activity_log
for select to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- customers
drop policy if exists "Admins manage all customers" on public.customers;
create policy "Admins manage all customers" on public.customers
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- bookings
drop policy if exists "Admins manage all bookings" on public.bookings;
create policy "Admins manage all bookings" on public.bookings
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- plots
drop policy if exists "Admins write plots" on public.plots;
create policy "Admins write plots" on public.plots
for insert to authenticated
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

drop policy if exists "Admins update plots" on public.plots;
create policy "Admins update plots" on public.plots
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

drop policy if exists "Admins delete plots" on public.plots;
create policy "Admins delete plots" on public.plots
for delete to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- sites
drop policy if exists "Admins write sites" on public.sites;
create policy "Admins write sites" on public.sites
for insert to authenticated
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

drop policy if exists "Admins update sites" on public.sites;
create policy "Admins update sites" on public.sites
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

drop policy if exists "Admins delete sites" on public.sites;
create policy "Admins delete sites" on public.sites
for delete to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- role-escalation guard trigger: managers may also change roles now.
create or replace function public.prevent_role_self_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if not exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'manager')
    ) then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

-- ============================================================
-- 4. DELETE PERMISSIONS — Sales can delete their own assigned leads/
--    customers; Telecallers cannot delete anything (view + update only,
--    already covered by the existing assigned-only select/update
--    policies). Admin/Manager already covered by the "for all" policies
--    above.
-- ============================================================
drop policy if exists "Sales delete assigned leads" on public.leads;
create policy "Sales delete assigned leads" on public.leads
for delete to authenticated
using (
  assigned_to = auth.uid()
  and (select role from public.profiles where id = auth.uid()) = 'sales'
);

drop policy if exists "Sales delete assigned customers" on public.customers;
create policy "Sales delete assigned customers" on public.customers
for delete to authenticated
using (
  assigned_to = auth.uid()
  and (select role from public.profiles where id = auth.uid()) = 'sales'
);
