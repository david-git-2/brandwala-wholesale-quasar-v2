CREATE FUNCTION public.list_open_on_profile (
  p_parent_tenant_id bigint,
  p_profile_id       bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_due_bills jsonb;
  v_open_credits jsonb;
  v_leftover jsonb;
begin
  if p_parent_tenant_id is null or p_profile_id is null then
    raise exception 'parent_tenant_id and profile_id are required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'total_amount', s.total_amount,
        'open_books', s.open_books,
        'due_date', s.due_date,
        'invoice_type', s.invoice_type
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_due_bills
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'standard'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'due_amount', s.open_books,
        'parent_bill_id', s.parent_bill_id
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_open_credits
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'credit_note'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'pay_id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'source', p.source
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_leftover
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.profile_id = p_profile_id
    and p.voided_at is null
    and p.unallocated_amount > 0;

  return jsonb_build_object(
    'due_bills', v_due_bills,
    'open_credit_notes', v_open_credits,
    'pay_leftover', v_leftover
  );
end;
$function$;

GRANT ALL ON FUNCTION public.list_open_on_profile(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_open_on_profile(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_open_on_profile(bigint, bigint) TO service_role;