begin;

-- =========================================================
-- P5: Parent consolidated treasury dashboard RPC
-- Aggregates posted invoices + payments across parent + children
-- =========================================================
create or replace function public.get_parent_dashboard(
  p_parent_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_revenue numeric(12,2) := 0;
  v_active_ar numeric(12,2) := 0;
  v_cash_collected numeric(12,2) := 0;
  v_unallocated_payments numeric(12,2) := 0;
  v_middleman_total numeric(12,2) := 0;
  v_middleman_liability numeric(12,2) := 0;
  v_type_distribution jsonb;
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(i.total_amount), 0),
    coalesce(sum(i.due_amount), 0),
    coalesce(sum(case when i.invoice_type = 'dropship' then i.middle_man_payout_amount else 0 end), 0),
    coalesce(sum(
      case
        when i.invoice_type = 'dropship' and i.middle_man_payout_status <> 'paid'
        then i.middle_man_payout_amount
        else 0
      end
    ), 0)
  into v_revenue, v_active_ar, v_middleman_total, v_middleman_liability
  from public.global_invoices i
  where i.parent_tenant_id = p_parent_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status;

  select
    coalesce(sum(gp.amount), 0),
    coalesce(sum(gp.unallocated_amount), 0)
  into v_cash_collected, v_unallocated_payments
  from public.global_payments gp
  where gp.tenant_id in (
    select t.id from public.tenants t
    where t.id = p_parent_tenant_id or t.parent_id = p_parent_tenant_id
  );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_type_distribution
  from (
    select
      i.invoice_type as name,
      coalesce(sum(i.total_amount), 0) as amount
    from public.global_invoices i
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
    group by i.invoice_type
  ) r;

  return jsonb_build_object(
    'totals', jsonb_build_object(
      'revenue', v_revenue,
      'cash_collected', v_cash_collected,
      'active_ar', v_active_ar,
      'unallocated_payments', v_unallocated_payments,
      'middleman_total', v_middleman_total,
      'middleman_liability', v_middleman_liability
    ),
    'type_distribution', v_type_distribution
  );
end;
$$;

grant execute on function public.get_parent_dashboard(bigint) to authenticated;

-- refresh_shipment_investor_profits delegates to get_shipment_pnl (20260831000200).
-- After ledger retirement (20260904000000), both use invoice-derived margins only.

commit;
