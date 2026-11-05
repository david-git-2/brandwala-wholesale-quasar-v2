CREATE FUNCTION public.add_stock_movement_line (
  p_movement_id       bigint,
  p_stock_id          bigint,
  p_quantity          numeric,
  p_from_location_id  bigint                    DEFAULT NULL::bigint,
  p_to_location_id    bigint                    DEFAULT NULL::bigint,
  p_from_availability public.stock_availability DEFAULT NULL::public.stock_availability,
  p_to_availability   public.stock_availability DEFAULT NULL::public.stock_availability,
  p_from_grade_tag_id bigint                    DEFAULT NULL::bigint,
  p_to_grade_tag_id   bigint                    DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
begin
  select * into v_mov from public.stock_movements where id = p_movement_id for update;
  if not found then
    raise exception 'movement not found';
  end if;
  if v_mov.is_posted then
    raise exception 'movement already posted';
  end if;
  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;

  insert into public.stock_movement_lines (
    movement_id, stock_id, from_location_id, to_location_id,
    from_availability, to_availability, from_grade_tag_id, to_grade_tag_id, quantity
  ) values (
    p_movement_id, p_stock_id, p_from_location_id, p_to_location_id,
    p_from_availability, p_to_availability, p_from_grade_tag_id, p_to_grade_tag_id, p_quantity
  )
  returning * into v_line;

  return jsonb_build_object('line', to_jsonb(v_line));
end;
$function$;

GRANT ALL ON FUNCTION public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability, bigint, bigint) TO service_role;