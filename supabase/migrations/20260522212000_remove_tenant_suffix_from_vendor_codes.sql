begin;

-- Stop appending tenant suffix into vendor code.
create or replace function public.normalize_vendor_fields()
returns trigger
language plpgsql
as $$
begin
  new.name = trim(new.name);
  new.code = upper(trim(new.code));
  new.market_code = upper(trim(new.market_code));

  if new.email is not null then
    new.email = nullif(lower(trim(new.email)), '');
  end if;

  if new.phone is not null then
    new.phone = nullif(trim(new.phone), '');
  end if;

  if new.address is not null then
    new.address = nullif(trim(new.address), '');
  end if;

  if new.website is not null then
    new.website = nullif(trim(new.website), '');
  end if;

  return new;
end;
$$;

-- Convert codes like ABC-11 back to ABC when the base code is not already used.
with normalized as (
  select
    v.id,
    upper(trim(v.code)) as current_code,
    case
      when v.tenant_id is not null
        and right(upper(trim(v.code)), length('-' || v.tenant_id::text)) = '-' || v.tenant_id::text
      then left(
        upper(trim(v.code)),
        length(upper(trim(v.code))) - length('-' || v.tenant_id::text)
      )
      else null
    end as base_code
  from public.vendors v
),
safe_updates as (
  select n.id, n.base_code
  from normalized n
  where n.base_code is not null
    and length(trim(n.base_code)) > 0
    and not exists (
      select 1
      from public.vendors v2
      where v2.id <> n.id
        and upper(trim(v2.code)) = n.base_code
    )
)
update public.vendors v
set code = s.base_code
from safe_updates s
where v.id = s.id
  and upper(trim(v.code)) <> s.base_code;

-- Keep denormalized vendor_code columns aligned with vendors.code via vendor_id.
update public.products p
set vendor_code = v.code
from public.vendors v
where p.vendor_id = v.id
  and coalesce(upper(trim(p.vendor_code)), '') <> upper(trim(v.code));

update public.shipments s
set vendor_code = v.code
from public.vendors v
where s.vendor_id = v.id
  and coalesce(upper(trim(s.vendor_code)), '') <> upper(trim(v.code));

update public.stores s
set vendor_code = v.code
from public.vendors v
where s.vendor_id = v.id
  and coalesce(upper(trim(s.vendor_code)), '') <> upper(trim(v.code));

update public.product_based_costing_files f
set vendor_code = v.code
from public.vendors v
where f.vendor_id = v.id
  and coalesce(upper(trim(f.vendor_code)), '') <> upper(trim(v.code));

update public.product_based_costing_items i
set vendor_code = v.code
from public.vendors v
where i.vendor_id = v.id
  and coalesce(upper(trim(i.vendor_code)), '') <> upper(trim(v.code));

update public.product_brands b
set vendor_code = v.code
from public.vendors v
where b.vendor_id = v.id
  and coalesce(upper(trim(b.vendor_code)), '') <> upper(trim(v.code));

update public.product_categories c
set vendor_code = v.code
from public.vendors v
where c.vendor_id = v.id
  and coalesce(upper(trim(c.vendor_code)), '') <> upper(trim(v.code));

update public.product_sync_snapshots s
set vendor_code = v.code
from public.vendors v
where s.vendor_id = v.id
  and coalesce(upper(trim(s.vendor_code)), '') <> upper(trim(v.code));

commit;
