CREATE FUNCTION public.purge_shop_order_wallet_ledger (
  p_order_id   bigint,
  p_tenant_id  bigint,
  p_order_no   text,
  p_invoice_id bigint DEFAULT NULL::bigint,
  p_invoice_no text   DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.cashbook_entries;
begin
  for v_row in
    select *
    from public.cashbook_entries u
    where (
      u.source_type = 'shop_order'
      and (
        u.source_id = p_order_id::text
        or (p_order_no is not null and u.source_id = p_order_no)
        or (p_invoice_no is not null and u.source_id = p_invoice_no)
      )
    )
    or u.metadata->>'order_id' = p_order_id::text
    or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text)
  loop
    perform public._undo_wallet_ledger_row_before_delete(v_row);
  end loop;

  delete from public.cashbook_entries u
  where (
    u.source_type = 'shop_order'
    and (
      u.source_id = p_order_id::text
      or (p_order_no is not null and u.source_id = p_order_no)
      or (p_invoice_no is not null and u.source_id = p_invoice_no)
    )
  )
  or u.metadata->>'order_id' = p_order_id::text
  or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text);
end;
$function$;

GRANT ALL ON FUNCTION public.purge_shop_order_wallet_ledger(bigint, bigint, text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.purge_shop_order_wallet_ledger(bigint, bigint, text, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.purge_shop_order_wallet_ledger(bigint, bigint, text, bigint, text) TO service_role;