CREATE FUNCTION public.ceil_thrift_retail_price (
  p_price numeric
)
  RETURNS numeric
  LANGUAGE plpgsql
  IMMUTABLE
  PARALLEL SAFE
  AS $function$
DECLARE
  n numeric;
  century numeric;
  ending numeric;
  candidate numeric;
BEGIN
  IF p_price IS NULL OR p_price <= 0 THEN
    RETURN 50;
  END IF;

  n := ceil(p_price);
  century := floor(n / 100) * 100;

  LOOP
    FOREACH ending IN ARRAY ARRAY[50, 90]::numeric[] LOOP
      candidate := century + ending;
      IF candidate >= n THEN
        RETURN candidate;
      END IF;
    END LOOP;
    century := century + 100;
  END LOOP;
END;
$function$;

COMMENT ON FUNCTION public.ceil_thrift_retail_price(numeric) IS 'Ceil to next thrift retail ending (.50 / .90); matches web ceilThriftRetailPrice.';

GRANT ALL ON FUNCTION public.ceil_thrift_retail_price(numeric) TO anon;

GRANT ALL ON FUNCTION public.ceil_thrift_retail_price(numeric) TO authenticated;

GRANT ALL ON FUNCTION public.ceil_thrift_retail_price(numeric) TO service_role;