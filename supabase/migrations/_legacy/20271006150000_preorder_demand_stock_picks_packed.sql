-- Restore stock_picks updates on packed tab (regression from ready_for_shipment rename).

CREATE OR REPLACE FUNCTION "public"."upsert_preorder_demand"("p_tenant_id" bigint, "p_source_type" "public"."preorder_demand_source_type", "p_source_id" bigint, "p_vendor_id" bigint DEFAULT NULL::bigint, "p_placed_quantity" integer DEFAULT NULL::integer, "p_stock_picks" "jsonb" DEFAULT NULL::"jsonb", "p_notes" "text" DEFAULT NULL::"text") RETURNS "public"."preorder_demand"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1 from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand line';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for preorder demand updates';
  end if;

  if p_placed_quantity is not null and v_doc_status <> 'procuring' then
    raise exception 'placed_quantity can only be updated while procuring';
  end if;

  if p_stock_picks is not null and v_doc_status not in ('procuring', 'packed') then
    raise exception 'stock_picks can only be updated while procuring or packed';
  end if;

  if p_placed_quantity is not null and coalesce(p_placed_quantity, 0) < 0 then
    raise exception 'placed_quantity cannot be negative';
  end if;

  if p_stock_picks is not null and not public.validate_preorder_stock_picks(p_stock_picks) then
    raise exception 'invalid stock_picks payload';
  end if;

  v_delivered := case
    when p_stock_picks is not null then public.sum_preorder_stock_picks(p_stock_picks)
    else null
  end;

  select pd.* into v_row
  from public.preorder_demand pd
  where pd.source_type = p_source_type
    and pd.source_id = p_source_id;

  if found then
    v_placed := coalesce(p_placed_quantity, v_row.placed_quantity, 0);
  else
    v_placed := coalesce(p_placed_quantity, 0);
  end if;

  if v_delivered is not null and v_delivered > coalesce(v_open_qty, 0) then
    raise exception 'delivered_quantity cannot exceed need quantity';
  end if;

  insert into public.preorder_demand (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    stock_picks,
    notes,
    updated_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, case when found then v_row.vendor_id else null end),
    v_placed,
    coalesce(v_delivered, case when found then v_row.delivered_quantity else 0 end, 0),
    coalesce(p_stock_picks, case when found then v_row.stock_picks else '[]'::jsonb end, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), case when found then v_row.notes else null end),
    auth.uid()
  )
  on conflict (source_type, source_id) do update set
    vendor_id = case when p_vendor_id is not null then p_vendor_id else preorder_demand.vendor_id end,
    placed_quantity = case when p_placed_quantity is not null then p_placed_quantity else preorder_demand.placed_quantity end,
    delivered_quantity = case when v_delivered is not null then v_delivered else preorder_demand.delivered_quantity end,
    stock_picks = case when p_stock_picks is not null then p_stock_picks else preorder_demand.stock_picks end,
    notes = case when p_notes is not null then nullif(trim(p_notes), '') else preorder_demand.notes end,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;
