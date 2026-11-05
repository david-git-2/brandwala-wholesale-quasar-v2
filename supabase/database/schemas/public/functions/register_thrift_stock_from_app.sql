CREATE FUNCTION public.register_thrift_stock_from_app (
  p_tenant_id                     bigint,
  p_barcode                       text,
  p_shipment_id                   bigint,
  p_image_url                     text,
  p_brand_name                    text    DEFAULT NULL::text,
  p_category_id                   bigint  DEFAULT NULL::bigint,
  p_type_id                       bigint  DEFAULT NULL::bigint,
  p_section                       text    DEFAULT NULL::text,
  p_shelf_id                      bigint  DEFAULT NULL::bigint,
  p_color                         text    DEFAULT NULL::text,
  p_size                          text    DEFAULT NULL::text,
  p_condition                     text    DEFAULT NULL::text,
  p_box_id                        bigint  DEFAULT NULL::bigint,
  p_product_weight                numeric DEFAULT NULL::numeric,
  p_extra_weight                  numeric DEFAULT NULL::numeric,
  p_note                          text    DEFAULT NULL::text,
  p_origin_purchase_price         numeric DEFAULT NULL::numeric,
  p_extra_origin_purchase_expense numeric DEFAULT NULL::numeric,
  p_cost_of_goods_sold            numeric DEFAULT 0,
  p_target_price                  numeric DEFAULT 0,
  p_listed_price                  numeric DEFAULT 0,
  p_extra_expense_cost            numeric DEFAULT 0,
  p_inserted_by                   text    DEFAULT 'app-user'::text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_section public.thrift_section;
  v_condition public.thrift_condition;
  v_canonical_barcode text;
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

  v_section := nullif(trim(coalesce(p_section, '')), '')::public.thrift_section;
  v_condition := nullif(trim(coalesce(p_condition, '')), '')::public.thrift_condition;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  v_canonical_barcode := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_barcode);
  if v_canonical_barcode is null then
    raise exception 'Barcode not found in catalog';
  end if;

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = v_canonical_barcode
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    end if;

    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_purchase_price,
      extra_origin_purchase_expense
    )
    values (
      p_tenant_id,
      p_shipment_id,
      nullif(trim(coalesce(p_brand_name, '')), ''),
      p_category_id,
      p_type_id,
      v_section,
      p_shelf_id,
      nullif(trim(coalesce(p_color, '')), ''),
      nullif(trim(coalesce(p_size, '')), ''),
      v_condition,
      v_canonical_barcode,
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      p_origin_purchase_price,
      p_extra_origin_purchase_expense
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = nullif(trim(coalesce(p_brand_name, '')), ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = v_section,
      shelf_id = p_shelf_id,
      color = nullif(trim(coalesce(p_color, '')), ''),
      size = nullif(trim(coalesce(p_size, '')), ''),
      condition = v_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_purchase_price = p_origin_purchase_price,
      extra_origin_purchase_expense = p_extra_origin_purchase_expense,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_price,
    extra_expense_cost,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(p_listed_price, 0),
    coalesce(p_extra_expense_cost, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_price = excluded.listed_price,
    extra_expense_cost = excluded.extra_expense_cost,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  end if;

  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode;

  return v_stock_id;
end;
$function$;

CREATE FUNCTION public.register_thrift_stock_from_app (
  p_tenant_id                     bigint,
  p_barcode                       text,
  p_shipment_id                   bigint,
  p_image_url                     text,
  p_brand_name                    text,
  p_category_id                   bigint,
  p_type_id                       bigint,
  p_section                       text,
  p_shelf_id                      bigint,
  p_color                         text,
  p_size                          text,
  p_condition                     text,
  p_box_id                        bigint  DEFAULT NULL::bigint,
  p_product_weight                numeric DEFAULT NULL::numeric,
  p_extra_weight                  numeric DEFAULT NULL::numeric,
  p_note                          text    DEFAULT NULL::text,
  p_origin_purchase_price         numeric DEFAULT NULL::numeric,
  p_cost_of_goods_sold            numeric DEFAULT 0,
  p_target_price                  numeric DEFAULT 0,
  p_listed_price                  numeric DEFAULT 0,
  p_inserted_by                   text    DEFAULT 'app-user'::text,
  p_origin_unit_price             numeric DEFAULT NULL::numeric,
  p_extra_origin_unit_price       numeric DEFAULT NULL::numeric,
  p_listed_unit_price             numeric DEFAULT NULL::numeric,
  p_extra_origin_purchase_expense numeric DEFAULT NULL::numeric
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_origin_unit_price numeric := coalesce(p_origin_unit_price, p_origin_purchase_price);
  v_extra_origin_unit_price numeric := coalesce(p_extra_origin_unit_price, p_extra_origin_purchase_expense, 0);
  v_listed_unit_price numeric := coalesce(p_listed_unit_price, p_listed_price);
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode)
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = trim(p_barcode)
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    end if;

    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_unit_price,
      extra_origin_unit_price
    )
    values (
      p_tenant_id,
      p_shipment_id,
      coalesce(p_brand_name, ''),
      p_category_id,
      p_type_id,
      p_section::public.thrift_section,
      p_shelf_id,
      p_color,
      p_size,
      p_condition::public.thrift_condition,
      trim(p_barcode),
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      v_origin_unit_price,
      v_extra_origin_unit_price
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = coalesce(p_brand_name, ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = p_section::public.thrift_section,
      shelf_id = p_shelf_id,
      color = p_color,
      size = p_size,
      condition = p_condition::public.thrift_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_unit_price = v_origin_unit_price,
      extra_origin_unit_price = v_extra_origin_unit_price,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    listed_unit_price,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(v_listed_unit_price, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    listed_unit_price = excluded.listed_unit_price,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  end if;

  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode);

  return v_stock_id;
end;
$function$;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, numeric, numeric, text) TO service_role;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, text, numeric, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, text, numeric, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION
  public.register_thrift_stock_from_app(bigint, text, bigint, text, text, bigint, bigint, text, bigint, text, text, text, bigint, numeric, numeric, text, numeric, numeric, numeric,
  numeric, text, numeric, numeric, numeric, numeric) TO service_role;