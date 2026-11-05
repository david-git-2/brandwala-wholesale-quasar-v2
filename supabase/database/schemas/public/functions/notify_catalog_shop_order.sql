CREATE FUNCTION public.notify_catalog_shop_order (
  p_order_id        bigint,
  p_notify_staff    boolean,
  p_notify_customer boolean,
  p_event_type      text,
  p_title           text,
  p_body            text    DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
  v_customer_user_ids uuid[];
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    return;
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog'::public.shop_type_enum then
    return;
  end if;

  if p_notify_staff then
    perform public.enqueue_notification(
      p_tenant_id := v_order.tenant_id,
      p_operating_tenant_id := v_order.tenant_id,
      p_audience := 'child_only',
      p_event_type := p_event_type,
      p_title := p_title,
      p_body := p_body,
      p_link_path := format('/app/shop/orders/%s', v_order.id),
      p_entity_type := 'shop_order',
      p_entity_id := v_order.id::text,
      p_module_key := 'shop_order_mgmt',
      p_action := 'view'
    );
  end if;

  if p_notify_customer and v_order.customer_group_id is not null then
    v_customer_user_ids := public.resolve_customer_group_notification_user_ids(v_order.customer_group_id);

    if v_customer_user_ids is not null and cardinality(v_customer_user_ids) > 0 then
      perform public.enqueue_notification(
        p_tenant_id := v_order.tenant_id,
        p_operating_tenant_id := v_order.tenant_id,
        p_audience := 'assignee_only',
        p_event_type := p_event_type,
        p_title := p_title,
        p_body := p_body,
        p_link_path := format('/shop/orders/%s', v_order.id),
        p_entity_type := 'shop_order',
        p_entity_id := v_order.id::text,
        p_recipient_user_ids := v_customer_user_ids,
        p_module_key := null,
        p_action := 'view'
      );
    end if;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.notify_catalog_shop_order(bigint, boolean, boolean, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.notify_catalog_shop_order(bigint, boolean, boolean, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.notify_catalog_shop_order(bigint, boolean, boolean, text, text, text) TO service_role;