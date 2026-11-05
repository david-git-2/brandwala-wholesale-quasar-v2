CREATE FUNCTION public.thrift_stocks_enforce_hold_metadata()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF NEW.status = 'RESERVED'::public.thrift_stock_status THEN
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires held_for_phone_normalized';
    END IF;
    NEW.held_for_phone_normalized := public.normalize_thrift_phone(
      COALESCE(NEW.held_for_phone_normalized, NEW.held_for_phone)
    );
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires a non-empty customer phone';
    END IF;
    IF NEW.held_at IS NULL THEN
      NEW.held_at := NOW();
    END IF;
  ELSIF TG_OP = 'UPDATE'
    AND OLD.status = 'RESERVED'::public.thrift_stock_status
  THEN
    NEW.held_for_name := NULL;
    NEW.held_for_phone := NULL;
    NEW.held_for_phone_normalized := NULL;
    NEW.hold_note := NULL;
    NEW.held_by := NULL;
    NEW.held_at := NULL;
    NEW.hold_expires_at := NULL;
  END IF;

  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public.thrift_stocks_enforce_hold_metadata() TO anon;

GRANT ALL ON FUNCTION public.thrift_stocks_enforce_hold_metadata() TO authenticated;

GRANT ALL ON FUNCTION public.thrift_stocks_enforce_hold_metadata() TO service_role;