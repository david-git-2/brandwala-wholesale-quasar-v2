-- Billing profiles are books-scoped (parent tenant_id). Child shops issue invoices
-- (issued_by_tenant_id = child) but reference parent-owned billing profiles.

create or replace function public.billing_profile_valid_for_issuer(
  p_billing_profile_id bigint,
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
    from public.billing_profiles bp
    where bp.id = p_billing_profile_id
      and (
        bp.tenant_id = p_issued_by_tenant_id
        or bp.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or coalesce(bp.parent_tenant_id, bp.tenant_id)
          = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = bp.tenant_id
            and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        )
      )
  );
$$;

create or replace function public.recipient_profile_valid_for_issuer(
  p_recipient_profile_id bigint,
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
    from public.recipient_profiles rp
    where rp.id = p_recipient_profile_id
      and (
        rp.tenant_id = p_issued_by_tenant_id
        or rp.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or coalesce(rp.parent_tenant_id, rp.tenant_id)
          = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = rp.tenant_id
            and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
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
  if new.billing_profile_id is not null then
    if not public.billing_profile_valid_for_issuer(
      new.billing_profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Billing profile tenant_id must match invoice issued_by_tenant_id';
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

grant execute on function public.billing_profile_valid_for_issuer(bigint, bigint) to authenticated;
grant execute on function public.recipient_profile_valid_for_issuer(bigint, bigint) to authenticated;
