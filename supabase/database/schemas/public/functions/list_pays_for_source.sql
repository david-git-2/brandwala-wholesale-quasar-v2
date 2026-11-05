CREATE FUNCTION public.list_pays_for_source (
  p_parent_tenant_id bigint,
  p_source_type      text,
  p_source_id        text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_order_id bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);
  v_order_id := nullif(trim(p_source_id), '')::bigint;

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'method', p.method,
        'source', p.source,
        'profile_id', p.profile_id,
        'shop_order_id', p.shop_order_id,
        'voided_at', p.voided_at,
        'settlement_currency_code', p.settlement_currency_code,
        'foreign_amount', p.foreign_amount,
        'exchange_rate', p.exchange_rate,
        'quote_currency_code', p.quote_currency_code,
        'source_currency_code', p.source_currency_code,
        'transaction_rate', p.transaction_rate,
        'source_amount', p.source_amount
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.voided_at is null
    and (
      (
        p_source_type = 'shop_order'
        and v_order_id is not null
        and p.shop_order_id = v_order_id
      )
      or exists (
        select 1
        from public.bill_settlements bs
        join public.bills b on b.id = bs.bill_id
        where bs.allocator_kind = 'pay'
          and bs.allocator_id = p.id
          and b.parent_tenant_id = v_parent_id
          and (
            (b.source_type = p_source_type and b.source_id = p_source_id)
            or (
              p_source_type = 'shipment_cost'
              and b.invoice_type = 'ap'::public.global_invoice_type
              and (
                (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
                or (v_order_id is not null and b.ap_shipment_id = v_order_id)
              )
            )
          )
      )
    );

  return v_rows;
end;
$function$;

GRANT ALL ON FUNCTION public.list_pays_for_source(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.list_pays_for_source(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_pays_for_source(bigint, text, text) TO service_role;