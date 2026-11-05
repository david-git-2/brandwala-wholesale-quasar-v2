CREATE FUNCTION public.create_and_post_stock_movement (
  p_tenant_id       bigint,
  p_stock_id        bigint,
  p_quantity        integer,
  p_to_location_id  bigint                     DEFAULT NULL::bigint,
  p_to_availability public.stock_availability  DEFAULT NULL::public.stock_availability,
  p_to_grade_tag_id bigint                     DEFAULT NULL::bigint,
  p_movement_type   public.stock_movement_type DEFAULT 'grade_change'::public.stock_movement_type,
  p_notes           text                       DEFAULT NULL::text,
  p_reference_type  text                       DEFAULT NULL::text,
  p_reference_id    text                       DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_is_customer_return boolean;
begin
  if not public.can_act_on_stock_movement_context(p_tenant_id, p_reference_type, p_reference_id) then
    raise exception 'not authorized';
  end if;

  select * into v_stock
  from public.global_stocks
  where id = p_stock_id
    and parent_tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'stock % not found', p_stock_id;
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    and coalesce(p_reference_type, '') is distinct from 'shipment_return'
  );

  if not v_is_customer_return and v_stock.quantity < p_quantity then
    raise exception 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  end if;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
    p_notes,
    public.current_user_email(),
    false,
    null
  )
  returning id into v_mov_id;

  insert into public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) values (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    case
      when v_is_customer_return then coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      else coalesce(p_to_location_id, v_stock.location_id)
    end,
    v_stock.availability,
    case
      when v_is_customer_return then coalesce(p_to_availability, 'held'::public.stock_availability)
      else coalesce(p_to_availability, v_stock.availability)
    end,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  perform public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$function$;

GRANT ALL ON FUNCTION public.create_and_post_stock_movement(bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text, text, text) TO
  anon;

GRANT ALL ON FUNCTION public.create_and_post_stock_movement(bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text, text, text) TO
  authenticated;

GRANT ALL ON FUNCTION public.create_and_post_stock_movement(bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text, text, text) TO
  service_role;