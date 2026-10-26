-- Catalog scrape/upload log + singleton app release versions (staff visibility).

create table if not exists public.catalog_refresh_log (
  id bigserial primary key,
  parent_tenant_id bigint not null,
  source text not null,
  event_kind text not null,
  source_url text,
  file_name text,
  ran_at timestamptz not null default now(),
  products_updated integer,
  duration_seconds integer,
  constraint catalog_refresh_log_event_kind_check
    check (event_kind in ('scrape', 'upload')),
  constraint catalog_refresh_log_payload_check
    check (
      (event_kind = 'scrape' and source_url is not null and file_name is null)
      or (event_kind = 'upload' and file_name is not null)
    )
);

create index if not exists catalog_refresh_log_list_idx
  on public.catalog_refresh_log (parent_tenant_id, source, event_kind, ran_at desc);

alter table public.catalog_refresh_log enable row level security;

revoke all on table public.catalog_refresh_log from anon, authenticated;
revoke all on sequence public.catalog_refresh_log_id_seq from anon, authenticated;
grant select, insert on table public.catalog_refresh_log to service_role;
grant usage, select on sequence public.catalog_refresh_log_id_seq to service_role;

create table if not exists public.app_release_versions (
  id smallint primary key default 1,
  backend_version text not null default 'unknown',
  frontend_version text not null default 'unknown',
  backend_updated_at timestamptz not null default now(),
  frontend_updated_at timestamptz not null default now(),
  constraint app_release_versions_singleton check (id = 1)
);

alter table public.app_release_versions enable row level security;

revoke all on table public.app_release_versions from anon, authenticated;
grant select, insert, update on table public.app_release_versions to service_role;

insert into public.app_release_versions (id, backend_version, frontend_version)
values (1, 'unknown', 'unknown')
on conflict (id) do nothing;

create or replace function public.list_catalog_refresh_log(
  p_parent_tenant_id bigint,
  p_limit integer default 50
)
returns table (
  id bigint,
  parent_tenant_id bigint,
  source text,
  event_kind text,
  source_url text,
  file_name text,
  ran_at timestamptz,
  products_updated integer,
  duration_seconds integer
)
language plpgsql
stable
security definer
set search_path to public
as $$
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if not public.can_view_products_for_parent(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.parent_tenant_id,
    l.source,
    l.event_kind,
    l.source_url,
    l.file_name,
    l.ran_at,
    l.products_updated,
    l.duration_seconds
  from public.catalog_refresh_log l
  where l.parent_tenant_id = p_parent_tenant_id
  order by l.ran_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

create or replace function public.get_app_release_versions()
returns table (
  backend_version text,
  frontend_version text,
  backend_updated_at timestamptz,
  frontend_updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path to public
as $$
begin
  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.is_active = true
        and lower(trim(m.email)) = public.current_user_email()
        and public.membership_has_module_action(m.tenant_id, 'products', 'view')
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    v.backend_version,
    v.frontend_version,
    v.backend_updated_at,
    v.frontend_updated_at
  from public.app_release_versions v
  where v.id = 1;
end;
$$;

revoke all on function public.list_catalog_refresh_log(bigint, integer) from public;
revoke all on function public.get_app_release_versions() from public;
grant execute on function public.list_catalog_refresh_log(bigint, integer) to authenticated;
grant execute on function public.get_app_release_versions() to authenticated;
grant execute on function public.list_catalog_refresh_log(bigint, integer) to service_role;
grant execute on function public.get_app_release_versions() to service_role;
