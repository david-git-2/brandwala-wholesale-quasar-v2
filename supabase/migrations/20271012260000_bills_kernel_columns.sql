-- Bills kernel (docs/features/bills_pays/kernel-schema.md):
-- from/to profiles, source plug, settlement_kind, line currency/kind,
-- pay cash point, alloc bill_id. Fold bill_charges into bill_lines.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'bill_settlement_kind'
  ) THEN
    CREATE TYPE public.bill_settlement_kind AS ENUM ('take', 'condition');
  END IF;
END $$;

ALTER TABLE public.bills
  ADD COLUMN IF NOT EXISTS from_profile_id bigint,
  ADD COLUMN IF NOT EXISTS to_profile_id bigint,
  ADD COLUMN IF NOT EXISTS settlement_kind public.bill_settlement_kind,
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id text,
  ADD COLUMN IF NOT EXISTS source_key text,
  ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'BDT' NOT NULL;

ALTER TABLE public.bills
  DROP CONSTRAINT IF EXISTS bills_from_to_distinct;
ALTER TABLE public.bills
  ADD CONSTRAINT bills_from_to_distinct CHECK (from_profile_id IS DISTINCT FROM to_profile_id);

ALTER TABLE public.bill_lines
  ADD COLUMN IF NOT EXISTS line_kind text DEFAULT 'stock' NOT NULL,
  ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'BDT' NOT NULL,
  ADD COLUMN IF NOT EXISTS books_amount numeric(12,2);

ALTER TABLE public.bill_lines
  DROP CONSTRAINT IF EXISTS bill_lines_line_kind_check;
ALTER TABLE public.bill_lines
  ADD CONSTRAINT bill_lines_line_kind_check
  CHECK (line_kind = ANY (ARRAY['stock'::text, 'description'::text, 'charge'::text]));

ALTER TABLE public.pays
  ADD COLUMN IF NOT EXISTS cashbook_point_id bigint;

ALTER TABLE public.pay_instruments
  ADD COLUMN IF NOT EXISTS cashbook_point_id bigint;

ALTER TABLE public.pay_allocations
  ADD COLUMN IF NOT EXISTS bill_id bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bills_from_profile_id_fkey'
  ) THEN
    ALTER TABLE public.bills
      ADD CONSTRAINT bills_from_profile_id_fkey
      FOREIGN KEY (from_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bills_to_profile_id_fkey'
  ) THEN
    ALTER TABLE public.bills
      ADD CONSTRAINT bills_to_profile_id_fkey
      FOREIGN KEY (to_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pays_cashbook_point_id_fkey'
  ) THEN
    ALTER TABLE public.pays
      ADD CONSTRAINT pays_cashbook_point_id_fkey
      FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pay_instruments_cashbook_point_id_fkey'
  ) THEN
    ALTER TABLE public.pay_instruments
      ADD CONSTRAINT pay_instruments_cashbook_point_id_fkey
      FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pay_allocations_bill_id_fkey'
  ) THEN
    ALTER TABLE public.pay_allocations
      ADD CONSTRAINT pay_allocations_bill_id_fkey
      FOREIGN KEY (bill_id) REFERENCES public.bills(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS bills_from_profile_id_idx ON public.bills USING btree (from_profile_id);
CREATE INDEX IF NOT EXISTS bills_to_profile_id_idx ON public.bills USING btree (to_profile_id);
CREATE INDEX IF NOT EXISTS pay_allocations_bill_id_idx ON public.pay_allocations USING btree (bill_id);
CREATE INDEX IF NOT EXISTS pays_cashbook_point_id_idx ON public.pays USING btree (cashbook_point_id) WHERE cashbook_point_id IS NOT NULL;

UPDATE public.bill_lines
SET
  line_kind = CASE
    WHEN global_stock_id IS NOT NULL THEN 'stock'
    ELSE 'description'
  END,
  currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT'),
  books_amount = coalesce(books_amount, line_total_amount)
WHERE true;

UPDATE public.bills
SET currency_code = 'BDT'
WHERE currency_code IS NULL OR btrim(currency_code) = '';

UPDATE public.pay_allocations
SET bill_id = coalesce(global_invoice_id, invoice_id)
WHERE bill_id IS NULL;

INSERT INTO public.bill_lines (
  invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
  sell_price_amount, line_discount_amount, line_total_amount, books_amount,
  currency_code, line_meta
)
SELECT
  c.invoice_id,
  c.parent_tenant_id,
  'charge',
  initcap(c.charge_type::text),
  1,
  c.amount,
  0,
  c.amount,
  c.amount,
  coalesce(b.currency_code, 'BDT'),
  jsonb_build_object('charge_type', c.charge_type::text)
FROM public.bill_charges c
JOIN public.bills b ON b.id = c.invoice_id
WHERE NOT EXISTS (
    SELECT 1 FROM public.bill_lines l
    WHERE l.invoice_id = c.invoice_id
      AND l.line_kind = 'charge'
      AND l.line_meta->>'charge_type' = c.charge_type::text
  );

DROP TABLE IF EXISTS public.bill_charges;
DROP SEQUENCE IF EXISTS public.sales_invoice_charges_id_seq;

CREATE OR REPLACE FUNCTION public.stamp_bill_kernel_fields(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_tenant_profile_id bigint;
  v_from bigint;
  v_to bigint;
  v_source_type text;
  v_source_id text;
  v_source_key text;
  v_settle public.bill_settlement_kind;
  v_kind text;
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    return;
  end if;

  select p.id into v_tenant_profile_id
  from public.profiles p
  where p.parent_tenant_id = v_bill.parent_tenant_id
    and p.profile_type = 'tenant'::public.profile_party_type
    and p.subject_id = v_bill.issued_by_tenant_id
  limit 1;

  if v_tenant_profile_id is null then
    select p.id into v_tenant_profile_id
    from public.profiles p
    where p.parent_tenant_id = v_bill.parent_tenant_id
      and p.profile_type = 'tenant'::public.profile_party_type
      and p.subject_id = v_bill.parent_tenant_id
    limit 1;
  end if;

  if v_bill.invoice_type = 'ap'::public.global_invoice_type then
    v_from := v_bill.profile_id;
    v_to := v_tenant_profile_id;
    v_source_type := coalesce(v_bill.source_type, 'shipment_cost');
    v_source_id := coalesce(v_bill.source_id, v_bill.ap_shipment_id::text);
    v_source_key := coalesce(v_bill.source_key, v_bill.ap_kind);
    v_settle := null;
  else
    v_from := v_tenant_profile_id;
    v_to := v_bill.profile_id;
    if v_bill.shop_order_id is not null then
      v_source_type := coalesce(v_bill.source_type, 'shop_order');
      v_source_id := coalesce(v_bill.source_id, v_bill.shop_order_id::text);
      v_source_key := v_bill.source_key;
    else
      v_source_type := coalesce(v_bill.source_type, 'compose');
      v_source_id := coalesce(v_bill.source_id, v_bill.id::text);
      v_source_key := v_bill.source_key;
    end if;
    v_kind := lower(trim(coalesce(v_bill.channel_meta->>'delivery_kind', '')));
    if v_bill.settlement_kind is not null then
      v_settle := v_bill.settlement_kind;
    elsif v_kind in ('take', 'condition') then
      v_settle := v_kind::public.bill_settlement_kind;
    else
      v_settle := 'take'::public.bill_settlement_kind;
    end if;
  end if;

  if v_from is not null and v_to is not null and v_from = v_to then
    v_to := v_bill.profile_id;
    if v_from = v_to then
      v_from := v_tenant_profile_id;
    end if;
  end if;

  update public.bills
  set
    from_profile_id = v_from,
    to_profile_id = v_to,
    source_type = v_source_type,
    source_id = v_source_id,
    source_key = v_source_key,
    settlement_kind = v_settle,
    currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT')
  where id = p_bill_id;
end;
$$;

GRANT ALL ON FUNCTION public.stamp_bill_kernel_fields(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.stamp_bill_kernel_fields(bigint) TO service_role;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public.bills LOOP
    PERFORM public.stamp_bill_kernel_fields(r.id);
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS bills_source_plug_uidx
  ON public.bills USING btree (
    parent_tenant_id,
    source_type,
    source_id,
    COALESCE(source_key, ''::text)
  )
  WHERE document_kind = 'standard'::public.bill_document_kind
    AND source_type IS NOT NULL
    AND source_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_sales_invoice_charges_from_header(p_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_inv public.bills;
  v_total numeric(12,2) := 0;
begin
  select * into v_inv from public.bills where id = p_invoice_id;
  if not found then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_invoice_id
    and line_kind = 'charge';

  if coalesce(v_inv.shipping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Delivery', 1,
      v_inv.shipping_charge, 0, v_inv.shipping_charge, v_inv.shipping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Print', 1,
      v_inv.print_charge, 0, v_inv.print_charge, v_inv.print_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'print')
    );
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Packing', 1,
      v_inv.wrapping_charge, 0, v_inv.wrapping_charge, v_inv.wrapping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'packing')
    );
    v_total := v_total + v_inv.wrapping_charge;
  end if;

  update public.bills
  set charges_amount = v_total,
      updated_at = now()
  where id = p_invoice_id;
end;
$$;
