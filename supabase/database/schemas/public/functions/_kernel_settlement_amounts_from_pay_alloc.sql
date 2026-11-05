CREATE FUNCTION public._kernel_settlement_amounts_from_pay_alloc (
  p_bill        public.bills,
  p_pay         public.pays,
  p_alloc_books numeric
)
  RETURNS TABLE (
    allocated_txn_amount    numeric,
    allocated_books_amount  numeric,
    books_rate_at_alloc     numeric,
    fx_realized_books_delta numeric
  )
  LANGUAGE plpgsql
  STABLE
  AS $function$
declare
  v_books numeric(12, 2);
  v_txn numeric(12, 2);
  v_bill_rate numeric(15, 6);
  v_pay_rate numeric(15, 6);
  v_txn_ccy text;
  v_books_ccy text;
begin
  v_books := round(coalesce(p_alloc_books, 0), 2);
  v_bill_rate := coalesce(nullif(p_bill.books_exchange_rate, 0), 1.000000);
  v_txn_ccy := upper(btrim(coalesce(p_bill.txn_currency_code, p_bill.currency_code, 'BDT')));
  v_books_ccy := upper(btrim(coalesce(p_bill.currency_code, 'BDT')));

  if v_txn_ccy = v_books_ccy or v_bill_rate <= 0 then
    v_txn := v_books;
    v_pay_rate := 1.000000;
  else
    if p_pay.id is not null
       and upper(btrim(coalesce(p_pay.settlement_currency_code, 'BDT'))) <> v_books_ccy
       and coalesce(p_pay.exchange_rate, 0) > 0
    then
      v_txn := round(v_books / p_pay.exchange_rate, 2);
      v_pay_rate := p_pay.exchange_rate;
    else
      v_txn := round(v_books / v_bill_rate, 2);
      v_pay_rate := v_bill_rate;
    end if;
  end if;

  if v_txn > 0 then
    v_pay_rate := round(v_books / v_txn, 6);
  end if;

  return query
  select
    v_txn,
    v_books,
    v_pay_rate,
    v_books - round(v_txn * v_bill_rate, 2);
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_settlement_amounts_from_pay_alloc(public.bills, public.pays, numeric) TO anon;

GRANT ALL ON FUNCTION public._kernel_settlement_amounts_from_pay_alloc(public.bills, public.pays, numeric) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_settlement_amounts_from_pay_alloc(public.bills, public.pays, numeric) TO service_role;