-- =========================================================
-- Step 4: Costing file backend RPCs
-- Stable backend entry points for frontend usage.
-- =========================================================

create or replace function public.list_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null
)
returns table(
  id bigint,
  name text,
  market text,
  status public.costing_file_status,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cf.id,
    cf.name,
    cf.market,
    cf.status,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
  )
  order by cf.id desc;
$$;

grant execute on function public.list_costing_files_for_actor(bigint, bigint)
to authenticated;

create or replace function public.get_costing_file_by_id(
  p_id bigint
)
returns table(
  id bigint,
  name text,
  cargo_rate_1kg numeric,
  cargo_rate_2kg numeric,
  conversion_rate numeric,
  admin_profit_rate numeric,
  status public.costing_file_status,
  market text,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cf.id,
    cf.name,
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate,
    cf.status,
    cf.market,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where cf.id = p_id
    and public.can_view_costing_file(cf.id)
  limit 1;
$$;

grant execute on function public.get_costing_file_by_id(bigint)
to authenticated;

create or replace function public.list_costing_file_items(
  p_costing_file_id bigint
)
returns table(
  id bigint,
  costing_file_id bigint,
  name text,
  image_url text,
  website_url text,
  quantity integer,
  product_weight integer,
  package_weight integer,
  price_in_web_gbp numeric,
  delivery_price_gbp numeric,
  auxiliary_price_gbp numeric,
  item_price_gbp numeric,
  cargo_rate numeric,
  costing_price_gbp numeric,
  costing_price_bdt integer,
  offer_price_bdt integer,
  customer_profit_rate numeric,
  status public.costing_file_item_status,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cfi.id,
    cfi.costing_file_id,
    cfi.name,
    cfi.image_url,
    cfi.website_url,
    cfi.quantity,
    cfi.product_weight,
    cfi.package_weight,
    cfi.price_in_web_gbp,
    cfi.delivery_price_gbp,
    cfi.auxiliary_price_gbp,
    cfi.item_price_gbp,
    cfi.cargo_rate,
    cfi.costing_price_gbp,
    cfi.costing_price_bdt,
    cfi.offer_price_bdt,
    cfi.customer_profit_rate,
    cfi.status,
    cfi.created_by_email,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$$;

grant execute on function public.list_costing_file_items(bigint)
to authenticated;

create or replace function public.create_costing_file(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_name text,
  p_market text
)
returns table(
  id bigint,
  name text,
  market text,
  status public.costing_file_status,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with inserted as (
    insert into public.costing_files (
      tenant_id,
      customer_group_id,
      name,
      market
    )
    select
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      trim(p_market)
    where public.can_admin_manage_costing_file(p_tenant_id)
    returning
      id,
      name,
      market,
      status,
      customer_group_id,
      tenant_id,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;

grant execute on function public.create_costing_file(bigint, bigint, text, text)
to authenticated;

create or replace function public.create_costing_file_item_request(
  p_costing_file_id bigint,
  p_website_url text,
  p_quantity integer
)
returns table(
  id bigint,
  costing_file_id bigint,
  website_url text,
  quantity integer,
  status public.costing_file_item_status,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      website_url,
      quantity
    )
    select
      cf.id,
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      id,
      costing_file_id,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;

grant execute on function public.create_costing_file_item_request(bigint, text, integer)
to authenticated;

create or replace function public.update_costing_file_item_enrichment(
  p_id bigint,
  p_name text default null,
  p_image_url text default null,
  p_product_weight integer default null,
  p_package_weight integer default null,
  p_price_in_web_gbp numeric default null,
  p_delivery_price_gbp numeric default null
)
returns table(
  id bigint,
  costing_file_id bigint,
  name text,
  image_url text,
  product_weight integer,
  package_weight integer,
  price_in_web_gbp numeric,
  delivery_price_gbp numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set
      name = coalesce(trim(p_name), cfi.name),
      image_url = coalesce(trim(p_image_url), cfi.image_url),
      product_weight = coalesce(p_product_weight, cfi.product_weight),
      package_weight = coalesce(p_package_weight, cfi.package_weight),
      price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
      delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
      )
    returning
      cfi.id,
      cfi.costing_file_id,
      cfi.name,
      cfi.image_url,
      cfi.product_weight,
      cfi.package_weight,
      cfi.price_in_web_gbp,
      cfi.delivery_price_gbp,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_enrichment(bigint, text, text, integer, integer, numeric, numeric)
to authenticated;

create or replace function public.update_costing_file_pricing(
  p_id bigint,
  p_cargo_rate_1kg numeric default null,
  p_cargo_rate_2kg numeric default null,
  p_conversion_rate numeric default null,
  p_admin_profit_rate numeric default null
)
returns table(
  id bigint,
  cargo_rate_1kg numeric,
  cargo_rate_2kg numeric,
  conversion_rate numeric,
  admin_profit_rate numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_files cf
    set
      cargo_rate_1kg = coalesce(p_cargo_rate_1kg, cf.cargo_rate_1kg),
      cargo_rate_2kg = coalesce(p_cargo_rate_2kg, cf.cargo_rate_2kg),
      conversion_rate = coalesce(p_conversion_rate, cf.conversion_rate),
      admin_profit_rate = coalesce(p_admin_profit_rate, cf.admin_profit_rate)
    where cf.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cf.id,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_pricing(bigint, numeric, numeric, numeric, numeric)
to authenticated;

create or replace function public.update_costing_file_item_offer(
  p_id bigint,
  p_auxiliary_price_gbp numeric default null,
  p_item_price_gbp numeric default null,
  p_cargo_rate numeric default null,
  p_costing_price_gbp numeric default null,
  p_costing_price_bdt integer default null,
  p_offer_price_bdt integer default null
)
returns table(
  id bigint,
  auxiliary_price_gbp numeric,
  item_price_gbp numeric,
  cargo_rate numeric,
  costing_price_gbp numeric,
  costing_price_bdt integer,
  offer_price_bdt integer,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set
      auxiliary_price_gbp = coalesce(p_auxiliary_price_gbp, cfi.auxiliary_price_gbp),
      item_price_gbp = coalesce(p_item_price_gbp, cfi.item_price_gbp),
      cargo_rate = coalesce(p_cargo_rate, cfi.cargo_rate),
      costing_price_gbp = coalesce(p_costing_price_gbp, cfi.costing_price_gbp),
      costing_price_bdt = coalesce(p_costing_price_bdt, cfi.costing_price_bdt),
      offer_price_bdt = coalesce(p_offer_price_bdt, cfi.offer_price_bdt)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.auxiliary_price_gbp,
      cfi.item_price_gbp,
      cfi.cargo_rate,
      cfi.costing_price_gbp,
      cfi.costing_price_bdt,
      cfi.offer_price_bdt,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer)
to authenticated;

create or replace function public.update_costing_file_item_customer_profit(
  p_id bigint,
  p_customer_profit_rate numeric
)
returns table(
  id bigint,
  customer_profit_rate numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_customer_profit(bigint, numeric)
to authenticated;

create or replace function public.update_costing_file_item_status(
  p_id bigint,
  p_status public.costing_file_item_status
)
returns table(
  id bigint,
  status public.costing_file_item_status,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set status = p_status
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.status,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_status(bigint, public.costing_file_item_status)
to authenticated;

create or replace function public.update_costing_file_status(
  p_id bigint,
  p_status public.costing_file_status
)
returns table(
  id bigint,
  status public.costing_file_status,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_status(bigint, public.costing_file_status)
to authenticated;
