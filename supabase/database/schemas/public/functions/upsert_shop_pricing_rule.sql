CREATE FUNCTION public.upsert_shop_pricing_rule (
  p_shop_id                    bigint,
  p_markup_percentage          numeric,
  p_is_auto_publish            boolean,
  p_default_show_quantity      boolean DEFAULT true,
  p_default_add_quantity       integer DEFAULT 0,
  p_dropship_markup_percentage numeric DEFAULT 0
)
  RETURNS SETOF public.shop_pricing_rules
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity,
    default_add_quantity,
    dropship_markup_percentage
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0),
    coalesce(p_dropship_markup_percentage, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    dropship_markup_percentage = excluded.dropship_markup_percentage,
    updated_at = now()
  returning *;
end;
$function$;

CREATE FUNCTION public.upsert_shop_pricing_rule (
  p_shop_id               bigint,
  p_markup_percentage     numeric,
  p_is_auto_publish       boolean,
  p_default_show_quantity boolean DEFAULT true,
  p_default_add_quantity  integer DEFAULT 0
)
  RETURNS SETOF public.shop_pricing_rules
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity,
    default_add_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    updated_at = now()
  returning *;
end;
$function$;

CREATE FUNCTION public.upsert_shop_pricing_rule (
  p_shop_id               bigint,
  p_markup_percentage     numeric,
  p_is_auto_publish       boolean,
  p_default_show_quantity boolean DEFAULT true
)
  RETURNS SETOF public.shop_pricing_rules
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    updated_at = now()
  returning *;
end;
$function$;

CREATE FUNCTION public.upsert_shop_pricing_rule (
  p_shop_id           bigint,
  p_markup_percentage numeric,
  p_is_auto_publish   boolean
)
  RETURNS SETOF public.shop_pricing_rules
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    updated_at = now()
  returning *;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer, numeric) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer, numeric) TO service_role;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean, integer) TO service_role;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean) TO service_role;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_pricing_rule(bigint, numeric, boolean) TO service_role;