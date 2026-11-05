CREATE FUNCTION public.log_thrift_stock_loss_ledger()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_landed numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.id), 0.00);

    if v_landed > 0 then
      insert into public.thrift_accounting_ledger (
        tenant_id,
        type,
        source,
        reference_id,
        amount,
        inserted_by,
        note
      )
      values (
        new.tenant_id,
        'LOSS'::public.thrift_ledger_type,
        'SHIPMENT'::public.thrift_ledger_source,
        new.shipment_id,
        v_landed * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (Barcode: ' || coalesce(new.barcode, '') || ')'
      );
    end if;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.log_thrift_stock_loss_ledger() TO anon;

GRANT ALL ON FUNCTION public.log_thrift_stock_loss_ledger() TO authenticated;

GRANT ALL ON FUNCTION public.log_thrift_stock_loss_ledger() TO service_role;