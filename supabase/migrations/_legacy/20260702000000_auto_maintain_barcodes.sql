-- =========================================================
-- Update generate_thrift_barcodes RPC to auto-maintain prefix and year
-- =========================================================

begin;

create or replace function public.generate_thrift_barcodes(
  p_tenant_id bigint,
  p_quantity integer,
  p_inserted_by text
)
returns text[]
language plpgsql
security definer
as $$
declare
  v_current_year text;
  v_latest_barcode text;
  v_prefix text;
  v_max_seq integer := 0;
  v_barcode_id text;
  v_generated text[] := array[]::text[];
  c1 integer;
  c2 integer;
  i integer;
begin
  -- Advisory lock to prevent race conditions on sequence generation for this tenant
  perform pg_advisory_xact_lock(p_tenant_id);

  -- Determine the current year (2 digits, e.g. '26')
  v_current_year := to_char(now(), 'YY');

  -- Validate quantity
  if p_quantity not in (50, 100, 150, 200, 300, 400, 500) then
    raise exception 'Quantity must be one of 50, 100, 150, 200, 300, 400, 500';
  end if;

  -- Find the latest barcode generated for the current year
  select barcode_id into v_latest_barcode
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id like '__-' || v_current_year || '-%'
  order by barcode_id desc
  limit 1;

  if v_latest_barcode is null then
    -- Start from AA for the new year
    v_prefix := 'AA';
    v_max_seq := 0;
  else
    -- Extract prefix and last sequence number
    v_prefix := substring(v_latest_barcode from 1 for 2);
    v_max_seq := substring(v_latest_barcode from 7)::integer;

    -- If sequence has reached the maximum of 999999, rollover prefix
    if v_max_seq >= 999999 then
      c1 := ascii(substring(v_prefix from 1 for 1));
      c2 := ascii(substring(v_prefix from 2 for 1));
      
      c2 := c2 + 1;
      if c2 > 90 then -- ASCII for 'Z'
        c2 := 65; -- ASCII for 'A'
        c1 := c1 + 1;
        if c1 > 90 then
          raise exception 'Maximum barcode prefix ZZ-999999 reached!';
        end if;
      end if;
      
      v_prefix := chr(c1) || chr(c2);
      v_max_seq := 0;
    end if;
  end if;

  -- Loop and insert p_quantity barcodes
  for i in 1..p_quantity loop
    v_barcode_id := v_prefix || '-' || v_current_year || '-' || lpad((v_max_seq + i)::text, 6, '0');
    
    insert into public.thrift_barcodes (
      tenant_id,
      barcode_id,
      status,
      is_printed,
      inserted_by
    )
    values (
      p_tenant_id,
      v_barcode_id,
      'AVAILABLE',
      0,
      p_inserted_by
    );
    
    v_generated := array_append(v_generated, v_barcode_id);
  end loop;

  return v_generated;
end;
$$;

-- Grant execute permission
grant execute on function public.generate_thrift_barcodes(bigint, integer, text) to authenticated;

-- Also drop old function signature if it exists to clean up
drop function if exists public.generate_thrift_barcodes(bigint, text, text, integer, text);

commit;
