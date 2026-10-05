-- bills.profile_id → profiles (BP3). Invoice trigger must validate profiles, not billing_profiles.

create or replace function public.profile_valid_for_issuer(
  p_profile_id bigint,
  p_issued_by_tenant_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles pr
    where pr.id = p_profile_id
      and pr.deleted_at is null
      and (
        pr.parent_tenant_id = p_issued_by_tenant_id
        or pr.parent_tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = p_issued_by_tenant_id
            and t.parent_id = pr.parent_tenant_id
        )
      )
  );
$$;

create or replace function public.trg_validate_global_invoice_profiles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.profile_id is not null then
    if not public.profile_valid_for_issuer(
      new.profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Profile books must match invoice issued_by_tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(
      new.recipient_profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Recipient profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  return new;
end;
$$;

grant execute on function public.profile_valid_for_issuer(bigint, bigint) to authenticated;
