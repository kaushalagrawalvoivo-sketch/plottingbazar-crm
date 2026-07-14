-- Run once in Supabase SQL Editor.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'sales' check (role in ('admin', 'sales')),
  created_at timestamptz not null default now()
);

alter table public.leads add column if not exists assigned_to uuid references auth.users(id) on delete set null;
create index if not exists leads_assigned_to_idx on public.leads (assigned_to);

alter table public.profiles enable row level security;
alter table public.leads enable row level security;

-- A user can see profiles for assigning/displaying leads; tighten this if needed.
drop policy if exists "Authenticated users can read profiles" on public.profiles;
create policy "Authenticated users can read profiles" on public.profiles
for select to authenticated using (true);

-- Administrators can change roles from the Manage users screen.
drop policy if exists "Admins manage profiles" on public.profiles;
create policy "Admins manage profiles" on public.profiles
for update to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Admins manage all leads" on public.leads;
create policy "Admins manage all leads" on public.leads
for all to authenticated
using ((select role from public.profiles where id = auth.uid()) = 'admin')
with check ((select role from public.profiles where id = auth.uid()) = 'admin');

drop policy if exists "Sales users view assigned leads" on public.leads;
create policy "Sales users view assigned leads" on public.leads
for select to authenticated using (assigned_to = auth.uid());

drop policy if exists "Sales users update assigned leads" on public.leads;
create policy "Sales users update assigned leads" on public.leads
for update to authenticated
using (assigned_to = auth.uid())
with check (assigned_to = auth.uid());

-- Create a profile automatically whenever an auth user is created.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Backfill profiles for existing auth users.
insert into public.profiles (id, full_name, email)
select id, coalesce(raw_user_meta_data ->> 'full_name', ''), email from auth.users
on conflict (id) do nothing;
