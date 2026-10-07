-- Products trigger: vendors no longer have tenant_id (20271001140000).

create or replace function public.sync_product_tenant_from_vendor()
returns trigger
language plpgsql
as $$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.parent_tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$$;

-- Idempotent safety if 20271007100000 was skipped on a remote DB.
create or replace function public.sync_lookup_tenant_id()
returns trigger
language plpgsql
as $$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.parent_tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$$;
