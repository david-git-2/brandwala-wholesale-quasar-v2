CREATE FUNCTION public.investor_uwl_flow_total (
  p_tenant_id   bigint,
  p_investor_id bigint,
  p_flow        text
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(sum(abs(uwl.amount)), 0)::numeric(12,2)
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
    and (
      (
        p_flow = 'in'
        and uwl.type = 'credit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'capital_in', 'capital_adjustment', 'manual_adjustment', 'deposit'
        )
      )
      or (
        p_flow = 'out'
        and uwl.type = 'debit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'withdrawal_paid', 'withdrawal', 'profit_payout'
        )
      )
    );
$function$;

GRANT ALL ON FUNCTION public.investor_uwl_flow_total(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.investor_uwl_flow_total(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.investor_uwl_flow_total(bigint, bigint, text) TO service_role;