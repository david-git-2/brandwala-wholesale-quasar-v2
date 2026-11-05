CREATE FUNCTION public.trg_fn_pbc_files_stamp_currency_codes()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_gbp_id bigint;
  v_bdt_id bigint;
begin
  select id into v_gbp_id from public.global_currencies where code = 'GBP' limit 1;
  select id into v_bdt_id from public.global_currencies where code = 'BDT' limit 1;

  if v_gbp_id is null then
    raise exception 'global_currencies must include GBP for product_based_costing_files defaults';
  end if;
  if v_bdt_id is null then
    raise exception 'global_currencies must include BDT for product_based_costing_files defaults';
  end if;

  if new.buy_currency_id is null then
    new.buy_currency_id := v_gbp_id;
  end if;
  if new.sell_currency_id is null then
    new.sell_currency_id := v_bdt_id;
  end if;

  select gc.code into new.buy_currency_code
    from public.global_currencies gc
   where gc.id = new.buy_currency_id;

  if new.buy_currency_code is null then
    raise exception 'unknown buy_currency_id %', new.buy_currency_id;
  end if;

  select gc.code into new.sell_currency_code
    from public.global_currencies gc
   where gc.id = new.sell_currency_id;

  if new.sell_currency_code is null then
    raise exception 'unknown sell_currency_id %', new.sell_currency_id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_currency_codes() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_currency_codes() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_currency_codes() TO service_role;