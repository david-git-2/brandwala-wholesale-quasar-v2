CREATE FUNCTION public.update_global_invoice_header (
  p_invoice_id        bigint,
  p_discount_amount   numeric DEFAULT NULL::numeric,
  p_shipping_charge   numeric DEFAULT NULL::numeric,
  p_cod_charge        numeric DEFAULT NULL::numeric,
  p_wrapping_charge   numeric DEFAULT NULL::numeric,
  p_print_charge      numeric DEFAULT NULL::numeric,
  p_recipient_name    text    DEFAULT NULL::text,
  p_recipient_phone   text    DEFAULT NULL::text,
  p_recipient_address text    DEFAULT NULL::text,
  p_note              text    DEFAULT NULL::text,
  p_invoice_no        text    DEFAULT NULL::text,
  p_invoice_date      date    DEFAULT NULL::date
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot update header of a non-draft invoice';
  end if;

  update public.bills
  set
    discount_amount = coalesce(p_discount_amount, discount_amount),
    shipping_charge = coalesce(p_shipping_charge, shipping_charge),
    channel_meta = case
      when p_cod_charge is null then channel_meta
      else coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', p_cod_charge)
    end,
    wrapping_charge = coalesce(p_wrapping_charge, wrapping_charge),
    print_charge = coalesce(p_print_charge, print_charge),
    recipient_name = coalesce(nullif(trim(p_recipient_name), ''), recipient_name),
    recipient_phone = coalesce(nullif(trim(p_recipient_phone), ''), recipient_phone),
    recipient_address = coalesce(nullif(trim(p_recipient_address), ''), recipient_address),
    note = coalesce(nullif(trim(p_note), ''), note),
    invoice_no = coalesce(nullif(trim(p_invoice_no), ''), invoice_no),
    invoice_date = coalesce(p_invoice_date, invoice_date),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$function$;

GRANT ALL ON FUNCTION public.update_global_invoice_header(bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text, text, date) TO anon;

GRANT ALL ON FUNCTION public.update_global_invoice_header(bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text, text, date) TO authenticated;

GRANT ALL ON FUNCTION public.update_global_invoice_header(bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text, text, date) TO service_role;