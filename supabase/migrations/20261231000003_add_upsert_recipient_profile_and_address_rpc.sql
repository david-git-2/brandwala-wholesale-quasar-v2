-- Migration: Add function alias upsert_recipient_profile_and_address for upsert_recipient_profile_by_phone
begin;

create or replace function public.upsert_recipient_profile_and_address(
  p_tenant_id bigint,
  p_name text,
  p_phone text,
  p_phone_secondary text default null,
  p_address text default null,
  p_district text default null,
  p_thana text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.upsert_recipient_profile_by_phone(
    p_tenant_id => p_tenant_id,
    p_name => p_name,
    p_phone => p_phone,
    p_secondary_phone => p_phone_secondary,
    p_address => p_address,
    p_district => p_district,
    p_thana => p_thana
  );
end;
$$;

grant execute on function public.upsert_recipient_profile_and_address(bigint, text, text, text, text, text, text) to authenticated;

commit;
