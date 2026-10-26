-- Update bulk_add_global_shipment_items and bulk_update_global_shipment_items to support section_id

begin;

create or replace function public.bulk_add_global_shipment_items(
  p_shipment_id bigint,
  p_items jsonb
)
returns setof public.global_shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_next_sort integer;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.global_shipment_items (
      shipment_id,
      section_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id,
      sort_order
    )
    values (
      p_shipment_id,
      nullif((v_item->>'section_id'), '')::bigint,
      nullif((v_item->>'product_id'), '')::bigint,
      nullif((v_item->>'vendor_id'), '')::bigint,
      coalesce(v_item->>'name', 'Unnamed Item'),
      greatest(1, coalesce((v_item->>'ordered_quantity')::integer, 1)),
      v_item->>'image_url',
      coalesce((v_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
      greatest(0, coalesce((v_item->>'purchase_price')::numeric, 0)),
      greatest(0, coalesce((v_item->>'product_weight')::numeric, 0)),
      greatest(0, coalesce((v_item->>'package_weight')::numeric, 0)),
      v_item->>'barcode',
      v_item->>'product_code',
      nullif((v_item->>'source_child_tenant_id'), '')::bigint,
      v_item->>'source_type',
      nullif((v_item->>'source_id'), '')::bigint,
      coalesce((v_item->>'sort_order')::integer, v_next_sort)
    );

    v_next_sort := v_next_sort + 10;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$$;

create or replace function public.bulk_update_global_shipment_items(
  p_shipment_id bigint,
  p_updates jsonb
)
returns setof public.global_shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_update jsonb;
  v_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  for v_update in select * from jsonb_array_elements(p_updates)
  loop
    v_id := (v_update->>'id')::bigint;
    if v_id is not null then
      update public.global_shipment_items
      set
        section_id = case
          when v_update ? 'section_id' then nullif((v_update->>'section_id'), '')::bigint
          else section_id
        end,
        vendor_id = case
          when v_update ? 'vendor_id' then nullif((v_update->>'vendor_id'), '')::bigint
          else vendor_id
        end,
        ordered_quantity = case
          when v_update ? 'ordered_quantity' and (v_update->>'ordered_quantity') is not null then greatest(1, (v_update->>'ordered_quantity')::integer)
          else ordered_quantity
        end,
        purchase_price = case
          when v_update ? 'purchase_price' and (v_update->>'purchase_price') is not null then greatest(0, (v_update->>'purchase_price')::numeric)
          else purchase_price
        end,
        product_weight = case
          when v_update ? 'product_weight' and (v_update->>'product_weight') is not null then greatest(0, (v_update->>'product_weight')::numeric)
          else product_weight
        end,
        package_weight = case
          when v_update ? 'package_weight' and (v_update->>'package_weight') is not null then greatest(0, (v_update->>'package_weight')::numeric)
          else package_weight
        end,
        barcode = case
          when v_update ? 'barcode' then v_update->>'barcode'
          else barcode
        end,
        product_code = case
          when v_update ? 'product_code' then v_update->>'product_code'
          else product_code
        end,
        name = case
          when v_update ? 'name' and (v_update->>'name') is not null then v_update->>'name'
          else name
        end,
        updated_at = now()
      where id = v_id and shipment_id = p_shipment_id;
    end if;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$$;

commit;
