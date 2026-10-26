-- list_koba_retail_products RPC
-- Returns paginated koba retail products with brand + category filter support.
-- Response shape matches the project standard: { data: [...], meta: { page, total, page_size, total_pages } }

begin;

-- Drop previous versions if they exist
drop function if exists public.list_koba_retail_products(bigint, integer, integer, text, bigint, bigint);
drop function if exists public.list_koba_retail_products(bigint, integer, integer, text, text, text);
drop function if exists public.list_koba_brands_for_tenant(bigint);
drop function if exists public.list_koba_categories_for_tenant(bigint);

-- ─── Main product list RPC ──────────────────────────────────────────────────

create function public.list_koba_retail_products(
  p_tenant_id   bigint,
  p_page        integer  default 1,
  p_page_size   integer  default 20,
  p_search      text     default null,
  p_brand_id    bigint   default null,
  p_category_id bigint   default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  with filtered as (
    select
      kp.id,
      kp.name,
      kp.sku,
      kp.barcode,
      kp.description,
      kp.stock_quantity,
      kp.in_stock,
      kp.price                   as price_gbp,
      kp.regular_price,
      kp.sale_price,
      kp.commission_percentage,
      kp.commission,
      kp.image_url,
      kp.brand_id,
      kb.name                    as brand,
      kp.category_id,
      kc.name                    as category,
      kp.created_at,
      kp.updated_at,
      count(*) over()            as total_count
    from public.koba_products kp
    left join public.koba_brands     kb on kb.id = kp.brand_id
    left join public.koba_categories kc on kc.id = kp.category_id
    where
      kp.tenant_id  = p_tenant_id
      and kp.source_type = 'retail'
      and kp.in_stock    = true
      -- search across name, sku, barcode
      and (
        coalesce(trim(p_search), '') = ''
        or kp.name    ilike ('%' || trim(p_search) || '%')
        or kp.sku     ilike ('%' || trim(p_search) || '%')
        or kp.barcode ilike ('%' || trim(p_search) || '%')
      )
      -- brand filter
      and (p_brand_id    is null or kp.brand_id    = p_brand_id)
      -- category filter
      and (p_category_id is null or kp.category_id = p_category_id)
  ),
  paged as (
    select *
    from filtered
    order by name asc, id asc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit  greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total',       coalesce(max(paged.total_count), 0),
      'page',        greatest(coalesce(p_page, 1), 1),
      'page_size',   greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric
               / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;

grant execute on function public.list_koba_retail_products(bigint, integer, integer, text, bigint, bigint)
  to authenticated, service_role;

-- ─── Brand lookup RPC ───────────────────────────────────────────────────────
-- Returns all brands that have at least one retail product in stock for the tenant.

create function public.list_koba_brands_for_tenant(
  p_tenant_id bigint
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', kb.id, 'name', kb.name)
      order by kb.name asc
    ),
    '[]'::jsonb
  )
  from public.koba_brands kb
  where kb.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.koba_products kp
      where kp.brand_id    = kb.id
        and kp.tenant_id   = p_tenant_id
        and kp.source_type = 'retail'
        and kp.in_stock    = true
    );
$$;

grant execute on function public.list_koba_brands_for_tenant(bigint)
  to authenticated, service_role;

-- ─── Category lookup RPC ─────────────────────────────────────────────────────
-- Returns all categories that have at least one retail product in stock for the tenant.

create function public.list_koba_categories_for_tenant(
  p_tenant_id bigint
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', kc.id, 'name', kc.name)
      order by kc.name asc
    ),
    '[]'::jsonb
  )
  from public.koba_categories kc
  where kc.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.koba_products kp
      where kp.category_id = kc.id
        and kp.tenant_id   = p_tenant_id
        and kp.source_type = 'retail'
        and kp.in_stock    = true
    );
$$;

grant execute on function public.list_koba_categories_for_tenant(bigint)
  to authenticated, service_role;

-- ─── Read policy for shop/app scope members ──────────────────────────────────
-- Allow tenant members (app + shop) to read retail products for their tenant.

drop policy if exists "koba_products_tenant_member_read" on public.koba_products;
create policy "koba_products_tenant_member_read"
on public.koba_products
for select
to authenticated
using (
  -- superadmin sees all
  public.is_superadmin()
  -- tenant admins/staff see their own
  or public.is_tenant_admin(tenant_id)
  -- shop/app members see their tenant's products
  or tenant_id = public.current_tenant_id()
);

commit;
