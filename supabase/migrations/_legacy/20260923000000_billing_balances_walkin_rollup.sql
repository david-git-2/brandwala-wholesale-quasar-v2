-- Migration to fix total paid rollup scope for billing balances
-- In order to include Walk-in / Direct invoices in the customer profiles list
-- we union a special row with ID -1 representing walk-in invoices.

begin;

create or replace function public.list_billing_balances(
  p_tenant_id bigint,
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      bp.id,
      bp.name,
      bp.email,
      bp.phone,
      bp.color,
      coalesce(sum(i.due_amount), 0.00) as balance_due,
      coalesce(sum(i.total_amount), 0.00) as total_invoiced,
      coalesce(sum(i.paid_amount), 0.00) as total_paid
    from public.billing_profiles bp
    left join public.global_invoices i on i.billing_profile_id = bp.id and i.invoice_status = 'posted'::public.global_invoice_status
    where bp.tenant_id = p_tenant_id
      and (p_search is null or p_search = '' or bp.name ilike '%' || p_search || '%' or bp.email ilike '%' || p_search || '%')
    group by bp.id
    
    union all
    
    select
      -1::bigint as id,
      'Walk-in / Direct' as name,
      null::text as email,
      null::text as phone,
      '#757575' as color,
      coalesce(sum(i.due_amount), 0.00) as balance_due,
      coalesce(sum(i.total_amount), 0.00) as total_invoiced,
      coalesce(sum(i.paid_amount), 0.00) as total_paid
    from public.global_invoices i
    where i.tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.billing_profile_id is null
      and (p_search is null or p_search = '' or 'Walk-in / Direct' ilike '%' || p_search || '%')
    having count(i.id) > 0
    
    order by balance_due desc, name asc
  ) r;

  return v_data;
end;
$$;

commit;
