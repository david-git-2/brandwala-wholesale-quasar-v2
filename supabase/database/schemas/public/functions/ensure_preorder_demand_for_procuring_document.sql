CREATE FUNCTION public.ensure_preorder_demand_for_procuring_document (
  p_document_type text,
  p_document_id   bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
BEGIN
  IF p_document_id IS NULL THEN
    RETURN;
  END IF;

  IF v_doc_type = 'shop_order' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      parent_tenant_id,
      source_type,
      source_id,
      profile_id,
      confirmed_quantity,
      open_quantity,
      placed_quantity,
      delivered_quantity,
      vendor_placements,
      stock_picks
    )
    SELECT
      o.tenant_id,
      public.resolve_parent_tenant_id(o.tenant_id),
      'shop_order_item'::public.preorder_demand_source_type,
      oi.id,
      o.profile_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      0,
      0,
      '[]'::jsonb,
      '[]'::jsonb
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog'
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
      confirmed_quantity = excluded.confirmed_quantity,
      open_quantity = greatest(
        excluded.confirmed_quantity - coalesce(public.preorder_demand.delivered_quantity, 0),
        0
      ),
      updated_at = now();
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      parent_tenant_id,
      source_type,
      source_id,
      profile_id,
      confirmed_quantity,
      open_quantity,
      placed_quantity,
      delivered_quantity,
      vendor_placements,
      stock_picks
    )
    SELECT
      f.tenant_id,
      public.resolve_parent_tenant_id(f.tenant_id),
      'pbc_costing_item'::public.preorder_demand_source_type,
      pci.id,
      f.profile_id,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer,
      0,
      0,
      '[]'::jsonb,
      '[]'::jsonb
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    WHERE f.id = p_document_id
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
      confirmed_quantity = excluded.confirmed_quantity,
      open_quantity = greatest(
        excluded.confirmed_quantity - coalesce(public.preorder_demand.delivered_quantity, 0),
        0
      ),
      updated_at = now();
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.ensure_preorder_demand_for_procuring_document(text, bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_preorder_demand_for_procuring_document(text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_preorder_demand_for_procuring_document(text, bigint) TO service_role;