CREATE FUNCTION public.sync_shop_order_collection_source_from_invoice()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_src public.collection_source_type;
begin
  if new.global_invoice_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.global_invoice_id is not distinct from new.global_invoice_id
     and new.collection_source is not null then
    return new;
  end if;

  select collection_source into v_src
  from public.bills
  where id = new.global_invoice_id;

  if v_src is not null then
    new.collection_source := v_src;
    if new.payout_settlement_status is null
       and new.shop_type_snapshot = 'dropship' then
      new.payout_settlement_status := 'unpaid';
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_shop_order_collection_source_from_invoice() TO anon;

GRANT ALL ON FUNCTION public.sync_shop_order_collection_source_from_invoice() TO authenticated;

GRANT ALL ON FUNCTION public.sync_shop_order_collection_source_from_invoice() TO service_role;