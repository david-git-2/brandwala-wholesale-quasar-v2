CREATE FUNCTION public._validate_stock_location_nesting (
  p_kind               public.stock_location_kind,
  p_parent_location_id bigint,
  p_parent_tenant_id   bigint
)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent public.stock_locations%rowtype;
begin
  if p_kind in ('warehouse', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'warehouse and returns must be top-level (no parent)';
    end if;
    return;
  end if;

  if p_parent_location_id is null then
    raise exception '% requires a parent location', p_kind;
  end if;

  select * into v_parent
  from public.stock_locations
  where id = p_parent_location_id;

  if not found then
    raise exception 'parent location not found';
  end if;

  if v_parent.parent_tenant_id <> p_parent_tenant_id then
    raise exception 'parent location belongs to another tenant';
  end if;

  if p_kind = 'zone' then
    if v_parent.kind not in ('warehouse', 'returns') then
      raise exception 'zone parent must be a warehouse or returns area';
    end if;
  elsif p_kind = 'shelf' then
    if v_parent.kind <> 'zone' then
      raise exception 'shelf parent must be a zone';
    end if;
  elsif p_kind = 'level' then
    if v_parent.kind <> 'shelf' then
      raise exception 'level parent must be a shelf';
    end if;
  elsif p_kind = 'bin' then
    if v_parent.kind <> 'level' then
      raise exception 'bin parent must be a level';
    end if;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public._validate_stock_location_nesting(public.stock_location_kind, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public._validate_stock_location_nesting(public.stock_location_kind, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public._validate_stock_location_nesting(public.stock_location_kind, bigint, bigint) TO service_role;