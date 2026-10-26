-- Allow quantity 0 on close_split stock pick rows (in-progress split allocation).

CREATE OR REPLACE FUNCTION "public"."validate_preorder_stock_picks"("p_stock_picks" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_elem jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_close_action text;
  v_is_close_split boolean;
begin
  if p_stock_picks is null then
    return true;
  end if;
  if jsonb_typeof(p_stock_picks) <> 'array' then
    return false;
  end if;

  for v_elem in select value from jsonb_array_elements(p_stock_picks)
  loop
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    v_is_close_split := coalesce((v_elem->>'close_split')::boolean, false);
    if v_stock_id is null then
      return false;
    end if;
    if v_is_close_split then
      if v_qty < 0 then
        return false;
      end if;
    elsif v_qty <= 0 then
      return false;
    end if;
    v_close_action := lower(trim(coalesce(v_elem->>'close_action', '')));
    if v_close_action <> ''
      and v_close_action not in ('take', 'condition', 'return') then
      return false;
    end if;
  end loop;

  return true;
end;
$$;
