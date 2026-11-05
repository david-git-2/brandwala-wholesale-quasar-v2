CREATE FUNCTION public.generate_shop_order_number (
  p_tenant_id bigint,
  p_shop_id   bigint
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order_no text;
begin
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');
  return v_order_no;
end;
$function$;

GRANT ALL ON FUNCTION public.generate_shop_order_number(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.generate_shop_order_number(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.generate_shop_order_number(bigint, bigint) TO service_role;