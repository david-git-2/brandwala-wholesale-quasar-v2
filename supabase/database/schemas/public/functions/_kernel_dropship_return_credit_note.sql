CREATE FUNCTION public._kernel_dropship_return_credit_note (
  p_parent_bill_id bigint,
  p_return_credit  numeric,
  p_return_charge  numeric,
  p_reason         text,
  p_lines          jsonb   DEFAULT '[]'::jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_net numeric(12, 2);
  v_reason text;
begin
  if p_parent_bill_id is null then
    return null;
  end if;

  v_net := round(greatest(coalesce(p_return_credit, 0) - greatest(coalesce(p_return_charge, 0), 0), 0), 2);
  if v_net <= 0 then
    return null;
  end if;

  v_reason := coalesce(nullif(trim(p_reason), ''), 'Dropship return credit');

  return public.create_bill_adjustment(
    p_parent_bill_id,
    'credit_note',
    v_net,
    v_reason,
    true,
    null,
    null,
    coalesce(p_lines, '[]'::jsonb)
  );
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_dropship_return_credit_note(bigint, numeric, numeric, text, jsonb) TO anon;

GRANT ALL ON FUNCTION public._kernel_dropship_return_credit_note(bigint, numeric, numeric, text, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_dropship_return_credit_note(bigint, numeric, numeric, text, jsonb) TO service_role;