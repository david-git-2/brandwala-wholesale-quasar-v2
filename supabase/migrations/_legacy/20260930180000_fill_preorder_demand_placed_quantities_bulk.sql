-- Bulk-fill placed_quantity = demand need qty for every line on a demand document group.

CREATE OR REPLACE FUNCTION public.fill_preorder_demand_placed_quantities_for_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for placed quantity updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer as need_qty
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.billing_profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated
  );
end;
$$;

GRANT ALL ON FUNCTION public.fill_preorder_demand_placed_quantities_for_document(bigint, text, bigint) TO authenticated;
