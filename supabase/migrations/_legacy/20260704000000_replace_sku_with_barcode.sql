begin;

-- Drop dependent constraints & triggers first
alter table public.thrift_stocks drop constraint if exists thrift_stocks_sku_tenant_unique;

-- Drop trigger & trigger function
drop trigger if exists trg_thrift_stock_loss_ledger on public.thrift_stocks;
drop function if exists public.log_thrift_stock_loss_ledger();

-- Drop sku and add barcode column
alter table public.thrift_stocks drop column if exists sku;
alter table public.thrift_stocks add column if not exists barcode text;

-- Add new unique constraint
alter table public.thrift_stocks add constraint thrift_stocks_barcode_tenant_unique unique (tenant_id, barcode);

-- Recreate trigger function using barcode
create or replace function public.log_thrift_stock_loss_ledger()
returns trigger
language plpgsql
security definer
as $$
declare
  v_cogs numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    select coalesce(cost_of_goods_sold, 0.00) into v_cogs
    from public.thrift_pricings
    where stock_id = new.id;

    if v_cogs > 0 then
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
        v_cogs * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (Barcode: ' || coalesce(new.barcode, '') || ')'
      );
    end if;
  end if;
  return new;
end;
$$;

-- Recreate trigger
create trigger trg_thrift_stock_loss_ledger
after update on public.thrift_stocks
for each row execute function public.log_thrift_stock_loss_ledger();

commit;
