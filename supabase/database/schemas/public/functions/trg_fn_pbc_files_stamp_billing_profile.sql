CREATE FUNCTION public.trg_fn_pbc_files_stamp_billing_profile()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.customer_group_id is not null then
    select bp.id
    into new.profile_id
    from public.profiles bp
    where bp.customer_group_id = new.customer_group_id;

    if new.profile_id is null then
      raise exception 'customer_group_id % has no linked customer profile', new.customer_group_id;
    end if;
  elsif tg_op = 'UPDATE' and new.customer_group_id is null and old.customer_group_id is not null then
    new.profile_id := null;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_billing_profile() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_billing_profile() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_stamp_billing_profile() TO service_role;