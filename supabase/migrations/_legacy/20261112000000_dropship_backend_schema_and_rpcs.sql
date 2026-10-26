-- =========================================================
-- Migration: Create courier_services table, extend shop_orders/shops, 
-- create middle_man_payout_ledger, and define dropship RPCs
-- =========================================================

begin;

-- 1. Create courier_services catalog
create table if not exists public.courier_services (
  id uuid primary key default gen_random_uuid(),
  tenant_id bigint references public.tenants(id) on delete cascade, -- null for platform default catalog
  code text not null unique,
  name text not null,
  is_active boolean not null default true,

  -- COD Fee Policy
  cod_fee_mode text not null default 'percent_of_collect' check (cod_fee_mode in ('none', 'percent_of_collect', 'flat', 'tiered_manual')),
  cod_fee_percent numeric(5,2) default 0.00,
  cod_fee_flat_amount numeric(12,2) default 0.00,
  cod_fee_notes text,
  deduct_cod_from_margin_default boolean not null default false,

  -- Delivery & Return Charges (matching DropshipCouriersPage.vue)
  inside_dhaka_fee numeric(12,2) not null default 60.00,
  outside_dhaka_fee numeric(12,2) not null default 120.00,
  inside_dhaka_return_fee numeric(12,2) default 30.00,
  outside_dhaka_return_fee numeric(12,2) default 60.00,
  
  -- Return Policy Rules
  return_fee_mode text not null default 'flat' check (return_fee_mode in ('none', 'percent_of_forward', 'flat', 'tiered_manual')),
  return_fee_percent numeric(5,2) default 0.00,

  -- Operational Constraints
  delivery_attempt_count int not null default 2,
  hub_hold_days int not null default 3,
  open_box_default_allowed boolean not null default false,
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Seed Default Couriers (Steadfast, Pathao, REDX)
insert into public.courier_services (code, name, cod_fee_mode, cod_fee_percent, inside_dhaka_fee, outside_dhaka_fee, inside_dhaka_return_fee, outside_dhaka_return_fee, delivery_attempt_count, hub_hold_days, open_box_default_allowed, notes)
values
  ('steadfast', 'Steadfast Courier', 'percent_of_collect', 1.00, 60.00, 120.00, 0.00, 0.00, 3, 2, false, 'No extra return charge on standard returns'),
  ('pathao', 'Pathao Courier', 'percent_of_collect', 1.00, 60.00, 120.00, 0.00, 60.00, 2, 2, false, '50% return fee outside Dhaka'),
  ('redx', 'REDX Courier', 'percent_of_collect', 1.00, 60.00, 130.00, 30.00, 65.00, 2, 3, false, 'Tiered return policy')
on conflict (code) do update set
  name = excluded.name,
  inside_dhaka_fee = excluded.inside_dhaka_fee,
  outside_dhaka_fee = excluded.outside_dhaka_fee,
  inside_dhaka_return_fee = excluded.inside_dhaka_return_fee,
  outside_dhaka_return_fee = excluded.outside_dhaka_return_fee;

-- 2. Extend shop_orders with dropship consignment & settlement fields
alter table public.shop_orders
  add column if not exists recipient_name text,
  add column if not exists recipient_phone text,
  add column if not exists shipping_address text,
  add column if not exists package_weight_band text default 'under_1kg',
  add column if not exists item_category text,
  add column if not exists parcel_description text,
  add column if not exists courier_order_ref text,
  add column if not exists delivery_zone text check (delivery_zone in ('inside_dhaka', 'outside_dhaka')),
  add column if not exists payout_account_type text default 'bank',
  add column if not exists payout_account_info text,
  add column if not exists delivery_instruction_notes text,
  add column if not exists courier_tracking_number text,
  add column if not exists courier_consignment_id text,
  add column if not exists courier_cost_amount numeric(12,2) default 0.00,
  add column if not exists middle_man_reference text,
  add column if not exists courier_remittance_ref text,
  add column if not exists courier_bank_trx_id text,
  add column if not exists replacement_of_order_id bigint references public.shop_orders(id),
  add column if not exists return_charge_amount numeric(12,2) default 0.00,
  add column if not exists deduct_return_charge_from_middle_man boolean default true,
  add column if not exists global_invoice_id bigint references public.global_invoices(id);

-- 3. Create middle_man_payout_ledger table
create table if not exists public.middle_man_payout_ledger (
  id uuid primary key default gen_random_uuid(),
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  customer_group_member_id uuid not null,
  shop_order_id bigint references public.shop_orders(id) on delete set null,
  global_invoice_id bigint references public.global_invoices(id) on delete set null,
  
  entry_type text not null check (entry_type in (
    'profit_credit',          -- Profit credit from dual invoice
    'return_fee_invoiced',    -- Post-invoice return charge
    'return_fee_uninvoiced',  -- Pre-invoice refused delivery charge
    'clawback',               -- Post-payout adjustment
    'payout_paid'             -- Paid out to middle man
  )),
  
  amount numeric(12,2) not null,
  balance_after numeric(12,2) not null,
  reference_notes text,
  created_by uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_payout_ledger_member on public.middle_man_payout_ledger(tenant_id, customer_group_member_id);

-- Grants
grant all on public.courier_services to authenticated;
grant all on public.courier_services to service_role;
grant all on public.middle_man_payout_ledger to authenticated;
grant all on public.middle_man_payout_ledger to service_role;

-- 4. RPC: update_dropship_consignment
create or replace function public.update_dropship_consignment(
  p_order_id bigint,
  p_cod_collect_amount numeric default 0.00,
  p_package_weight_band text default 'under_1kg',
  p_item_category text default null,
  p_parcel_description text default null,
  p_courier_order_ref text default null,
  p_delivery_zone text default 'inside_dhaka',
  p_sender_name text default null,
  p_pickup_phone text default null,
  p_pickup_address text default null,
  p_payout_account_type text default 'bank',
  p_payout_account_info text default null,
  p_allow_open_box boolean default false,
  p_delivery_instruction_notes text default null,
  p_courier_service_id uuid default null,
  p_courier_tracking_number text default null,
  p_courier_awb_number text default null,
  p_courier_consignment_id text default null,
  p_tracking_url text default null,
  p_courier_cost_amount numeric default 0.00
)
returns jsonb
language plpgsql
security definer
as $$
begin
  update public.shop_orders
  set
    cod_collect_amount = p_cod_collect_amount,
    package_weight_band = p_package_weight_band,
    item_category = p_item_category,
    parcel_description = p_parcel_description,
    courier_order_ref = coalesce(p_courier_order_ref, order_no),
    delivery_zone = p_delivery_zone,
    sender_name = p_sender_name,
    pickup_phone = p_pickup_phone,
    pickup_address = p_pickup_address,
    payout_account_type = p_payout_account_type,
    payout_account_info = p_payout_account_info,
    allow_open_box = p_allow_open_box,
    delivery_instruction_notes = p_delivery_instruction_notes,
    courier_service_id = p_courier_service_id,
    courier_tracking_number = p_courier_tracking_number,
    courier_awb_number = p_courier_awb_number,
    courier_consignment_id = p_courier_consignment_id,
    tracking_url = p_tracking_url,
    courier_cost_amount = p_courier_cost_amount,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true);
end;
$$;

-- 5. RPC: advance_dropship_order_status
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_current_status public.shop_order_status;
begin
  select status into v_current_status from public.shop_orders where id = p_order_id;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

-- 6. RPC: mark_dropship_order_returned
create or replace function public.mark_dropship_order_returned(
  p_order_id bigint,
  p_actual_return_charge numeric,
  p_deduct_from_middle_man boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
  v_customer_group_member_id uuid;
  v_global_invoice_id bigint;
  v_prev_balance numeric := 0.00;
  v_new_balance numeric;
begin
  select tenant_id, customer_group_member_id, global_invoice_id
  into v_tenant_id, v_customer_group_member_id, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  -- 1. Update Order Status
  update public.shop_orders
  set
    status = 'returned',
    returned_at = now(),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man
  where id = p_order_id;

  -- 2. If Uninvoiced & Middle Man Bears Return Fee -> Record Ledger Debit
  if v_global_invoice_id is null and p_deduct_from_middle_man and p_actual_return_charge > 0 then
    select coalesce(balance_after, 0.00) into v_prev_balance
    from public.middle_man_payout_ledger
    where tenant_id = v_tenant_id and customer_group_member_id = v_customer_group_member_id
    order by created_at desc limit 1;

    v_new_balance := v_prev_balance - p_actual_return_charge;

    insert into public.middle_man_payout_ledger (
      tenant_id, customer_group_member_id, shop_order_id, entry_type, amount, balance_after, reference_notes
    ) values (
      v_tenant_id, v_customer_group_member_id, p_order_id, 'return_fee_uninvoiced', -p_actual_return_charge, v_new_balance, coalesce(p_reason, 'Failed delivery return fee')
    );
  end if;

  return jsonb_build_object('success', true);
end;
$$;

commit;
