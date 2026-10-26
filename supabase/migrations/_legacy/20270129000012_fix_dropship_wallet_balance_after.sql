-- ============================================================================
-- Migration: Sync balance_after for Dropship Tenant Revenue Ledger Entries
-- ============================================================================

do $$
declare
  r record;
  v_acct_subtotal numeric(12,2);
  v_correct_revenue numeric(12,2);
begin
  for r in (
    select uwl.id as ledger_id, uwl.source_id, uwl.tenant_id, o.id as order_id,
           coalesce(o.print_charge_amount, 0) as print_chg,
           coalesce(o.packing_charge_amount, 0) as pack_chg
    from public.universal_wallet_ledger uwl
    join public.shop_orders o on (o.id::text = uwl.source_id or o.order_no = uwl.source_id)
    where uwl.source_type = 'shop_order'
      and uwl.entity_type = 'tenant'
      and uwl.metadata->>'transaction_type' = 'revenue'
      and o.shop_type_snapshot = 'dropship'
  ) loop
    select coalesce(sum(coalesce(unit_sell_price_amount, unit_list_price_amount, 0) * quantity), 0)
    into v_acct_subtotal
    from public.shop_order_items
    where order_id = r.order_id;

    v_correct_revenue := v_acct_subtotal + r.print_chg + r.pack_chg;

    update public.universal_wallet_ledger
    set amount = v_correct_revenue,
        base_amount = v_correct_revenue,
        balance_after = v_correct_revenue
    where id = r.ledger_id;
  end loop;
end $$;
