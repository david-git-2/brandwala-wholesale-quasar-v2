CREATE FUNCTION public.list_open_invoices_for_payment (
  p_tenant_id         bigint,
  p_customer_group_id bigint  DEFAULT NULL::bigint,
  p_search            text    DEFAULT NULL::text,
  p_limit             integer DEFAULT 50,
  p_offset            integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      cg.id as customer_group_id,
      coalesce(cg.name, bp.name, si.recipient_name, 'Direct Customer') as customer_group_name,
      coalesce(bp.name, 'Main Outlet') as branch_name,
      si.invoice_date,
      si.due_date,
      si.total_amount,
      si.paid_amount,
      si.written_off_amount,
      si.due_amount,
      si.payment_status
    from public.bills si
    left join public.billing_profiles bp on bp.id = si.profile_id
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
      and si.invoice_status = 'issued'
      and si.due_amount > 0
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or si.invoice_no ilike '%' || trim(p_search) || '%'
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or si.recipient_name ilike '%' || trim(p_search) || '%'
      )
    order by si.invoice_date asc, si.id asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.list_open_invoices_for_payment(bigint, bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_open_invoices_for_payment(bigint, bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_open_invoices_for_payment(bigint, bigint, text, integer, integer) TO service_role;