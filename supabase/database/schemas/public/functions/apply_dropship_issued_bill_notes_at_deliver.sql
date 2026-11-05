CREATE FUNCTION public.apply_dropship_issued_bill_notes_at_deliver (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_plan jsonb;
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_note public.bills;
  v_ar_note_id bigint;
  v_ap_note_id bigint;
begin
  v_plan := public.preview_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_plan->>'success', 'false') <> 'true' then
    return v_plan;
  end if;

  if coalesce(v_plan->>'skipped', 'false') = 'true' then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', v_plan->>'reason');
  end if;

  v_ar_adj := v_plan->'customer_invoice';
  if v_ar_adj is not null and v_ar_adj <> 'null'::jsonb then
    perform 1 from public.bills where id = (v_ar_adj->>'bill_id')::bigint for update;
    v_note := public.create_bill_adjustment(
      (v_ar_adj->>'bill_id')::bigint,
      v_ar_adj->>'adjustment_kind',
      (v_ar_adj->>'amount')::numeric,
      v_ar_adj->>'reason',
      true
    );
    v_ar_note_id := v_note.id;
  end if;

  v_ap_adj := v_plan->'courier_ap';
  if v_ap_adj is not null and v_ap_adj <> 'null'::jsonb then
    perform 1 from public.bills where id = (v_ap_adj->>'bill_id')::bigint for update;
    v_note := public.create_bill_adjustment(
      (v_ap_adj->>'bill_id')::bigint,
      v_ap_adj->>'adjustment_kind',
      (v_ap_adj->>'amount')::numeric,
      v_ap_adj->>'reason',
      true
    );
    v_ap_note_id := v_note.id;
  end if;

  return jsonb_build_object(
    'success', true,
    'customer_invoice_id', (v_ar_adj->>'bill_id')::bigint,
    'customer_note_id', v_ar_note_id,
    'courier_ap_bill_id', (v_ap_adj->>'bill_id')::bigint,
    'courier_note_id', v_ap_note_id,
    'has_adjustments', coalesce(v_plan->>'has_adjustments', 'false') = 'true'
  );
end;
$function$;

GRANT ALL ON FUNCTION public.apply_dropship_issued_bill_notes_at_deliver(bigint) TO anon;

GRANT ALL ON FUNCTION public.apply_dropship_issued_bill_notes_at_deliver(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.apply_dropship_issued_bill_notes_at_deliver(bigint) TO service_role;