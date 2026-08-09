-- PlottingBazaar CRM: professional features batch 2.
-- Run once in Supabase SQL Editor (after 20260808_crm_upgrade.sql).

-- ============================================================
-- 1. LEAD SOURCE — track which channel a lead came from
--    (Facebook, Referral, Walk-in, etc.)
-- ============================================================
alter table public.leads add column if not exists source text;

-- ============================================================
-- 2. DUPLICATE PHONE CHECK — lets any logged-in employee find out if a
--    phone number is already a lead (assigned to someone else or not),
--    WITHOUT exposing that other lead's full details or bypassing RLS
--    for anything else. This stops two employees from independently
--    calling the same person.
-- ============================================================
create or replace function public.check_lead_phone_exists(p_phone text)
returns table (lead_name text, assigned_name text, lead_status text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    l.name,
    coalesce(p.full_name, p.email, 'Unassigned'),
    l.status
  from public.leads l
  left join public.profiles p on p.id = l.assigned_to
  where regexp_replace(l.phone, '\D', '', 'g') = regexp_replace(p_phone, '\D', '', 'g')
  order by l.created_at desc
  limit 1;
end;
$$;

grant execute on function public.check_lead_phone_exists(text) to authenticated;

-- ============================================================
-- 3. PROFILE SELF-SERVICE — allow a logged-in user to update their own
--    display name (needed for the new Profile screen). Role changes stay
--    admin-only: the trigger below silently reverts any attempt by a
--    non-admin to change their own `role` column, even though the RLS
--    policy itself allows updating the row (RLS can't restrict individual
--    columns, only rows).
-- ============================================================
drop policy if exists "Users update their own display name" on public.profiles;
create policy "Users update their own display name" on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create or replace function public.prevent_role_self_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if not exists (
      select 1 from public.profiles where id = auth.uid() and role = 'admin'
    ) then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_role_self_escalation on public.profiles;
create trigger trg_prevent_role_self_escalation
before update on public.profiles
for each row execute function public.prevent_role_self_escalation();
