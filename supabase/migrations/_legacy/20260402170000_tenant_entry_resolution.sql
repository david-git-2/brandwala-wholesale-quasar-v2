-- =========================================================
-- Tenant entry resolution for Step 2 routing
-- Allows frontend route context resolution before login by
-- tenant slug or mapped public_domain hostname.
-- =========================================================

drop function if exists public.resolve_tenant_for_entry(text, text);

create function public.resolve_tenant_for_entry(
  p_slug text default null,
  p_hostname text default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  with normalized_input as (
    select
      nullif(lower(trim(coalesce(p_slug, ''))), '') as tenant_slug,
      nullif(
        regexp_replace(
          lower(
            trim(
              split_part(
                regexp_replace(coalesce(p_hostname, ''), '^https?://', '', 'i'),
                '/',
                1
              )
            )
          ),
          ':\d+$',
          ''
        ),
        ''
      ) as hostname
  )
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  cross join normalized_input i
  where (
    i.hostname is not null
    and lower(trim(coalesce(t.public_domain, ''))) = i.hostname
  )
  or (
    i.tenant_slug is not null
    and lower(trim(t.slug)) = i.tenant_slug
  )
  order by
    case
      when i.hostname is not null
        and lower(trim(coalesce(t.public_domain, ''))) = i.hostname then 0
      when i.tenant_slug is not null
        and lower(trim(t.slug)) = i.tenant_slug then 1
      else 2
    end,
    t.id asc
  limit 1;
$$;

grant execute on function public.resolve_tenant_for_entry(text, text)
to anon, authenticated;
