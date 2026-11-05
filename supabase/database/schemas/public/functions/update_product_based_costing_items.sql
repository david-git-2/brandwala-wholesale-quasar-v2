CREATE FUNCTION public.update_product_based_costing_items (
  p_items jsonb
)
  RETURNS SETOF public.product_based_costing_items
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.update_product_based_costing_items(jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_product_based_costing_items(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_product_based_costing_items(jsonb) TO service_role;