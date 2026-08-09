-- PlottingBazaar CRM: "Forgot password" without email.
--
-- WHY NOT SUPABASE'S BUILT-IN EMAIL RESET:
-- Employee accounts in this project are created by an admin from
-- "Manage users" with whatever email string is convenient (not
-- necessarily a real, checked inbox), so Supabase's normal
-- resetPasswordForEmail() link would go nowhere for most users. Instead,
-- a user who forgot their password submits a request here (no login
-- required), and an admin/manager reviews it in the app and sets the new
-- password directly using the existing admin-users Edge Function --
-- admin approval is the final step, not an email link.
--
-- Run once in the Supabase SQL editor (or `supabase db push`).

create table if not exists public.password_reset_requests (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'resolved', 'dismissed')),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null
);

alter table public.password_reset_requests enable row level security;

-- Submitted from the login screen, before the user has a session --
-- anyone (anon or already-signed-in) can create a pending request. The
-- check clause stops a caller from inserting a row that's already
-- marked resolved/dismissed or pre-filled with a resolver.
drop policy if exists "Anyone can submit a reset request" on public.password_reset_requests;
create policy "Anyone can submit a reset request" on public.password_reset_requests
for insert to anon, authenticated
with check (
  status = 'pending'
  and resolved_at is null
  and resolved_by is null
);

-- Only admins/managers can see the queue of requests.
drop policy if exists "Admins view reset requests" on public.password_reset_requests;
create policy "Admins view reset requests" on public.password_reset_requests
for select to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));

-- Only admins/managers can resolve/dismiss a request.
drop policy if exists "Admins resolve reset requests" on public.password_reset_requests;
create policy "Admins resolve reset requests" on public.password_reset_requests
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'))
with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'manager'));
