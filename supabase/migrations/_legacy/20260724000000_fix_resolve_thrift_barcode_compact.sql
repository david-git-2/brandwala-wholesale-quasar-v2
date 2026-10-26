-- Fix hyphenless barcode parsing in resolve_thrift_barcode_id_internal.
begin;

create or replace function public.resolve_thrift_barcode_id_internal(
  p_tenant_id bigint,
  p_scanned_value text
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_raw text;
  v_candidates text[] := array[]::text[];
  v_match text;
  v_tenant_prefix text;
  v_compact text[];
begin
  v_raw := upper(trim(regexp_replace(coalesce(p_scanned_value, ''), '[^A-Za-z0-9-]', '', 'g')));
  if v_raw = '' then
    return null;
  end if;

  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');
  v_candidates := array_append(v_candidates, v_raw);

  if v_raw ~ '^\d+-[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates,
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      split_part(v_raw, '-', 3) || '-' ||
      lpad(split_part(v_raw, '-', 4), 6, '0'));
  end if;

  if v_raw ~ '^[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates, v_tenant_prefix || '-' || v_raw);
    v_candidates := array_append(v_candidates,
      v_tenant_prefix || '-' ||
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      lpad(split_part(v_raw, '-', 3), 6, '0'));
  end if;

  v_compact := regexp_match(v_raw, '^(\d+)([A-Z]{2})(\d{2})(\d+)$');
  if v_compact is not null then
    v_candidates := array_append(v_candidates,
      v_compact[1] || '-' || v_compact[2] || '-' || v_compact[3] || '-' || lpad(v_compact[4], 6, '0'));
  end if;

  select b.barcode_id
  into v_match
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = any (v_candidates)
  order by b.barcode_id
  limit 1;

  return v_match;
end;
$$;

commit;
