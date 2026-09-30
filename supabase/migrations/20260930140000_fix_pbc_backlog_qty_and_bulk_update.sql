-- Wait-list refresh must not read dropped ordered_quantity.
-- Bulk quote-line edits go through one RPC.

create or replace function public.upsert_pbc_backlog_from_item(p_costing_item_id bigint)
returns public.product_based_costing_backlog_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.product_based_costing_items%rowtype;
  v_file public.product_based_costing_files%rowtype;
  v_prod record;
  v_confirmed_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
  v_tenant_id bigint;
  v_price_gbp numeric;
begin
  select * into v_item
  from public.product_based_costing_items
  where id = p_costing_item_id;

  if v_item.id is null then
    return null;
  end if;

  select * into v_file
  from public.product_based_costing_files
  where id = v_item.product_based_costing_file_id;

  if v_file.id is null then
    raise exception 'costing file % not found', v_item.product_based_costing_file_id;
  end if;

  v_tenant_id := v_file.tenant_id;
  if v_tenant_id is null and v_file.billing_profile_id is not null then
    select tenant_id into v_tenant_id
    from public.billing_profiles
    where id = v_file.billing_profile_id;
  end if;

  if v_tenant_id is not null and not (
    public.can_admin_manage_costing_file(v_tenant_id)
    or public.can_staff_access_costing_file(v_tenant_id)
  ) then
    raise exception 'access denied for tenant %', v_tenant_id;
  end if;

  if v_tenant_id is null or v_file.billing_profile_id is null or v_item.product_id is null then
    return null;
  end if;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_open_qty := case
    when v_item.assigned_shipment_id is not null then 0
    when coalesce(v_file.status, 'pending') in ('pending', 'offered') then v_confirmed_qty
    else 0
  end;

  if v_confirmed_qty <= 0 or v_open_qty <= 0 then
    delete from public.product_based_costing_backlog_items
    where tenant_id = v_tenant_id
      and billing_profile_id = v_file.billing_profile_id
      and product_id = v_item.product_id;
    return null;
  end if;

  select
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code as list_price_currency_code
  into v_prod
  from public.products p
  left join public.global_currencies gc on gc.id = p.list_price_currency_id
  where p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    case
      when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
        then v_prod.list_price_amount
      else null
    end
  );

  insert into public.product_based_costing_backlog_items (
    tenant_id,
    billing_profile_id,
    product_id,
    open_quantity,
    name,
    image_url,
    barcode,
    product_code,
    price_gbp,
    product_weight,
    package_weight,
    last_costing_file_id,
    last_costing_item_id,
    updated_at
  )
  values (
    v_tenant_id,
    v_file.billing_profile_id,
    v_item.product_id,
    v_open_qty,
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    v_price_gbp,
    coalesce(v_item.product_weight::numeric, v_prod.product_weight),
    coalesce(v_item.package_weight::numeric, v_prod.package_weight),
    v_file.id,
    v_item.id,
    now()
  )
  on conflict (tenant_id, billing_profile_id, product_id)
  do update set
    open_quantity = excluded.open_quantity,
    name = excluded.name,
    image_url = excluded.image_url,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    price_gbp = excluded.price_gbp,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    last_costing_file_id = excluded.last_costing_file_id,
    last_costing_item_id = excluded.last_costing_item_id,
    updated_at = now()
  returning * into v_backlog_row;

  return v_backlog_row;
end;
$$;

create or replace function public.trg_fn_auto_upsert_pbc_backlog()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_file public.product_based_costing_files%rowtype;
  v_tenant_id bigint;
  v_other_id bigint;
  v_open_qty numeric;
  v_prod record;
  v_price_gbp numeric;
  v_name text;
begin
  if tg_op = 'DELETE' then
    if old.product_id is not null and old.product_based_costing_file_id is not null then
      select * into v_file
      from public.product_based_costing_files
      where id = old.product_based_costing_file_id;

      if v_file.id is not null then
        v_tenant_id := v_file.tenant_id;
        if v_tenant_id is null and v_file.billing_profile_id is not null then
          select tenant_id into v_tenant_id
          from public.billing_profiles
          where id = v_file.billing_profile_id;
        end if;

        select pci.id into v_other_id
        from public.product_based_costing_items pci
        inner join public.product_based_costing_files pcf
          on pcf.id = pci.product_based_costing_file_id
        where pci.product_id = old.product_id
          and pcf.billing_profile_id is not distinct from v_file.billing_profile_id
        order by pci.updated_at desc nulls last, pci.id desc
        limit 1;

        if v_other_id is not null then
          perform public.upsert_pbc_backlog_from_item(v_other_id);
        elsif v_tenant_id is not null and v_file.billing_profile_id is not null then
          v_open_qty := coalesce(old.confirmed_quantity, old.quantity, 0);

          if coalesce(v_file.status, 'pending') in ('pending', 'offered')
             and v_open_qty > 0
          then
            select
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code as list_price_currency_code
            into v_prod
            from public.products p
            left join public.global_currencies gc on gc.id = p.list_price_currency_id
            where p.id = old.product_id;

            v_name := coalesce(old.name, v_prod.name);
            v_price_gbp := coalesce(
              old.price_gbp,
              case
                when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
                  then v_prod.list_price_amount
                else null
              end
            );

            if v_name is not null then
              insert into public.product_based_costing_backlog_items (
                tenant_id,
                billing_profile_id,
                product_id,
                open_quantity,
                name,
                image_url,
                barcode,
                product_code,
                price_gbp,
                product_weight,
                package_weight,
                last_costing_file_id,
                last_costing_item_id,
                updated_at
              )
              values (
                v_tenant_id,
                v_file.billing_profile_id,
                old.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(old.image_url, v_prod.image_url),
                coalesce(old.barcode, v_prod.barcode),
                coalesce(old.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(old.product_weight::numeric, v_prod.product_weight),
                coalesce(old.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                null,
                now()
              )
              on conflict (tenant_id, billing_profile_id, product_id)
              do update set
                open_quantity = excluded.open_quantity,
                name = excluded.name,
                image_url = excluded.image_url,
                barcode = excluded.barcode,
                product_code = excluded.product_code,
                price_gbp = excluded.price_gbp,
                product_weight = excluded.product_weight,
                package_weight = excluded.package_weight,
                last_costing_file_id = excluded.last_costing_file_id,
                last_costing_item_id = excluded.last_costing_item_id,
                updated_at = now();
            end if;
          else
            delete from public.product_based_costing_backlog_items
            where tenant_id = v_tenant_id
              and billing_profile_id = v_file.billing_profile_id
              and product_id = old.product_id;
          end if;
        end if;
      end if;
    end if;

    return old;
  end if;

  perform public.upsert_pbc_backlog_from_item(new.id);
  return new;
end;
$$;

create or replace function public.update_product_based_costing_items(p_items jsonb)
returns setof public.product_based_costing_items
language plpgsql
set search_path = public
as $$
declare
  v_elem jsonb;
  v_id bigint;
  v_row public.product_based_costing_items;
begin
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_elem in select value from jsonb_array_elements(p_items)
  loop
    v_id := (v_elem->>'id')::bigint;
    if v_id is null then
      raise exception 'each item must include id';
    end if;

    update public.product_based_costing_items pci
    set
      product_based_costing_file_id = case
        when v_elem ? 'product_based_costing_file_id' then (v_elem->>'product_based_costing_file_id')::bigint
        else pci.product_based_costing_file_id
      end,
      name = case when v_elem ? 'name' then nullif(v_elem->>'name', '') else pci.name end,
      image_url = case when v_elem ? 'image_url' then nullif(v_elem->>'image_url', '') else pci.image_url end,
      note = case when v_elem ? 'note' then nullif(v_elem->>'note', '') else pci.note end,
      quantity = case when v_elem ? 'quantity' then (v_elem->>'quantity')::numeric else pci.quantity end,
      barcode = case when v_elem ? 'barcode' then nullif(v_elem->>'barcode', '') else pci.barcode end,
      product_code = case when v_elem ? 'product_code' then nullif(v_elem->>'product_code', '') else pci.product_code end,
      brand = case when v_elem ? 'brand' then nullif(v_elem->>'brand', '') else pci.brand end,
      vendor_code = case when v_elem ? 'vendor_code' then nullif(v_elem->>'vendor_code', '') else pci.vendor_code end,
      market_code = case when v_elem ? 'market_code' then nullif(v_elem->>'market_code', '') else pci.market_code end,
      web_link = case when v_elem ? 'web_link' then nullif(v_elem->>'web_link', '') else pci.web_link end,
      price_gbp = case when v_elem ? 'price_gbp' then (v_elem->>'price_gbp')::numeric else pci.price_gbp end,
      product_weight = case when v_elem ? 'product_weight' then (v_elem->>'product_weight')::numeric else pci.product_weight end,
      package_weight = case when v_elem ? 'package_weight' then (v_elem->>'package_weight')::numeric else pci.package_weight end,
      confirmed_quantity = case when v_elem ? 'confirmed_quantity' then (v_elem->>'confirmed_quantity')::integer else pci.confirmed_quantity end,
      offer_price = case when v_elem ? 'offer_price' then (v_elem->>'offer_price')::numeric else pci.offer_price end,
      is_offer_price_manual = case when v_elem ? 'is_offer_price_manual' then (v_elem->>'is_offer_price_manual')::boolean else pci.is_offer_price_manual end,
      input_type = case when v_elem ? 'input_type' then nullif(v_elem->>'input_type', '') else pci.input_type end,
      assigned_shipment_id = case when v_elem ? 'assigned_shipment_id' then (v_elem->>'assigned_shipment_id')::bigint else pci.assigned_shipment_id end,
      product_id = case when v_elem ? 'product_id' then (v_elem->>'product_id')::bigint else pci.product_id end
    where pci.id = v_id
    returning * into v_row;

    if not found then
      raise exception 'costing item % was not updated', v_id;
    end if;

    return next v_row;
  end loop;

  return;
end;
$$;

grant all on function public.update_product_based_costing_items(jsonb) to authenticated;
