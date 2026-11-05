CREATE FUNCTION public.list_books_exchange_rates (
  p_parent_tenant_id    bigint,
  p_quote_currency_code text    DEFAULT NULL::text,
  p_limit               integer DEFAULT 50
)
  RETURNS TABLE (
    id                  bigint,
    base_currency_code  text,
    quote_currency_code text,
    rate                numeric,
    rate_date           timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF p_parent_tenant_id IS NULL THEN RAISE EXCEPTION 'parent_tenant_id is required'; END IF;
  IF NOT public.wallet_staff_can_view(p_parent_tenant_id) THEN RAISE EXCEPTION 'not allowed'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (upper(r.quote_currency_code))
    r.id, r.base_currency_code, r.quote_currency_code, r.rate, r.rate_date
  FROM public.books_exchange_rates r
  WHERE r.parent_tenant_id = public.resolve_parent_tenant_id(p_parent_tenant_id)
    AND (p_quote_currency_code IS NULL OR upper(r.quote_currency_code) = upper(p_quote_currency_code))
  ORDER BY upper(r.quote_currency_code), r.rate_date DESC, r.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$function$;

GRANT ALL ON FUNCTION public.list_books_exchange_rates(bigint, text, integer) TO anon;

GRANT ALL ON FUNCTION public.list_books_exchange_rates(bigint, text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_books_exchange_rates(bigint, text, integer) TO service_role;