CREATE FUNCTION public.issue_bill_adjustment (
  p_adjustment_id bigint
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.bills;
begin
  select * into v_row from public.bills where id = p_adjustment_id for update;
  if v_row.id is null then
    raise exception 'adjustment not found';
  end if;
  if v_row.document_kind = 'standard'::public.bill_document_kind then
    raise exception 'not an adjustment bill';
  end if;
  if v_row.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft adjustments can be issued';
  end if;
  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_row.parent_tenant_id)
    or public.membership_has_module_action(v_row.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where id = p_adjustment_id
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(v_row.parent_bill_id);
  select * into v_row from public.bills where id = p_adjustment_id;
  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.issue_bill_adjustment(bigint) TO anon;

GRANT ALL ON FUNCTION public.issue_bill_adjustment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.issue_bill_adjustment(bigint) TO service_role;