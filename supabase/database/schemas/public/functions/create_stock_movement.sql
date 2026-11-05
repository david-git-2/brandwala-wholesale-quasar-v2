CREATE FUNCTION public.create_stock_movement (
  p_tenant_id      bigint,
  p_movement_type  public.stock_movement_type,
  p_notes          text                       DEFAULT NULL::text,
  p_reference_type text                       DEFAULT NULL::text,
  p_reference_id   text                       DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_mov public.stock_movements%rowtype;
  v_no text;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_no := 'SM-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    p_tenant_id,
    v_no,
    p_movement_type,
    p_reference_type,
    p_reference_id,
    p_notes,
    public.current_user_email()
  )
  returning * into v_mov;

  return jsonb_build_object('movement', to_jsonb(v_mov));
end;
$function$;

GRANT ALL ON FUNCTION public.create_stock_movement(bigint, public.stock_movement_type, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_stock_movement(bigint, public.stock_movement_type, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_stock_movement(bigint, public.stock_movement_type, text, text, text) TO service_role;