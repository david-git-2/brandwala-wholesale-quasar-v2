-- Batch Code Analyze: single RPC for grid/column paste (create missing rows + merge updates).
begin;

create or replace function public.paste_batch_code_items(
  p_list_id bigint,
  p_start_row_index integer,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_tenant_id bigint;
  v_existing_count integer;
  v_needed_count integer;
  v_row_count integer;
  v_missing integer;
  v_row jsonb;
  v_offset integer;
  v_barcode text;
  v_product_code text;
  v_batch_id text;
  v_mfg date;
  v_exp date;
  v_cur public.batch_code_items%rowtype;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    return jsonb_build_object('created', 0, 'updated', 0);
  end if;

  if p_start_row_index is null or p_start_row_index < 0 then
    raise exception 'start_row_index must be >= 0';
  end if;

  select l.parent_tenant_id
  into v_parent_tenant_id
  from public.batch_code_lists l
  where l.id = p_list_id;

  if v_parent_tenant_id is null then
    raise exception 'Batch list not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_parent_tenant_id) then
    raise exception 'Access denied';
  end if;

  v_row_count := jsonb_array_length(p_rows);
  v_needed_count := p_start_row_index + v_row_count;

  select count(*)::integer
  into v_existing_count
  from public.batch_code_items
  where list_id = p_list_id;

  v_missing := greatest(0, v_needed_count - v_existing_count);

  if v_missing > 0 then
    insert into public.batch_code_items (list_id)
    select p_list_id
    from generate_series(1, v_missing);
  end if;

  for v_offset in 0..(v_row_count - 1) loop
    v_row := p_rows -> v_offset;

    select i.*
    into v_cur
    from public.batch_code_items i
    where i.list_id = p_list_id
    order by i.id
    offset p_start_row_index + v_offset
    limit 1;

    if v_cur.id is null then
      continue;
    end if;

    v_barcode := v_cur.barcode;
    v_product_code := v_cur.product_code;
    v_batch_id := v_cur.batch_id;
    v_mfg := v_cur.manufacturing_date;
    v_exp := v_cur.expire_date;

    if v_row ? 'barcode' then
      v_barcode := nullif(trim(v_row ->> 'barcode'), '');
    end if;

    if v_row ? 'product_code' then
      v_product_code := nullif(trim(v_row ->> 'product_code'), '');
    end if;

    if v_row ? 'batch_id' then
      v_batch_id := nullif(trim(v_row ->> 'batch_id'), '');
    end if;

    if v_row ? 'manufacturing_date' then
      begin
        v_mfg := nullif(trim(v_row ->> 'manufacturing_date'), '')::date;
      exception
        when others then
          v_mfg := v_cur.manufacturing_date;
      end;
    end if;

    if v_row ? 'expire_date' then
      begin
        v_exp := nullif(trim(v_row ->> 'expire_date'), '')::date;
      exception
        when others then
          v_exp := v_cur.expire_date;
      end;
    end if;

    if v_mfg is not null and v_exp is null then
      v_exp := (v_mfg + interval '36 months')::date;
    end if;

    update public.batch_code_items
    set
      barcode = v_barcode,
      product_code = v_product_code,
      batch_id = v_batch_id,
      manufacturing_date = v_mfg,
      expire_date = v_exp,
      updated_at = now()
    where id = v_cur.id;
  end loop;

  update public.batch_code_lists
  set updated_at = now()
  where id = p_list_id;

  return jsonb_build_object('created', v_missing, 'updated', v_row_count);
end;
$$;

revoke all on function public.paste_batch_code_items(bigint, integer, jsonb) from public;
grant execute on function public.paste_batch_code_items(bigint, integer, jsonb) to authenticated;

commit;
