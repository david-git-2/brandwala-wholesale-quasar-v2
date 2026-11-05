CREATE FUNCTION public.trg_fn_seed_new_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.seed_tenant_roles_and_grants(new.id);
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_seed_new_tenant() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_seed_new_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_seed_new_tenant() TO service_role;