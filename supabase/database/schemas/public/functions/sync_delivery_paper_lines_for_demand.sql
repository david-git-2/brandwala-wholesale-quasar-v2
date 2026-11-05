CREATE FUNCTION public.sync_delivery_paper_lines_for_demand (
  p_preorder_demand_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_pd public.preorder_demand%rowtype;
  v_source_type public.delivery_paper_source_type;
  v_source_id bigint;
  v_paper_id bigint;
  v_elem jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_split_status text;
  v_splits jsonb;
  v_paper_status public.delivery_paper_status;
BEGIN
  SELECT * INTO v_pd FROM public.preorder_demand WHERE id = p_preorder_demand_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_pd.source_type = 'shop_order_item'::public.preorder_demand_source_type THEN
    v_source_type := 'shop_order'::public.delivery_paper_source_type;
    SELECT oi.order_id INTO v_source_id
    FROM public.shop_order_items oi
    WHERE oi.id = v_pd.source_id;
  ELSE
    v_source_type := 'pbc_costing_file'::public.delivery_paper_source_type;
    SELECT pci.product_based_costing_file_id INTO v_source_id
    FROM public.product_based_costing_items pci
    WHERE pci.id = v_pd.source_id;
  END IF;

  IF v_source_id IS NULL THEN
    RETURN;
  END IF;

  SELECT dp.id INTO v_paper_id
  FROM public.delivery_paper dp
  WHERE dp.source_type = v_source_type
    AND dp.source_id = v_source_id
    AND dp.status <> 'cancelled'::public.delivery_paper_status
  ORDER BY dp.id DESC
  LIMIT 1;

  IF v_paper_id IS NULL THEN
    INSERT INTO public.delivery_paper (
      parent_tenant_id,
      source_type,
      source_id,
      profile_id,
      status
    ) VALUES (
      coalesce(v_pd.parent_tenant_id, public.resolve_parent_tenant_id(v_pd.tenant_id)),
      v_source_type,
      v_source_id,
      v_pd.profile_id,
      'draft'::public.delivery_paper_status
    )
    RETURNING id INTO v_paper_id;
  END IF;

  DELETE FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = v_paper_id
    AND dpl.preorder_demand_id = v_pd.id;

  CREATE TEMP TABLE IF NOT EXISTS _dpl_sync_splits (
    global_stock_id bigint PRIMARY KEY,
    splits jsonb NOT NULL DEFAULT '[]'::jsonb,
    note text
  ) ON COMMIT DROP;

  TRUNCATE _dpl_sync_splits;

  FOR v_elem IN
    SELECT value FROM jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
  LOOP
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce(
      nullif(v_elem->>'initial_quantity', '')::integer,
      nullif(v_elem->>'quantity', '')::integer,
      0
    );
    IF v_stock_id IS NULL OR v_qty <= 0 THEN
      CONTINUE;
    END IF;
    v_close := lower(trim(coalesce(v_elem->>'close_action', '')));
    v_split_status := public.delivery_paper_close_action_to_split_status(v_close);

    INSERT INTO _dpl_sync_splits (global_stock_id, splits, note)
    VALUES (
      v_stock_id,
      jsonb_build_array(jsonb_build_object('quantity', v_qty, 'status', v_split_status)),
      nullif(trim(coalesce(v_elem->>'note', '')), '')
    )
    ON CONFLICT (global_stock_id) DO UPDATE SET
      splits = _dpl_sync_splits.splits || EXCLUDED.splits,
      note = coalesce(_dpl_sync_splits.note, EXCLUDED.note);
  END LOOP;

  INSERT INTO public.delivery_paper_line (
    delivery_paper_id,
    preorder_demand_id,
    global_stock_id,
    splits,
    note
  )
  SELECT
    v_paper_id,
    v_pd.id,
    s.global_stock_id,
    s.splits,
    s.note
  FROM _dpl_sync_splits s;

  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM public.delivery_paper_line l
      WHERE l.delivery_paper_id = v_paper_id
        AND public.delivery_paper_line_splits_has_status(l.splits, 'packed')
    ) THEN 'packed'::public.delivery_paper_status
    WHEN EXISTS (
      SELECT 1 FROM public.delivery_paper_line l
      WHERE l.delivery_paper_id = v_paper_id
    ) THEN 'delivered'::public.delivery_paper_status
    ELSE 'draft'::public.delivery_paper_status
  END INTO v_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = v_paper_id;
END;
$function$;

GRANT ALL ON FUNCTION public.sync_delivery_paper_lines_for_demand(bigint) TO anon;

GRANT ALL ON FUNCTION public.sync_delivery_paper_lines_for_demand(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.sync_delivery_paper_lines_for_demand(bigint) TO service_role;