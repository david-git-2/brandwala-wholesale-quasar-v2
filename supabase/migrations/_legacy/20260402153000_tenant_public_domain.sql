-- =========================================================
-- Tenant public domain support
-- Align tenants with the master plan and expose the field in
-- all tenant-facing RPCs.
-- =========================================================

alter table public.tenants
add column if not exists public_domain text;

update public.tenants
set public_domain = nullif(
  regexp_replace(
    lower(
      trim(
        split_part(
          regexp_replace(coalesce(public_domain, ''), '^https?://', '', 'i'),
          '/',
          1
        )
      )
    ),
    ':\d+$',
    ''
  ),
  ''
);

drop index if exists public.tenants_public_domain_unique_idx;

create unique index if not exists tenants_public_domain_unique_idx
on public.tenants ((lower(trim(public_domain))))
where nullif(trim(public_domain), '') is not null;

drop function if exists public.create_tenant_for_superadmin(text, text, boolean);

create function public.create_tenant_for_superadmin(
  p_name text,
  p_slug text,
  p_is_active boolean default true,
  p_public_domain text default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  inserted as (
    insert into public.tenants (name, slug, public_domain, is_active)
    select
      trim(p_name),
      lower(trim(p_slug)),
      nullif(
        regexp_replace(
          lower(
            trim(
              split_part(
                regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
                '/',
                1
              )
            )
          ),
          ':\d+$',
          ''
        ),
        ''
      ),
      coalesce(p_is_active, true)
    from permission
    where allowed
    returning
      id,
      name,
      slug,
      public_domain,
      is_active,
      created_at,
      updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    created_at,
    updated_at
  from inserted;
$$;

grant execute on function public.create_tenant_for_superadmin(text, text, boolean, text)
to authenticated;

drop function if exists public.update_tenant_for_superadmin(bigint, text, text, boolean);

create function public.update_tenant_for_superadmin(
  p_tenant_id bigint,
  p_name text,
  p_slug text,
  p_is_active boolean,
  p_public_domain text default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  updated as (
    update public.tenants as t
    set
      name = trim(p_name),
      slug = lower(trim(p_slug)),
      public_domain = nullif(
        regexp_replace(
          lower(
            trim(
              split_part(
                regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
                '/',
                1
              )
            )
          ),
          ':\d+$',
          ''
        ),
        ''
      ),
      is_active = coalesce(p_is_active, true)
    from permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    created_at,
    updated_at
  from updated;
$$;

grant execute on function public.update_tenant_for_superadmin(bigint, text, text, boolean, text)
to authenticated;

drop function if exists public.delete_tenant_for_superadmin(bigint);

create function public.delete_tenant_for_superadmin(
  p_tenant_id bigint
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  deleted as (
    delete from public.tenants as t
    using permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    created_at,
    updated_at
  from deleted;
$$;

grant execute on function public.delete_tenant_for_superadmin(bigint)
to authenticated;

drop function if exists public.list_tenants_for_superadmin();

create function public.list_tenants_for_superadmin()
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_superadmin() then
    return;
  end if;

  return query
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  order by t.id asc;
end;
$$;

grant execute on function public.list_tenants_for_superadmin()
to authenticated;

drop function if exists public.list_my_admin_tenants();

create function public.list_my_admin_tenants()
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  where exists (
    select 1
    from public.memberships m
    where m.tenant_id = t.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
  )
  order by t.id asc;
$$;

grant execute on function public.list_my_admin_tenants()
to authenticated;

drop function if exists public.list_tenants_by_membership(bigint, text, public.app_role);

create function public.list_tenants_by_membership(
  p_tenant_id bigint default null,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where m.is_active = true
    and (p_tenant_id is null or t.id = p_tenant_id)
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  order by t.id asc;
$$;

grant execute on function public.list_tenants_by_membership(bigint, text, public.app_role)
to authenticated;

drop function if exists public.get_tenant_details_by_membership(bigint, text, public.app_role);

create function public.get_tenant_details_by_membership(
  p_tenant_id bigint,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where t.id = p_tenant_id
    and m.is_active = true
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  limit 1;
$$;

grant execute on function public.get_tenant_details_by_membership(bigint, text, public.app_role)
to authenticated;
