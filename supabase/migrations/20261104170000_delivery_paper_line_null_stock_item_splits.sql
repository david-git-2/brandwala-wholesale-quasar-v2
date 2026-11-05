-- Item-level delivery qty (no stock lot): nullable global_stock_id + save splits on line.

DROP INDEX IF EXISTS public.delivery_paper_line_paper_demand_stock_uidx;

ALTER TABLE public.delivery_paper_line
  ALTER COLUMN global_stock_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS delivery_paper_line_paper_demand_no_stock_uidx
  ON public.delivery_paper_line (delivery_paper_id, preorder_demand_id)
  WHERE global_stock_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS delivery_paper_line_paper_demand_stock_uidx
  ON public.delivery_paper_line (delivery_paper_id, preorder_demand_id, global_stock_id)
  WHERE global_stock_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.save_delivery_paper_detail(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_elem jsonb;
  v_pick jsonb;
  v_split_elem jsonb;
  v_demand_id bigint;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_split_status text;
  v_item_splits jsonb;
  v_paper_status public.delivery_paper_status;
  v_line_count integer := 0;
  v_valid_demand boolean;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery paper not found'; END IF;
  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'only draft delivery papers can be edited';
  END IF;

  DELETE FROM public.delivery_paper_line dpl WHERE dpl.delivery_paper_id = p_delivery_paper_id;

  CREATE TEMP TABLE IF NOT EXISTS _dpl_save_splits (
    preorder_demand_id bigint NOT NULL,
    global_stock_id bigint NOT NULL,
    splits jsonb NOT NULL DEFAULT '[]'::jsonb,
    note text,
    PRIMARY KEY (preorder_demand_id, global_stock_id)
  ) ON COMMIT DROP;

  TRUNCATE _dpl_save_splits;

  IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' THEN
    FOR v_elem IN SELECT value FROM jsonb_array_elements(p_items) LOOP
      v_demand_id := nullif(v_elem->>'preorder_demand_id', '')::bigint;
      IF v_demand_id IS NULL THEN CONTINUE; END IF;

      SELECT EXISTS (
        SELECT 1
        FROM public.preorder_demand pd
        WHERE pd.id = v_demand_id
          AND (
            (
              v_paper.source_type = 'shop_order'::public.delivery_paper_source_type
              AND pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
              AND EXISTS (
                SELECT 1 FROM public.shop_order_items oi
                WHERE oi.id = pd.source_id AND oi.order_id = v_paper.source_id
              )
            )
            OR (
              v_paper.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
              AND pd.source_type = 'pbc_costing_item'::public.preorder_demand_source_type
              AND EXISTS (
                SELECT 1 FROM public.product_based_costing_items pci
                WHERE pci.id = pd.source_id
                  AND pci.product_based_costing_file_id = v_paper.source_id
              )
            )
          )
      ) INTO v_valid_demand;

      IF NOT coalesce(v_valid_demand, false) THEN
        RAISE EXCEPTION 'invalid preorder_demand_id % for this paper', v_demand_id;
      END IF;

      v_item_splits := '[]'::jsonb;
      FOR v_split_elem IN
        SELECT value FROM jsonb_array_elements(coalesce(v_elem->'splits', '[]'::jsonb))
      LOOP
        v_qty := coalesce((v_split_elem->>'quantity')::integer, 0);
        v_split_status := lower(trim(coalesce(v_split_elem->>'status', '')));
        IF v_qty <= 0 THEN CONTINUE; END IF;
        IF v_split_status NOT IN ('packed', 'accepted', 'conditioned', 'rejected') THEN
          RAISE EXCEPTION 'invalid split status: %', v_split_status;
        END IF;
        v_item_splits := v_item_splits || jsonb_build_array(
          jsonb_build_object('quantity', v_qty, 'status', v_split_status)
        );
      END LOOP;

      IF jsonb_array_length(v_item_splits) > 0
        AND coalesce(jsonb_array_length(v_elem->'picks'), 0) = 0 THEN
        INSERT INTO public.delivery_paper_line (
          delivery_paper_id,
          preorder_demand_id,
          global_stock_id,
          splits,
          note
        ) VALUES (
          p_delivery_paper_id,
          v_demand_id,
          NULL,
          v_item_splits,
          nullif(trim(coalesce(v_elem->>'note', '')), '')
        );
        v_line_count := v_line_count + jsonb_array_length(v_item_splits);
      END IF;

      FOR v_pick IN SELECT value FROM jsonb_array_elements(coalesce(v_elem->'picks', '[]'::jsonb)) LOOP
        v_stock_id := nullif(v_pick->>'global_stock_id', '')::bigint;
        v_qty := coalesce(nullif(v_pick->>'quantity', '')::integer, 0);
        IF v_stock_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

        v_close := lower(trim(coalesce(v_pick->>'close_action', '')));
        v_split_status := public.delivery_paper_close_action_to_split_status(v_close);

        INSERT INTO _dpl_save_splits (preorder_demand_id, global_stock_id, splits, note)
        VALUES (
          v_demand_id,
          v_stock_id,
          jsonb_build_array(jsonb_build_object('quantity', v_qty, 'status', v_split_status)),
          nullif(trim(coalesce(v_pick->>'note', '')), '')
        )
        ON CONFLICT (preorder_demand_id, global_stock_id) DO UPDATE SET
          splits = _dpl_save_splits.splits || EXCLUDED.splits,
          note = coalesce(_dpl_save_splits.note, EXCLUDED.note);
      END LOOP;
    END LOOP;
  END IF;

  INSERT INTO public.delivery_paper_line (
    delivery_paper_id,
    preorder_demand_id,
    global_stock_id,
    splits,
    note
  )
  SELECT
    p_delivery_paper_id,
    s.preorder_demand_id,
    s.global_stock_id,
    s.splits,
    s.note
  FROM _dpl_save_splits s;

  SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
  INTO v_line_count
  FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = p_delivery_paper_id;

  v_paper_status := 'draft'::public.delivery_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'line_count', v_line_count, 'status', v_paper_status);
END;
$$;
