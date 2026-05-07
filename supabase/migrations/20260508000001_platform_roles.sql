-- SIS27 platform: role catalog and per-user assignments (RLS).
-- Roles are assigned manually (SQL / service_role) for this POC.

create table if not exists public.roles (
  id bigserial primary key,
  name text not null unique,
  created_at timestamptz not null default now()
);

comment on table public.roles is 'Platform role catalog; referenced by user_roles.';

insert into public.roles (name)
values ('contact:user'), ('contact:admin')
on conflict (name) do nothing;

create table if not exists public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role_id bigint not null references public.roles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, role_id)
);

comment on table public.user_roles is 'Many-to-many: auth users and platform roles.';

alter table public.roles enable row level security;
alter table public.user_roles enable row level security;

grant select on public.roles to authenticated;
grant select on public.user_roles to authenticated;
grant all on public.roles to service_role;
grant all on public.user_roles to service_role;

-- Catalog is readable by any signed-in user.
drop policy if exists "roles_select_authenticated" on public.roles;
create policy "roles_select_authenticated"
  on public.roles
  for select
  to authenticated
  using (true);

-- Users can see only their own role rows.
drop policy if exists "user_roles_select_own" on public.user_roles;
create policy "user_roles_select_own"
  on public.user_roles
  for select
  to authenticated
  using (auth.uid() = user_id);

-- No direct client writes; assign via service_role / SQL as postgres.
drop policy if exists "user_roles_no_insert_authenticated" on public.user_roles;
create policy "user_roles_no_insert_authenticated"
  on public.user_roles
  for insert
  to authenticated
  with check (false);

drop policy if exists "user_roles_no_update_authenticated" on public.user_roles;
create policy "user_roles_no_update_authenticated"
  on public.user_roles
  for update
  to authenticated
  using (false)
  with check (false);

drop policy if exists "user_roles_no_delete_authenticated" on public.user_roles;
create policy "user_roles_no_delete_authenticated"
  on public.user_roles
  for delete
  to authenticated
  using (false);

create or replace function public.current_user_roles()
returns text[]
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    array_agg(r.name order by r.name) filter (where r.name is not null),
    '{}'::text[]
  )
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = auth.uid();
$$;

comment on function public.current_user_roles() is 'Role names for the current auth user; empty array if none.';

create or replace function public.has_role(role_name text)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = role_name
  );
$$;

comment on function public.has_role(text) is 'True if current auth user has the given role name.';

grant execute on function public.current_user_roles() to authenticated;
grant execute on function public.has_role(text) to authenticated;
grant execute on function public.current_user_roles() to service_role;
grant execute on function public.has_role(text) to service_role;
