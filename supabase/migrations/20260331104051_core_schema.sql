-- =========================================================
-- Single migration: schema + triggers + RLS policies
-- For Supabase / Postgres
-- =========================================================

-- -------------------------
-- Types
-- -------------------------
create type app_role as enum (
  'superadmin',
  'admin',
  'staff',
  'viewer',
  'customer'
);

-- -------------------------
-- Tables
-- -------------------------
create table public.profiles (
  id bigserial primary key,
  auth_user_id uuid not null unique,
  email text not null unique,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tenants (
  id bigserial primary key,
  name text not null,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id bigserial primary key,
  profile_id bigint not null references public.profiles(id) on delete cascade,
  tenant_id bigint references public.tenants(id) on delete cascade,
  role app_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),


  constraint memberships_role_tenant_check check (
    (role = 'superadmin' and tenant_id is null)
    or
    (role <> 'superadmin' and tenant_id is not null)
  )
);

create table public.modules (
  id bigserial primary key,
  key text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tenant_modules (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  module_key text not null references public.modules(key) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (tenant_id, module_key)
);

-- -------------------------
-- Helpful indexes
-- -------------------------
create index memberships_profile_id_idx on public.memberships(profile_id);
create index memberships_tenant_id_idx on public.memberships(tenant_id);
create index memberships_role_idx on public.memberships(role);
create index tenant_modules_tenant_id_idx on public.tenant_modules(tenant_id);
create index tenant_modules_module_key_idx on public.tenant_modules(module_key);
create index profiles_auth_user_id_idx on public.profiles(auth_user_id);

-- -------------------------
-- updated_at trigger function
-- -------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_tenants_updated_at
before update on public.tenants
for each row execute function public.set_updated_at();

create trigger trg_memberships_updated_at
before update on public.memberships
for each row execute function public.set_updated_at();

create trigger trg_modules_updated_at
before update on public.modules
for each row execute function public.set_updated_at();

create trigger trg_tenant_modules_updated_at
before update on public.tenant_modules
for each row execute function public.set_updated_at();

-- =========================================================
-- RLS helper functions
-- =========================================================

create or replace function public.current_profile_id()
returns bigint
language sql
stable
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.profile_id = public.current_profile_id()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$$;

create or replace function public.is_tenant_admin(p_tenant_id bigint)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.profile_id = public.current_profile_id()
      and m.tenant_id = p_tenant_id
      and m.role = 'admin'
      and m.is_active = true
  )
$$;

create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role app_role
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'customer')
    )
$$;

-- =========================================================
-- Enable RLS
-- =========================================================
alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.modules enable row level security;
alter table public.tenant_modules enable row level security;

-- =========================================================
-- Policies: tenants
-- superadmin can do all operations
-- =========================================================
create policy "superadmin_can_manage_tenants"
on public.tenants
for all
to authenticated
using (
  public.is_superadmin()
)
with check (
  public.is_superadmin()
);

-- =========================================================
-- Policies: modules
-- superadmin can do all operations
-- =========================================================
create policy "superadmin_can_manage_modules"
on public.modules
for all
to authenticated
using (
  public.is_superadmin()
)
with check (
  public.is_superadmin()
);

-- =========================================================
-- Policies: tenant_modules
-- superadmin can do all operations
-- =========================================================
create policy "superadmin_can_manage_tenant_modules"
on public.tenant_modules
for all
to authenticated
using (
  public.is_superadmin()
)
with check (
  public.is_superadmin()
);

-- =========================================================
-- Policies: memberships
--
-- superadmin:
--   can do all operations
--
-- admin of a tenant:
--   can view memberships in that tenant
--   can add/edit/delete only staff and customer
--   cannot manage admin or superadmin
-- =========================================================

create policy "memberships_select"
on public.memberships
for select
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy "memberships_insert"
on public.memberships
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);

create policy "memberships_update"
on public.memberships
for update
to authenticated
using (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
)
with check (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);

create policy "memberships_delete"
on public.memberships
for delete
to authenticated
using (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);