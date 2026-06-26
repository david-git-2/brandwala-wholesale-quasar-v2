-- When thrift stock is deleted, return its barcode to AVAILABLE in thrift_barcodes.

begin;

create or replace function public.release_thrift_barcode_on_stock_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.barcode is not null and trim(old.barcode) <> '' then
    update public.thrift_barcodes
    set status = 'AVAILABLE'
    where tenant_id = old.tenant_id
      and barcode_id = trim(old.barcode);
  end if;

  return old;
end;
$$;

drop trigger if exists trg_release_thrift_barcode_on_stock_delete on public.thrift_stocks;

create trigger trg_release_thrift_barcode_on_stock_delete
after delete on public.thrift_stocks
for each row
execute function public.release_thrift_barcode_on_stock_delete();

commit;
