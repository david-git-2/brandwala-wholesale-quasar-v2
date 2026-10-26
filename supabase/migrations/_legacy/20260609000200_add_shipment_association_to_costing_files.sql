-- Alter table public.costing_files to add default_shipment_id referencing public.shipments(id)
alter table public.costing_files
  add column default_shipment_id bigint references public.shipments(id) on delete set null;

-- Alter table public.costing_file_items to add assigned_shipment_id referencing public.shipments(id)
alter table public.costing_file_items
  add column assigned_shipment_id bigint references public.shipments(id) on delete set null;

-- Redefine public.get_costing_file_by_id
drop function if exists public.get_costing_file_by_id(bigint);

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
  default_shipment_id bigint,
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
    cf.default_shipment_id,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where cf.id = p_id
    and public.can_view_costing_file(cf.id)
  limit 1;
$$;

grant execute on function public.get_costing_file_by_id(bigint) to authenticated;

-- Redefine public.create_costing_file
drop function if exists public.create_costing_file(bigint, text, text, public.costing_file_status, bigint);

create or replace function public.create_costing_file(
  p_customer_group_id bigint,
  p_market text,
  p_name text,
  p_status public.costing_file_status default 'draft',
  p_tenant_id bigint default null
)
returns table(
  id bigint,
  name text,
  market text,
  status public.costing_file_status,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  default_shipment_id bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files as cf (
      tenant_id,
      customer_group_id,
      name,
      market,
      status
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), ''),
      coalesce(p_status, 'draft')
    )
    returning
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at;
end;
$$;

grant execute on function public.create_costing_file(bigint, text, text, public.costing_file_status, bigint) to authenticated;

-- Redefine public.update_costing_file
drop function if exists public.update_costing_file(bigint, text, text, bigint);

create or replace function public.update_costing_file(
  p_id bigint,
  p_name text default null,
  p_market text default null,
  p_customer_group_id bigint default null
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
  default_shipment_id bigint,
  created_at timestamptz,
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
      name = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_name), cf.name)
        else cf.name
      end,
      market = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_market), cf.market)
        else cf.market
      end,
      customer_group_id = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
        then coalesce(p_customer_group_id, cf.customer_group_id)
        else cf.customer_group_id
      end
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
      )
    returning
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
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file(bigint, text, text, bigint) to authenticated;

-- Redefine public.list_costing_file_items
drop function if exists public.list_costing_file_items(bigint);

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
  assigned_shipment_id bigint,
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
    cfi.assigned_shipment_id,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$$;

grant execute on function public.list_costing_file_items(bigint) to authenticated;

-- Redefine public.update_costing_file_item_enrichment
drop function if exists public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric);

create or replace function public.update_costing_file_item_enrichment(
  p_id bigint,
  p_name text,
  p_item_type text,
  p_image_url text,
  p_product_weight integer,
  p_package_weight integer,
  p_price_in_web_gbp numeric,
  p_delivery_price_gbp numeric
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
  assigned_shipment_id bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  return query
    with updated as (
      update public.costing_file_items cfi
      set
        name = coalesce(trim(p_name), cfi.name),
        item_type = coalesce(trim(p_item_type), cfi.item_type),
        image_url = coalesce(trim(p_image_url), cfi.image_url),
        product_weight = coalesce(p_product_weight, cfi.product_weight),
        package_weight = coalesce(p_package_weight, cfi.package_weight),
        price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
        delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
      where cfi.id = p_id
        and public.can_admin_manage_costing_file((select cf.tenant_id from public.costing_files cf where cf.id = cfi.costing_file_id))
      returning
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
        cfi.assigned_shipment_id,
        cfi.created_at,
        cfi.updated_at
    )
    select *
    from updated;
end;
$$;

grant execute on function public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric) to authenticated;

-- Redefine list_costing_files_for_actor to include default_shipment_id in returning JSON data
drop function if exists public.list_costing_files_for_actor(bigint, bigint, integer, integer);

create or replace function public.list_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching files
  select count(*)
  into v_total_count
  from public.costing_files cf
  where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
    and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
    and public.can_view_costing_file(cf.id);

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      public.resolve_costing_file_creator_label(
        cf.tenant_id,
        cf.customer_group_id,
        cf.created_by_email
      ) as created_by_label,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
    from public.costing_files cf
    where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
      and public.can_view_costing_file(cf.id)
    order by cf.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_costing_files_for_actor(bigint, bigint, integer, integer) to authenticated;
