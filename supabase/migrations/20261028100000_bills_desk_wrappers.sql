-- Bills desk wrappers (see supabase/schemas/bills_pays/06_bills_desk_wrappers.sql)

CREATE OR REPLACE FUNCTION public.update_draft_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.update_sales_invoice_from_payload(p_tenant_id, p_bill_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_bill(
  p_bill_id bigint,
  p_items jsonb DEFAULT NULL
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
begin
  select * into v_bill from public.issue_wholesale_invoice(p_bill_id, p_items);
  return v_bill;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_retail_bill(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.post_sales_invoice(p_bill_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO service_role;
