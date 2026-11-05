-- delivery_paper_line: quantity + status → splits jsonb [{ quantity, status }, ...]

CREATE OR REPLACE FUNCTION public.validate_delivery_paper_line_splits(p_splits jsonb)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_elem jsonb;
  v_qty integer;
  v_status text;
BEGIN
  IF p_splits IS NULL OR jsonb_typeof(p_splits) <> 'array' THEN
    RETURN false;
  END IF;
  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_splits)
  LOOP
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    v_status := lower(trim(coalesce(v_elem->>'status', '')));
    IF v_qty <= 0 THEN
      RETURN false;
    END IF;
    IF v_status NOT IN ('packed', 'accepted', 'conditioned', 'rejected') THEN
      RETURN false;
    END IF;
  END LOOP;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_close_action_to_split_status(p_close_action text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE lower(trim(coalesce(p_close_action, '')))
    WHEN 'condition' THEN 'conditioned'
    WHEN 'return' THEN 'rejected'
    WHEN 'take' THEN 'accepted'
    ELSE 'packed'
  END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_line_splits_has_status(
  p_splits jsonb,
  p_status text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) elem(value)
    WHERE lower(trim(elem.value->>'status')) = lower(trim(p_status))
  );
$$;

ALTER TABLE public.delivery_paper_line
  ADD COLUMN IF NOT EXISTS splits jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE public.delivery_paper_line dpl
SET splits = jsonb_build_array(
  jsonb_build_object(
    'quantity', dpl.quantity,
    'status', dpl.status::text
  )
)
WHERE jsonb_array_length(coalesce(dpl.splits, '[]'::jsonb)) = 0
  AND dpl.quantity IS NOT NULL;

-- Merge multiple rows per (paper, demand, stock) into one row with combined splits.
WITH grouped AS (
  SELECT
    delivery_paper_id,
    preorder_demand_id,
    global_stock_id,
    min(id) AS keep_id,
    jsonb_agg(
      jsonb_build_object('quantity', quantity, 'status', status::text)
      ORDER BY id
    ) AS merged_splits,
    (array_agg(note ORDER BY id) FILTER (WHERE note IS NOT NULL))[1] AS merged_note
  FROM public.delivery_paper_line
  GROUP BY delivery_paper_id, preorder_demand_id, global_stock_id
  HAVING count(*) > 1
),
updated AS (
  UPDATE public.delivery_paper_line dpl
  SET
    splits = g.merged_splits,
    note = g.merged_note,
    updated_at = now()
  FROM grouped g
  WHERE dpl.id = g.keep_id
  RETURNING dpl.id
)
DELETE FROM public.delivery_paper_line dpl
WHERE dpl.id IN (
  SELECT dpl2.id
  FROM public.delivery_paper_line dpl2
  INNER JOIN grouped g
    ON g.delivery_paper_id = dpl2.delivery_paper_id
    AND g.preorder_demand_id = dpl2.preorder_demand_id
    AND g.global_stock_id = dpl2.global_stock_id
    AND dpl2.id <> g.keep_id
);

ALTER TABLE public.delivery_paper_line
  DROP COLUMN IF EXISTS quantity,
  DROP COLUMN IF EXISTS status;

ALTER TABLE public.delivery_paper_line
  DROP CONSTRAINT IF EXISTS delivery_paper_line_quantity_check;

ALTER TABLE public.delivery_paper_line
  DROP CONSTRAINT IF EXISTS delivery_paper_line_splits_valid;

ALTER TABLE public.delivery_paper_line
  ADD CONSTRAINT delivery_paper_line_splits_valid
  CHECK (public.validate_delivery_paper_line_splits(splits));

CREATE UNIQUE INDEX IF NOT EXISTS delivery_paper_line_paper_demand_stock_uidx
  ON public.delivery_paper_line (delivery_paper_id, preorder_demand_id, global_stock_id);

CREATE OR REPLACE FUNCTION public.sync_delivery_paper_lines_for_demand(p_preorder_demand_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.list_delivery_papers_for_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_papers jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', dp.id,
        'status', dp.status,
        'created_at', dp.created_at,
        'updated_at', dp.updated_at,
        'delivery_date', dp.delivery_date,
        'note', dp.note,
        'line_count', (
          SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
          FROM public.delivery_paper_line dpl
          WHERE dpl.delivery_paper_id = dp.id
        )
      )
      ORDER BY dp.created_at DESC, dp.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_papers
  FROM public.delivery_paper dp
  WHERE dp.source_type = v_source_type
    AND dp.source_id = p_document_id;

  RETURN jsonb_build_object('papers', v_papers);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_delivery_paper_detail(
  p_tenant_id bigint,
  p_delivery_paper_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_doc_type text;
  v_document_name text;
  v_shop_order_no text;
  v_profile_name text;
  v_items_payload jsonb;
  v_items jsonb := '[]'::jsonb;
  v_item jsonb;
  v_paper_picks jsonb;
  v_merged jsonb := '[]'::jsonb;
  i integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery paper not found'; END IF;

  v_doc_type := v_paper.source_type::text;

  IF v_paper.source_type = 'shop_order'::public.delivery_paper_source_type THEN
    SELECT
      nullif(trim(coalesce(o.name, o.order_no, '')), ''),
      nullif(trim(o.order_no), '')
    INTO v_document_name, v_shop_order_no
    FROM public.shop_orders o
    WHERE o.id = v_paper.source_id;
  ELSE
    SELECT nullif(trim(coalesce(f.name, '')), '')
    INTO v_document_name
    FROM public.product_based_costing_files f
    WHERE f.id = v_paper.source_id;
  END IF;

  SELECT pr.name INTO v_profile_name
  FROM public.profiles pr
  WHERE pr.id = v_paper.profile_id;

  v_items_payload := public.list_procurement_demand_group_items(
    p_tenant_id,
    v_doc_type,
    v_paper.source_id,
    null,
    500,
    null
  );

  v_items := coalesce(v_items_payload->'items', '[]'::jsonb);

  FOR i IN 0 .. coalesce(jsonb_array_length(v_items), 0) - 1 LOOP
    v_item := v_items->i;
    IF (v_item->>'preorder_demand_id') IS NULL THEN
      v_merged := v_merged || jsonb_build_array(v_item);
      CONTINUE;
    END IF;

    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'line_id', pr.line_id,
          'client_key', pr.client_key,
          'global_stock_id', pr.global_stock_id,
          'quantity', pr.quantity,
          'close_action', public.delivery_paper_map_line_status_to_close_action(
            pr.line_status::public.delivery_paper_line_status
          ),
          'line_status', pr.line_status,
          'is_close_split', pr.is_close_split,
          'shipment_name', pr.shipment_name,
          'location_name', pr.location_name
        )
        ORDER BY pr.line_id, pr.split_ord
      ),
      '[]'::jsonb
    )
    INTO v_paper_picks
    FROM (
      SELECT
        dpl.id AS line_id,
        ('dpl-' || dpl.id::text || '-' || split.ord::text) AS client_key,
        dpl.global_stock_id,
        (split.elem->>'quantity')::integer AS quantity,
        split.elem->>'status' AS line_status,
        (split.ord > 1) AS is_close_split,
        coalesce(nullif(trim(sh.name), ''), gsi.shipment_id::text) AS shipment_name,
        sl.name AS location_name,
        split.ord AS split_ord
      FROM public.delivery_paper_line dpl
      LEFT JOIN public.global_stocks gs ON gs.id = dpl.global_stock_id
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      LEFT JOIN public.global_shipments sh ON sh.id = gsi.shipment_id
      LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
      CROSS JOIN LATERAL jsonb_array_elements(dpl.splits) WITH ORDINALITY AS split(elem, ord)
      WHERE dpl.delivery_paper_id = p_delivery_paper_id
        AND dpl.preorder_demand_id = (v_item->>'preorder_demand_id')::bigint
    ) pr;

    v_merged := v_merged || jsonb_build_array(
      v_item || jsonb_build_object('paper_picks', coalesce(v_paper_picks, '[]'::jsonb))
    );
  END LOOP;

  RETURN jsonb_build_object(
    'paper', jsonb_build_object(
      'id', v_paper.id,
      'status', v_paper.status,
      'source_type', v_paper.source_type,
      'source_id', v_paper.source_id,
      'profile_id', v_paper.profile_id,
      'profile_name', v_profile_name,
      'document_name', v_document_name,
      'shop_order_no', v_shop_order_no,
      'created_at', v_paper.created_at,
      'updated_at', v_paper.updated_at,
      'delivery_date', v_paper.delivery_date,
      'note', v_paper.note
    ),
    'items', v_merged,
    'meta', coalesce(v_items_payload->'meta', '{}'::jsonb)
  );
END;
$$;

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
  v_demand_id bigint;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_split_status text;
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

  SELECT coalesce(sum(jsonb_array_length(s.splits)), 0)::integer
  INTO v_line_count
  FROM _dpl_save_splits s;

  v_paper_status := 'draft'::public.delivery_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'line_count', v_line_count, 'status', v_paper_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_delivery_paper_line_splits(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_close_action_to_split_status(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_line_splits_has_status(jsonb, text) TO authenticated, service_role;
