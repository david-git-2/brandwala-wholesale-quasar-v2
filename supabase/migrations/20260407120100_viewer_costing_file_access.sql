-- =========================================================
-- Viewer costing-file access
-- Adds viewer table, RPCs, and visibility rules.
-- =========================================================

create table if not exists public.costing_file_viewers (
  id bigserial primary key,
  costing_file_id bigint not null references public.costing_files(id) on delete cascade,
  membership_id bigint not null references public.memberships(id) on delete cascade,
  created_by_email text not null default public.current_user_email(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint costing_file_viewers_unique unique (costing_file_id, membership_id)
);

create index if not exists costing_file_viewers_costing_file_id_idx
  on public.costing_file_viewers (costing_file_id);

create index if not exists costing_file_viewers_membership_id_idx
  on public.costing_file_viewers (membership_id);

drop trigger if exists trg_costing_file_viewers_updated_at on public.costing_file_viewers;
create trigger trg_costing_file_viewers_updated_at
before update on public.costing_file_viewers
for each row execute function public.set_updated_at();

create or replace function public.can_manage_costing_file_viewers(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.can_admin_manage_costing_file(p_tenant_id);
$$;

grant execute on function public.can_manage_costing_file_viewers(bigint)
to authenticated;

create or replace function public.is_assigned_costing_file_viewer(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_file_viewers cfv
    inner join public.memberships m
      on m.id = cfv.membership_id
    where cfv.costing_file_id = p_costing_file_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role = 'viewer'
  );
$$;

grant execute on function public.is_assigned_costing_file_viewer(bigint)
to authenticated;

create or replace function public.can_view_costing_file_items(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        (
          public.can_admin_manage_costing_file(cf.tenant_id)
          and (
            public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            or cf.status in ('customer_submitted', 'in_review', 'priced', 'offered', 'completed', 'cancelled')
          )
        )
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status = 'completed'
        )
      )
  );
$$;

grant execute on function public.can_view_costing_file_items(bigint)
to authenticated;

create or replace function public.can_view_costing_file(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        (
          public.can_admin_manage_costing_file(cf.tenant_id)
          and (
            public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            or cf.status in ('customer_submitted', 'offered', 'completed', 'cancelled')
          )
        )
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
        or public.is_assigned_costing_file_viewer(cf.id)
      )
  );
$$;

grant execute on function public.can_view_costing_file(bigint)
to authenticated;

drop policy if exists "costing_file_viewers_select" on public.costing_file_viewers;
create policy "costing_file_viewers_select"
on public.costing_file_viewers
for select
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  )
);

drop policy if exists "costing_file_viewers_insert" on public.costing_file_viewers;
create policy "costing_file_viewers_insert"
on public.costing_file_viewers
for insert
to authenticated
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  )
);

drop policy if exists "costing_file_viewers_delete" on public.costing_file_viewers;
create policy "costing_file_viewers_delete"
on public.costing_file_viewers
for delete
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  )
);

drop policy if exists "costing_file_items_select" on public.costing_file_items;
create policy "costing_file_items_select"
on public.costing_file_items
for select
to authenticated
using (
  public.can_view_costing_file_items(costing_file_id)
);

drop policy if exists "costing_file_items_update" on public.costing_file_items;
create policy "costing_file_items_update"
on public.costing_file_items
for update
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
  )
)
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
  )
);

drop policy if exists "costing_file_items_delete" on public.costing_file_items;
create policy "costing_file_items_delete"
on public.costing_file_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
          and lower(trim(cf.created_by_email)) = public.current_user_email()
        )
      )
  )
);

drop function if exists public.list_tenants_by_membership(bigint, text, public.app_role);
create or replace function public.list_tenants_by_membership(
  p_tenant_id bigint default null,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
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
    and (
      p_role is null
      or m.role = p_role
    )
  order by t.id asc;
$$;

grant execute on function public.list_tenants_by_membership(bigint, text, public.app_role)
to authenticated;

drop function if exists public.get_tenant_details_by_membership(bigint, text, public.app_role);
create or replace function public.get_tenant_details_by_membership(
  p_tenant_id bigint,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
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
    and (
      p_role is null
      or m.role = p_role
    )
  limit 1;
$$;

grant execute on function public.get_tenant_details_by_membership(bigint, text, public.app_role)
to authenticated;

drop function if exists public.get_app_bootstrap_context(text, bigint, bigint);
create or replace function public.get_app_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_membership_id bigint default null
)
returns table(
  member_id bigint,
  member_email text,
  member_role public.app_role,
  member_is_active boolean,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  active_module_keys text[]
)
language sql
security definer
set search_path = public
stable
as $$
  with matched_member as (
    select
      m.id,
      lower(trim(m.email)) as email,
      m.role,
      m.is_active,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active
    from public.memberships m
    inner join public.tenants t
      on t.id = m.tenant_id
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, public.current_user_email())))
      and m.is_active = true
      and m.role in ('admin', 'staff', 'viewer')
      and (p_tenant_id is null or m.tenant_id = p_tenant_id)
      and (p_membership_id is null or m.id = p_membership_id)
    order by
      case m.role
        when 'admin' then 1
        when 'staff' then 2
        when 'viewer' then 3
        else 99
      end,
      m.id asc
    limit 1
  ),
  module_keys as (
    select
      tm.tenant_id,
      coalesce(
        array_agg(tm.module_key order by tm.module_key)
          filter (where tm.module_key is not null),
        '{}'::text[]
      ) as active_module_keys
    from public.tenant_modules tm
    inner join public.modules mo
      on mo.key = tm.module_key
    where tm.is_active = true
      and mo.is_active = true
    group by tm.tenant_id
  )
  select
    mm.id as member_id,
    mm.email as member_email,
    mm.role as member_role,
    mm.is_active as member_is_active,
    mm.tenant_id,
    mm.tenant_name,
    mm.tenant_slug,
    mm.tenant_is_active,
    coalesce(mk.active_module_keys, '{}'::text[]) as active_module_keys
  from matched_member mm
  left join module_keys mk
    on mk.tenant_id = mm.tenant_id;
$$;

grant execute on function public.get_app_bootstrap_context(text, bigint, bigint)
to authenticated;

create or replace function public.list_tenant_viewers(
  p_tenant_id bigint
)
returns table(
  membership_id bigint,
  tenant_id bigint,
  name text,
  email text,
  role public.app_role,
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
    m.id as membership_id,
    m.tenant_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    m.created_at,
    m.updated_at
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.tenants t
      where t.id = p_tenant_id
        and public.can_manage_costing_file_viewers(t.id)
    )
    and m.role = 'viewer'
  order by m.created_at asc, m.id asc;
$$;

grant execute on function public.list_tenant_viewers(bigint)
to authenticated;

create or replace function public.list_costing_file_viewers(
  p_costing_file_id bigint
)
returns table(
  costing_file_viewer_id bigint,
  costing_file_id bigint,
  membership_id bigint,
  name text,
  email text,
  role public.app_role,
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
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    cfv.created_at,
    cfv.updated_at
  from public.costing_file_viewers cfv
  inner join public.memberships m
    on m.id = cfv.membership_id
  where cfv.costing_file_id = p_costing_file_id
    and exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_manage_costing_file_viewers(cf.tenant_id)
    )
  order by cfv.id asc;
$$;

grant execute on function public.list_costing_file_viewers(bigint)
to authenticated;

create or replace function public.grant_costing_file_viewer(
  p_costing_file_id bigint,
  p_membership_id bigint
)
returns table(
  costing_file_viewer_id bigint,
  costing_file_id bigint,
  membership_id bigint,
  name text,
  email text,
  role public.app_role,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with target_file as (
    select cf.id, cf.tenant_id
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  ),
  target_viewer as (
    select m.id, m.email, m.role, m.is_active
    from public.memberships m
    inner join target_file tf
      on true
    where m.id = p_membership_id
      and m.tenant_id = tf.tenant_id
      and m.role = 'viewer'
      and m.is_active = true
  ),
  inserted as (
    insert into public.costing_file_viewers (
      costing_file_id,
      membership_id
    )
    select
      tf.id,
      tv.id
    from target_file tf
    cross join target_viewer tv
    on conflict (costing_file_id, membership_id) do update
      set updated_at = now()
    returning
      id as costing_file_viewer_id,
      costing_file_id,
      membership_id,
      created_at,
      updated_at
  )
  select
    i.costing_file_viewer_id,
    i.costing_file_id,
    i.membership_id,
    tv.email as name,
    tv.email,
    tv.role,
    tv.is_active,
    i.created_at,
    i.updated_at
  from inserted i
  inner join target_viewer tv
    on tv.id = i.membership_id;
$$;

grant execute on function public.grant_costing_file_viewer(bigint, bigint)
to authenticated;

create or replace function public.revoke_costing_file_viewer(
  p_costing_file_id bigint,
  p_membership_id bigint
)
returns table(
  costing_file_viewer_id bigint,
  costing_file_id bigint,
  membership_id bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  delete from public.costing_file_viewers cfv
  using public.costing_files cf
  where cf.id = p_costing_file_id
    and cf.id = cfv.costing_file_id
    and cfv.membership_id = p_membership_id
    and public.can_manage_costing_file_viewers(cf.tenant_id)
  returning
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    cfv.created_at,
    cfv.updated_at;
$$;

grant execute on function public.revoke_costing_file_viewer(bigint, bigint)
to authenticated;
