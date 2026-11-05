CREATE FUNCTION public.delivery_paper_line_apply_outcome_from_packed (
  p_splits         jsonb,
  p_move_qty       integer,
  p_outcome_status text,
  p_invoice_id     bigint  DEFAULT NULL::bigint,
  p_returned_at    text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  AS $function$
DECLARE
  v_elem jsonb;
  v_status text;
  v_qty integer;
  v_need integer;
  v_out jsonb := '[]'::jsonb;
  v_outcome_qty integer := 0;
  v_target text := lower(trim(p_outcome_status));
BEGIN
  IF p_move_qty <= 0 THEN
    RETURN coalesce(p_splits, '[]'::jsonb);
  END IF;

  IF p_move_qty > public.delivery_paper_line_packed_qty(p_splits) THEN
    RAISE EXCEPTION 'insufficient packed qty (have %, need %)',
      public.delivery_paper_line_packed_qty(p_splits), p_move_qty;
  END IF;

  v_need := p_move_qty;

  FOR v_elem IN
    SELECT value FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb))
  LOOP
    v_status := lower(trim(coalesce(v_elem->>'status', '')));
    v_qty := greatest(0, coalesce((v_elem->>'quantity')::integer, 0));
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    IF v_status = v_target THEN
      v_outcome_qty := v_outcome_qty + v_qty;
      CONTINUE;
    END IF;

    IF v_status = 'packed' AND v_need > 0 THEN
      IF v_qty <= v_need THEN
        v_need := v_need - v_qty;
        CONTINUE;
      END IF;
      v_out := v_out || jsonb_build_array(
        v_elem || jsonb_build_object('quantity', v_qty - v_need)
      );
      v_need := 0;
    ELSE
      v_out := v_out || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  v_out := v_out || jsonb_build_array(
    jsonb_strip_nulls(jsonb_build_object(
      'quantity', p_move_qty + v_outcome_qty,
      'status', v_target,
      'invoice_id', p_invoice_id,
      'returned_at', p_returned_at
    ))
  );

  IF NOT public.validate_delivery_paper_line_splits(v_out) THEN
    RAISE EXCEPTION 'invalid splits after outcome apply';
  END IF;

  RETURN v_out;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_apply_outcome_from_packed(jsonb, integer, text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_apply_outcome_from_packed(jsonb, integer, text, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_apply_outcome_from_packed(jsonb, integer, text, bigint, text) TO service_role;