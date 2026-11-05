CREATE FUNCTION public.trg_customer_groups_guard_administer_active()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if old.is_active is distinct from new.is_active then
    if not public.can_administer_customer_group(old.tenant_id) then
      raise exception 'Only parent tenant admins can activate or deactivate customer groups';
    end if;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_customer_groups_guard_administer_active() TO anon;

GRANT ALL ON FUNCTION public.trg_customer_groups_guard_administer_active() TO authenticated;

GRANT ALL ON FUNCTION public.trg_customer_groups_guard_administer_active() TO service_role;