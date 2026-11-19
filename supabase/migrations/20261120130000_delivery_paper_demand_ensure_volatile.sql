-- Demand seed uses INSERT; STABLE RPCs run in read-only transactions (SQLSTATE 25006).

ALTER FUNCTION public.delivery_paper_resolve_line_demand_id(
  public.delivery_paper, bigint, text, bigint
) VOLATILE;

ALTER FUNCTION public.suggest_delivery_paper_last_lot_picks(
  bigint, bigint, bigint, jsonb
) VOLATILE;

ALTER FUNCTION public.get_delivery_paper_detail(
  bigint, bigint
) VOLATILE;