-- Fixes "Could not remove user: FunctionException(... Database error deleting
-- user)" on the Manage users screen.
--
-- WHY THIS HAPPENS:
-- Supabase's auth.admin.deleteUser() deletes the row from auth.users.
-- Every table in this project that references auth.users(id) was created
-- with an explicit ON DELETE action (cascade / set null) EXCEPT for tables
-- that were created directly in the Supabase dashboard rather than through
-- one of the migrations in this repo (e.g. an early leads/customers
-- "created_by" column, a push-notification-token table, etc.) -- those
-- default to Postgres's NO ACTION, which makes the delete fail at the
-- database level the moment that user has any row anywhere pointing at
-- them. GoTrue reports that failure back only as the generic message
-- "Database error deleting user", which is exactly what the app showed.
--
-- FIX: a generic helper that runs right before the delete. It walks
-- every foreign key in the public schema that points at auth.users(id) --
-- whatever it is, known or not -- and either nulls it out (nullable
-- columns, e.g. assigned_to) or reassigns it to the admin performing the
-- deletion (required columns, e.g. called_by/created_by), so their call
-- logs, feedback, activity, etc. are preserved instead of being destroyed
-- or blocking the delete. Tables that "extend" auth.users with their own
-- primary key (profiles.id) are skipped -- those rows are meant to be
-- removed by their own ON DELETE CASCADE, not reassigned.
--
-- Run this once in the Supabase SQL editor (or `supabase db push`).

create or replace function public.admin_delete_user_prep(
  target_user_id uuid,
  fallback_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  fk record;
  col_is_nullable boolean;
  col_is_pk boolean;
begin
  for fk in
    select tc.table_schema, tc.table_name, kcu.column_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name
      and tc.table_schema = kcu.table_schema
    join information_schema.constraint_column_usage ccu
      on tc.constraint_name = ccu.constraint_name
      and tc.table_schema = ccu.table_schema
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema = 'public'
      and ccu.table_schema = 'auth'
      and ccu.table_name = 'users'
      and ccu.column_name = 'id'
  loop
    -- Skip "extends auth.users" tables (e.g. profiles) where the FK column
    -- is itself that table's primary key. Those rows are removed with the
    -- user via ON DELETE CASCADE, never reassigned to someone else.
    select exists (
      select 1
      from information_schema.table_constraints pk
      join information_schema.key_column_usage pkcu
        on pk.constraint_name = pkcu.constraint_name
        and pk.table_schema = pkcu.table_schema
      where pk.constraint_type = 'PRIMARY KEY'
        and pk.table_schema = fk.table_schema
        and pk.table_name = fk.table_name
        and pkcu.column_name = fk.column_name
    ) into col_is_pk;

    if col_is_pk then
      continue;
    end if;

    select (c.is_nullable = 'YES') into col_is_nullable
    from information_schema.columns c
    where c.table_schema = fk.table_schema
      and c.table_name = fk.table_name
      and c.column_name = fk.column_name;

    if col_is_nullable then
      execute format(
        'update %I.%I set %I = null where %I = $1',
        fk.table_schema, fk.table_name, fk.column_name, fk.column_name
      ) using target_user_id;
    else
      execute format(
        'update %I.%I set %I = $2 where %I = $1',
        fk.table_schema, fk.table_name, fk.column_name, fk.column_name
      ) using target_user_id, fallback_user_id;
    end if;
  end loop;
end;
$$;

-- Only the admin-users Edge Function (using the service-role key) calls
-- this, but grant to authenticated too so it also works if ever called
-- from a context using the caller's own session.
grant execute on function public.admin_delete_user_prep(uuid, uuid) to service_role, authenticated;
