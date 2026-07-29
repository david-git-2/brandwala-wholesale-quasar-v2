-- Migration: Update auto_create_billing_profile trigger to populate email, phone, and address

create or replace function public.trg_auto_create_billing_profile_for_customer_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.billing_profiles
    where tenant_id = new.tenant_id
      and customer_group_id = new.id
  ) then
    insert into public.billing_profiles (
      tenant_id,
      customer_group_id,
      name,
      email,
      phone,
      address,
      color,
      created_at,
      updated_at
    )
    values (
      new.tenant_id,
      new.id,
      new.name,
      null,
      null,
      null,
      new.accent_color,
      now(),
      now()
    );
  end if;
  return new;
end;
$$;
