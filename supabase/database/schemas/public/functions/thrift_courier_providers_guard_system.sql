CREATE FUNCTION public.thrift_courier_providers_guard_system()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be deleted';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be updated';
    END IF;
    IF NEW.is_system IS DISTINCT FROM FALSE OR NEW.tenant_id IS NULL THEN
      RAISE EXCEPTION 'Tenant courier providers must keep is_system=false and a tenant_id';
    END IF;
    IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
      RAISE EXCEPTION 'Cannot move courier provider across tenants';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public.thrift_courier_providers_guard_system() TO anon;

GRANT ALL ON FUNCTION public.thrift_courier_providers_guard_system() TO authenticated;

GRANT ALL ON FUNCTION public.thrift_courier_providers_guard_system() TO service_role;