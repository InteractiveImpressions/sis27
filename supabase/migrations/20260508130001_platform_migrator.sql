-- SIS27 platform: migrator role and ownership for shared public objects.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'platform_migrator') then
    create role platform_migrator nologin;
  end if;
end
$$;

grant platform_migrator to postgres;

grant usage, create on schema public to platform_migrator;

alter table if exists public.profiles owner to platform_migrator;
alter function public.set_profiles_updated_at() owner to platform_migrator;
alter function public.handle_new_user() owner to platform_migrator;
alter table if exists public.roles owner to platform_migrator;
alter sequence if exists public.roles_id_seq owner to platform_migrator;
alter table if exists public.user_roles owner to platform_migrator;
alter function public.current_user_roles() owner to platform_migrator;
alter function public.has_role(text) owner to platform_migrator;

comment on role platform_migrator is 'No-login role for SIS27 platform-owned database objects.';
