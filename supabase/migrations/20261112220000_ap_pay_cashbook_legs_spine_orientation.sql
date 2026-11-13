-- AP pay cashbook legs: use bill from/to as payer/payee (no AP swap).
-- Backfill shipment_cost_ap rows stored with document orientation (vendor on from, tenant on to).

CREATE OR REPLACE FUNCTION public._desk_bill_pay_cashbook_legs_json(
  p_tenant_id bigint,
  p_invoice_type text,
  p_from_profile_id bigint,
  p_to_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_books_id bigint;
  v_ccy text;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  RETURN jsonb_build_object(
    'currency_code', v_ccy,
    'from_leg', public._desk_profile_cashbook_leg_json(v_books_id, p_from_profile_id, v_ccy),
    'to_leg', public._desk_profile_cashbook_leg_json(v_books_id, p_to_profile_id, v_ccy)
  );
END;
$$;

-- Product-oriented rows: from = vendor/cargo, to = tenant self-profile. Spine: from = tenant, to = payee.
UPDATE money_kernel.bills b
   SET from_profile_id = b.to_profile_id,
       to_profile_id = b.from_profile_id,
       counterparty_profile_id = b.from_profile_id,
       updated_at = now()
 WHERE b.kind = 'shipment_cost_ap'
   AND b.status <> 'voided'
   AND b.from_profile_id IS NOT NULL
   AND b.to_profile_id IS NOT NULL
   AND b.from_profile_id <> b.to_profile_id
   AND EXISTS (
     SELECT 1 FROM public.profiles pf
      WHERE pf.id = b.from_profile_id
        AND pf.profile_type IN (
          'vendor'::public.profile_party_type,
          'cargo'::public.profile_party_type,
          'company'::public.profile_party_type
        )
   )
   AND EXISTS (
     SELECT 1 FROM public.profiles pt
      WHERE pt.id = b.to_profile_id
        AND pt.profile_type = 'tenant'::public.profile_party_type
   )
   AND NOT EXISTS (
     SELECT 1
       FROM money_kernel.bill_settlements bs
       JOIN money_kernel.pays p
         ON p.tenant_id = bs.tenant_id
        AND p.id = bs.pays_id
        AND p.status <> 'voided'
      WHERE bs.bill_id = b.id
        AND bs.tenant_id = b.tenant_id
        AND bs.settlement_kind = 'pay'
   );
