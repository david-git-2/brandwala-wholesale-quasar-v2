CREATE FUNCTION public.trg_customer_groups_soft_delete_phone_unique()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    alter table public.billing_profiles disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

    update public.billing_profiles
    set is_phone_unique = false
    where customer_group_id = new.id;

    alter table public.billing_profiles enable trigger trg_billing_profiles_admin_email_unique_per_tenant;
  elsif new.deleted_at is null and old.deleted_at is not null then
    alter table public.billing_profiles disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

    update public.billing_profiles
    set is_phone_unique = true
    where customer_group_id = new.id;

    alter table public.billing_profiles enable trigger trg_billing_profiles_admin_email_unique_per_tenant;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_customer_groups_soft_delete_phone_unique() TO anon;

GRANT ALL ON FUNCTION public.trg_customer_groups_soft_delete_phone_unique() TO authenticated;

GRANT ALL ON FUNCTION public.trg_customer_groups_soft_delete_phone_unique() TO service_role;