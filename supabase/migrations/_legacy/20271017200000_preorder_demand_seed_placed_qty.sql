-- Seed placed_quantity from line need when demand rows are created; backfill procuring rows still at 0.

CREATE OR REPLACE FUNCTION public.ensure_preorder_demand_for_procuring_document(
  p_document_type text,
  p_document_id bigint
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
BEGIN
  IF p_document_id IS NULL THEN
    RETURN;
  END IF;

  IF v_doc_type = 'shop_order' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    SELECT
      o.tenant_id,
      'shop_order_item'::public.preorder_demand_source_type,
      oi.id,
      o.profile_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      0,
      '[]'::jsonb
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog'
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    SELECT
      f.tenant_id,
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
      0,
      '[]'::jsonb
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    WHERE f.id = p_document_id
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  END IF;
END;
$$;

UPDATE public.preorder_demand pd
SET
  placed_quantity = greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
  updated_at = now()
FROM public.shop_order_items oi
INNER JOIN public.shop_orders o ON o.id = oi.order_id
WHERE pd.source_type = 'shop_order_item'
  AND pd.source_id = oi.id
  AND pd.placed_quantity = 0
  AND o.shop_type_snapshot = 'vendor_catalog'
  AND public.normalize_shop_order_procurement_status(o.status) = 'procuring';

UPDATE public.preorder_demand pd
SET
  placed_quantity = greatest(
    CASE
      WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
      ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
    END,
    0
  )::integer,
  updated_at = now()
FROM public.product_based_costing_items pci
INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
WHERE pd.source_type = 'pbc_costing_item'
  AND pd.source_id = pci.id
  AND pd.placed_quantity = 0
  AND f.profile_id IS NOT NULL
  AND public.normalize_pbc_procurement_status(f.status) = 'procuring';
