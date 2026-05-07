-- SIS27 platform: database ownership boundary for the Contact satellite app.
-- Platform migrations run privileged; Contact migrations run under contact_migrator.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'platform_migrator') then
    create role platform_migrator nologin;
  end if;

  if not exists (select 1 from pg_roles where rolname = 'contact_migrator') then
    create role contact_migrator nologin;
  end if;
end
$$;

grant platform_migrator to postgres;
grant contact_migrator to postgres;

grant usage, create on schema public to platform_migrator;

alter table if exists public.profiles owner to platform_migrator;
alter function public.set_profiles_updated_at() owner to platform_migrator;
alter function public.handle_new_user() owner to platform_migrator;
alter table if exists public.roles owner to platform_migrator;
alter sequence if exists public.roles_id_seq owner to platform_migrator;
alter table if exists public.user_roles owner to platform_migrator;
alter function public.current_user_roles() owner to platform_migrator;
alter function public.has_role(text) owner to platform_migrator;

-- Destructive one-time reset for the POC: Contact is moving from public.* to contact.*.
drop table if exists public.contact_entries cascade;
drop function if exists public.contact_users_public_profile(uuid[]) cascade;
drop function if exists public.set_contact_entries_updated_at() cascade;

create schema if not exists contact authorization contact_migrator;
alter schema contact owner to contact_migrator;

grant usage on schema public to contact_migrator;
grant usage on schema auth to contact_migrator;
grant usage on schema contact to anon, authenticated, service_role;
grant all on schema contact to contact_migrator;

grant references, select on auth.users to contact_migrator;
grant select on public.profiles to contact_migrator;
grant execute on function public.has_role(text) to contact_migrator;

alter role contact_migrator in database postgres set search_path = contact, public, auth;

comment on schema contact is 'Contact satellite app schema. Owned by contact_migrator; platform objects stay in public/auth.';
comment on role contact_migrator is 'No-login role used to apply Contact satellite app migrations.';
comment on role platform_migrator is 'No-login role for SIS27 platform-owned database objects.';
