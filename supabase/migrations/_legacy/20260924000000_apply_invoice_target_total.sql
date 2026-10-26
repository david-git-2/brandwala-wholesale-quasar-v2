-- Migration: Invoice Target-Total Adjuster
-- Spread a desired final total across draft invoice line prices (weight-by-line-value).
-- Dry-run returns the proposed per-line change without writing; otherwise commits and recomputes.
begin;

create or replace function public.apply_global_invoice_target_total(
  p_invoice_id bigint,
  p_target_total numeric,
  p_dry_run boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_is_dropship boolean;
  v_charges_sum numeric(12,2);
  v_target_line_subtotal numeric(12,2);
  v_current_subtotal numeric(12,2);
  v_current_total numeric(12,2);
  v_count integer;
  v_index integer := 0;
  v_running numeric(12,2) := 0.00;
  v_share numeric(12,2);
  v_base numeric(12,2);
  v_old_price numeric(12,2);
  v_new_price numeric(12,2);
  v_item record;
  v_lines jsonb := '[]'::jsonb;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot adjust totals on a non-draft invoice';
  end if;
  if p_target_total is null or p_target_total < 0 then
    raise exception 'target total must be 0 or greater';
  end if;

  v_is_dropship := v_invoice.invoice_type = 'dropship'::public.global_invoice_type;
  v_charges_sum := coalesce(v_invoice.shipping_charge, 0.00)
    + coalesce(v_invoice.cod_charge, 0.00)
    + coalesce(v_invoice.wrapping_charge, 0.00)
    + coalesce(v_invoice.print_charge, 0.00);

  -- Only merchandise lines flex; charges and header discount stay fixed.
  v_target_line_subtotal := round(p_target_total - v_charges_sum + coalesce(v_invoice.discount_amount, 0.00), 2);
  if v_target_line_subtotal < 0 then
    raise exception 'target total too low: charges and discount leave no room for item prices';
  end if;

  select
    count(*),
    coalesce(sum(case when v_is_dropship then line_face_total_amount else line_total_amount end), 0.00)
  into v_count, v_current_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  if v_count = 0 then raise exception 'invoice has no items to adjust'; end if;
  if v_current_subtotal <= 0 then
    raise exception 'current item subtotal is zero; cannot spread proportionally';
  end if;

  v_current_total := round(
    (case when v_is_dropship then coalesce(v_invoice.face_subtotal_amount, 0.00) else coalesce(v_invoice.subtotal_amount, 0.00) end)
    + v_charges_sum - coalesce(v_invoice.discount_amount, 0.00), 2);

  for v_item in
    select id, name_snapshot, quantity, sell_price_amount, recipient_price_amount,
           line_total_amount, line_face_total_amount, line_discount_amount
    from public.global_invoice_items
    where invoice_id = p_invoice_id
    order by id asc
  loop
    v_index := v_index + 1;
    v_base := case when v_is_dropship then v_item.line_face_total_amount else v_item.line_total_amount end;
    v_old_price := case when v_is_dropship then v_item.recipient_price_amount else v_item.sell_price_amount end;

    -- Weight by current line value; last line absorbs the rounding remainder so the sum is exact.
    if v_index = v_count then
      v_share := round(v_target_line_subtotal - v_running, 2);
    else
      v_share := round(v_target_line_subtotal * (v_base / v_current_subtotal), 2);
      v_running := v_running + v_share;
    end if;

    if v_share < 0 then
      raise exception 'target total too low: item "%" would need a negative line total', v_item.name_snapshot;
    end if;

    v_new_price := round((v_share + coalesce(v_item.line_discount_amount, 0.00)) / v_item.quantity, 2);
    if v_new_price < 0 then
      raise exception 'target total too low: item "%" would need a negative price', v_item.name_snapshot;
    end if;

    v_lines := v_lines || jsonb_build_object(
      'item_id', v_item.id,
      'name', v_item.name_snapshot,
      'quantity', v_item.quantity,
      'old_price', v_old_price,
      'new_price', v_new_price,
      'unit_delta', round(v_new_price - v_old_price, 2),
      'line_delta', round(v_share - v_base, 2)
    );

    if not p_dry_run then
      if v_is_dropship then
        update public.global_invoice_items
        set recipient_price_amount = v_new_price,
            line_face_total_amount = v_share
        where id = v_item.id;
      else
        update public.global_invoice_items
        set sell_price_amount = v_new_price,
            line_total_amount = v_share
        where id = v_item.id;
      end if;
    end if;
  end loop;

  if not p_dry_run then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  return jsonb_build_object(
    'current_total', v_current_total,
    'target_total', round(p_target_total, 2),
    'adjustment', round(p_target_total - v_current_total, 2),
    'is_dropship', v_is_dropship,
    'lines', v_lines
  );
end;
$$;

grant execute on function public.apply_global_invoice_target_total(bigint, numeric, boolean) to authenticated;

commit;
