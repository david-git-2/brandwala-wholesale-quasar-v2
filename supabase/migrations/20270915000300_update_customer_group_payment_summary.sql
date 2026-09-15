-- Migration: 20270915000300_update_customer_group_payment_summary.sql
-- Description: Include total_paid and total_written_off in list_customer_groups_payment_summary

CREATE OR REPLACE FUNCTION public.list_customer_groups_payment_summary(
  p_tenant_id bigint,
  p_search text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id,
      cg.name,
      'CUST-GRP-' || lpad(cg.id::text, 4, '0') as account_code,
      coalesce(
        (select bp.phone from public.billing_profiles bp where bp.customer_group_id = cg.id and bp.phone is not null limit 1),
        '—'
      ) as phone,
      coalesce(
        (select array_agg(bp.name order by bp.name) from public.billing_profiles bp where bp.customer_group_id = cg.id),
        array[]::text[]
      ) as branches,
      coalesce(
        count(distinct si.id) filter (where si.invoice_status = 'issued' and si.due_amount > 0),
        0
      )::int as open_invoice_count,
      coalesce(
        sum(si.total_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_invoiced,
      coalesce(
        sum(si.paid_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_paid,
      coalesce(
        sum(si.written_off_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_written_off,
      coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_due,
      (
        select max(gp.payment_date)
        from public.global_payments gp
        where gp.customer_group_id = cg.id
           or gp.billing_profile_id in (select id from public.billing_profiles where customer_group_id = cg.id)
      ) as last_payment_date
    from public.customer_groups cg
    left join public.billing_profiles bp on bp.customer_group_id = cg.id
    left join public.sales_invoices si on si.billing_profile_id = bp.id
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or bp.phone ilike '%' || trim(p_search) || '%'
      )
    group by cg.id, cg.name
    order by total_due desc, cg.name asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION public.list_customer_groups_payment_summary(bigint, text, int, int) OWNER TO postgres;
