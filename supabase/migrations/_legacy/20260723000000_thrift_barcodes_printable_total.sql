-- Add printable_total: barcodes with is_printed = 0 AND status = AVAILABLE.
begin;

create or replace function public.list_thrift_barcodes_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 50,
  p_search text default null,
  p_is_printed smallint default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 50), 1);
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_unprinted_total bigint;
  v_available_total bigint;
  v_printable_total bigint;
  v_latest_current_year text;
  v_current_year text := to_char(now(), 'YY');
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  select count(*)
  into v_total_count
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and (p_is_printed is null or b.is_printed = p_is_printed)
    and (v_status is null or b.status = v_status)
    and (
      v_search is null
      or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
      or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
    );

  select count(*)
  into v_unprinted_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0;

  select count(*)
  into v_available_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.status = 'AVAILABLE';

  select count(*)
  into v_printable_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0
    and b.status = 'AVAILABLE';

  select b.barcode_id
  into v_latest_current_year
  from public.thrift_barcodes b
  cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
  where b.tenant_id = p_tenant_id
    and b.barcode_id like '%-' || v_current_year || '-%'
  order by sk.sort_prefix desc, sk.sort_year desc, sk.sort_seq desc, b.barcode_id desc
  limit 1;

  select coalesce(jsonb_agg(row_data order by sort_prefix asc, sort_year asc, sort_seq asc, sort_barcode_id asc), '[]'::jsonb)
  into v_data
  from (
    select
      jsonb_build_object(
        'id', b.id,
        'tenant_id', b.tenant_id,
        'barcode_id', b.barcode_id,
        'status', b.status,
        'is_printed', b.is_printed,
        'inserted_by', b.inserted_by,
        'created_at', b.created_at,
        'updated_at', b.updated_at
      ) as row_data,
      sk.sort_prefix,
      sk.sort_year,
      sk.sort_seq,
      b.barcode_id as sort_barcode_id
    from public.thrift_barcodes b
    cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
    where b.tenant_id = p_tenant_id
      and (p_is_printed is null or b.is_printed = p_is_printed)
      and (v_status is null or b.status = v_status)
      and (
        v_search is null
        or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
        or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
      )
    order by sk.sort_prefix asc, sk.sort_year asc, sk.sort_seq asc, b.barcode_id asc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ) paged;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unprinted_total', v_unprinted_total,
      'available_total', v_available_total,
      'printable_total', v_printable_total,
      'latest_current_year_barcode_id', v_latest_current_year
    )
  );
end;
$$;

commit;
