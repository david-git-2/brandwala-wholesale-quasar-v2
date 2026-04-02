-- =========================================================
-- Step 3: Costing file backend access rules
-- Add helpers, RLS policies, and update guards for
-- admin, staff, and customer-side users.
-- =========================================================

create or replace function public.is_tenant_staff(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'staff'
      and m.is_active = true
  )
$$;

create or replace function public.is_customer_group_member(
  p_customer_group_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    inner join public.customer_groups cg
      on cg.id = cgm.customer_group_id
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  )
$$;

create or replace function public.can_admin_manage_costing_file(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;

create or replace function public.can_staff_access_costing_file(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_tenant_staff(p_tenant_id)
$$;

create or replace function public.can_customer_access_costing_file(
  p_customer_group_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_customer_group_member(p_customer_group_id)
$$;

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
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
  )
$$;

create or replace function public.current_costing_item_actor_role(
  p_costing_file_id bigint
)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select case
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_admin_manage_costing_file(cf.tenant_id)
    ) then 'admin'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_staff_access_costing_file(cf.tenant_id)
    ) then 'staff'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_customer_access_costing_file(cf.customer_group_id)
    ) then 'customer'
    else null
  end
$$;

grant execute on function public.is_tenant_staff(bigint)
to authenticated;

grant execute on function public.is_customer_group_member(bigint)
to authenticated;

grant execute on function public.can_admin_manage_costing_file(bigint)
to authenticated;

grant execute on function public.can_staff_access_costing_file(bigint)
to authenticated;

grant execute on function public.can_customer_access_costing_file(bigint)
to authenticated;

grant execute on function public.can_view_costing_file(bigint)
to authenticated;

grant execute on function public.current_costing_item_actor_role(bigint)
to authenticated;

create or replace function public.enforce_costing_file_item_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role text;
begin
  v_actor_role := public.current_costing_item_actor_role(old.costing_file_id);

  if v_actor_role = 'admin' then
    return new;
  end if;

  if v_actor_role = 'staff' then
    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.customer_profit_rate is distinct from old.customer_profit_rate
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'staff can update enrichment fields only';
    end if;

    return new;
  end if;

  if v_actor_role = 'customer' then
    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.name is distinct from old.name
      or new.image_url is distinct from old.image_url
      or new.product_weight is distinct from old.product_weight
      or new.package_weight is distinct from old.package_weight
      or new.price_in_web_gbp is distinct from old.price_in_web_gbp
      or new.delivery_price_gbp is distinct from old.delivery_price_gbp
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'customer can update customer_profit_rate only';
    end if;

    return new;
  end if;

  raise exception 'current user cannot update costing file items';
end;
$$;

alter table public.costing_files enable row level security;
alter table public.costing_file_items enable row level security;

create policy "costing_files_select"
on public.costing_files
for select
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
  or public.can_staff_access_costing_file(tenant_id)
  or public.can_customer_access_costing_file(customer_group_id)
);

create policy "costing_files_insert"
on public.costing_files
for insert
to authenticated
with check (
  public.can_admin_manage_costing_file(tenant_id)
);

create policy "costing_files_update"
on public.costing_files
for update
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
)
with check (
  public.can_admin_manage_costing_file(tenant_id)
);

create policy "costing_files_delete"
on public.costing_files
for delete
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
);

create policy "costing_file_items_select"
on public.costing_file_items
for select
to authenticated
using (
  public.can_view_costing_file(costing_file_id)
);

create policy "costing_file_items_insert"
on public.costing_file_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
  )
);

create policy "costing_file_items_update"
on public.costing_file_items
for update
to authenticated
using (
  public.can_view_costing_file(costing_file_id)
)
with check (
  public.can_view_costing_file(costing_file_id)
);

create policy "costing_file_items_delete"
on public.costing_file_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
  )
);

drop trigger if exists trg_costing_file_items_enforce_update_rules on public.costing_file_items;
create trigger trg_costing_file_items_enforce_update_rules
before update on public.costing_file_items
for each row execute function public.enforce_costing_file_item_update_rules();
