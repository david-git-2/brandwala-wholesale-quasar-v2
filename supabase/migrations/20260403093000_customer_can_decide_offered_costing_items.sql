create or replace function public.enforce_costing_file_item_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role text;
  v_file_status public.costing_file_status;
begin
  v_actor_role := public.current_costing_item_actor_role(old.costing_file_id);

  select cf.status
  into v_file_status
  from public.costing_files cf
  where cf.id = old.costing_file_id;

  if v_actor_role = 'admin' then
    return new;
  end if;

  if v_actor_role = 'staff' then
    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.customer_profit_rate is distinct from old.customer_profit_rate
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'staff can update enrichment fields only';
    end if;

    return new;
  end if;

  if v_actor_role = 'customer' then
    if v_file_status = 'offered' then
      if new.costing_file_id is distinct from old.costing_file_id
        or new.website_url is distinct from old.website_url
        or new.quantity is distinct from old.quantity
        or new.name is distinct from old.name
        or new.image_url is distinct from old.image_url
        or new.product_weight is distinct from old.product_weight
        or new.package_weight is distinct from old.package_weight
        or new.price_in_web_gbp is distinct from old.price_in_web_gbp
        or new.delivery_price_gbp is distinct from old.delivery_price_gbp
        or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
        or new.item_price_gbp is distinct from old.item_price_gbp
        or new.cargo_rate is distinct from old.cargo_rate
        or new.costing_price_gbp is distinct from old.costing_price_gbp
        or new.costing_price_bdt is distinct from old.costing_price_bdt
        or new.offer_price_bdt is distinct from old.offer_price_bdt
        or new.offer_price_override_bdt is distinct from old.offer_price_override_bdt
        or new.customer_profit_rate is distinct from old.customer_profit_rate
        or new.created_by_email is distinct from old.created_by_email
        or new.created_at is distinct from old.created_at
      then
        raise exception 'customer can update item status only when file is offered';
      end if;

      return new;
    end if;

    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.name is distinct from old.name
      or new.image_url is distinct from old.image_url
      or new.product_weight is distinct from old.product_weight
      or new.package_weight is distinct from old.package_weight
      or new.price_in_web_gbp is distinct from old.price_in_web_gbp
      or new.delivery_price_gbp is distinct from old.delivery_price_gbp
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'customer can update customer_profit_rate only';
    end if;

    return new;
  end if;

  raise exception 'current user cannot update costing file items';
end;
$$;

create or replace function public.update_costing_file_item_status(
  p_id bigint,
  p_status public.costing_file_item_status
)
returns table(
  id bigint,
  status public.costing_file_item_status,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_file_items cfi
    set status = p_status
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'offered'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      cfi.id,
      cfi.status,
      cfi.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_item_status(bigint, public.costing_file_item_status)
to authenticated;
