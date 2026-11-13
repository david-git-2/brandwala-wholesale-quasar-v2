-- Cashbook lots replace pooled pots (FX tranches per point).
-- Requires: 21_money_kernel_tables.sql (pays + points); migration drops cash_bundles.

-- 005b cash_bundles (balance truth — many per point / currency at different books_rate)
CREATE TABLE IF NOT EXISTS money_kernel.cash_bundles (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         bigint NOT NULL REFERENCES public.tenants (id),
  cash_location_id bigint NOT NULL REFERENCES money_kernel.cash_locations (id) ON DELETE RESTRICT,
  currency_id       bigint NOT NULL REFERENCES public.global_currencies (id),
  currency_code     text NOT NULL DEFAULT 'BDT' REFERENCES public.global_currencies (code),
  drawer_group      text NOT NULL DEFAULT '',
  amount            numeric(18, 4) NOT NULL DEFAULT 0,
  books_rate        numeric(15, 6) NOT NULL DEFAULT 1,
  opened_pay_id     bigint,
  closed_at         timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_bundle_amount_non_negative CHECK (amount >= 0),
  CONSTRAINT chk_bundle_books_rate_positive CHECK (books_rate > 0),
  CONSTRAINT uq_cash_bundles_tenant_id UNIQUE (tenant_id, id)
);

CREATE INDEX IF NOT EXISTS ix_bundles_point_currency
  ON money_kernel.cash_bundles (cash_location_id, currency_code);

CREATE INDEX IF NOT EXISTS ix_bundles_tenant ON money_kernel.cash_bundles (tenant_id);

CREATE INDEX IF NOT EXISTS ix_bundles_open_location
  ON money_kernel.cash_bundles (cash_location_id, currency_code)
  WHERE closed_at IS NULL;

ALTER TABLE money_kernel.cash_bundles SET (fillfactor = 70);

-- pay_bundle_lines: manual multi-lot debits/credits per pay (DEFERRABLE apply trigger)
CREATE TABLE IF NOT EXISTS money_kernel.pay_bundle_lines (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id    bigint NOT NULL REFERENCES public.tenants (id),
  pay_id       bigint NOT NULL,
  direction    text NOT NULL CHECK (direction IN ('debit', 'credit')),
  cash_bundle_id       bigint NOT NULL,
  amount       numeric(18, 4) NOT NULL CHECK (amount > 0),
  books_rate   numeric(15, 6) NOT NULL CHECK (books_rate > 0),
  books_amount numeric(18, 4) NOT NULL CHECK (books_amount >= 0),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pay_bundle_lines_tenant_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_pay_bundle_lines_pay
    FOREIGN KEY (tenant_id, pay_id)
    REFERENCES money_kernel.pays (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_pay_bundle_lines_lot
    FOREIGN KEY (tenant_id, cash_bundle_id)
    REFERENCES money_kernel.cash_bundles (tenant_id, id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_pay_bundle_lines_pay ON money_kernel.pay_bundle_lines (pay_id);

ALTER TABLE money_kernel.cashbooks
  DROP CONSTRAINT IF EXISTS fk_accounts_default_pot;
ALTER TABLE money_kernel.cashbooks
  DROP CONSTRAINT IF EXISTS fk_accounts_default_bundle;
ALTER TABLE money_kernel.cashbooks
  ADD CONSTRAINT fk_accounts_default_bundle
  FOREIGN KEY (default_cash_bundle_id)
  REFERENCES money_kernel.cash_bundles (id);

-- Helper: insert line (caller must be in same txn before deferred apply)
CREATE OR REPLACE FUNCTION money_kernel.fn_insert_pay_bundle_line(
  p_tenant_id    bigint,
  p_pay_id       bigint,
  p_direction    text,
  p_cash_bundle_id       bigint,
  p_amount       numeric,
  p_books_rate   numeric,
  p_books_amount numeric
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO money_kernel.pay_bundle_lines (
    tenant_id, pay_id, direction, cash_bundle_id, amount, books_rate, books_amount
  ) VALUES (
    p_tenant_id, p_pay_id, p_direction, p_cash_bundle_id, p_amount, p_books_rate, p_books_amount
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Create a new lot at point (deposit / transfer credit). Returns lot id.
CREATE OR REPLACE FUNCTION money_kernel.fn_open_cash_bundle(
  p_tenant_id         bigint,
  p_cash_location_id bigint,
  p_currency_code     text,
  p_books_rate        numeric DEFAULT 1,
  p_opened_pay_id     bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
  v_rate numeric(15, 6);
BEGIN
  v_rate := coalesce(nullif(p_books_rate, 0), 1);
  INSERT INTO money_kernel.cash_bundles (
    tenant_id, cash_location_id, currency_id, currency_code, drawer_group,
    amount, books_rate, opened_pay_id
  )
  SELECT
    p_tenant_id, p_cash_location_id, gc.id, upper(trim(p_currency_code)), '',
    0, v_rate, p_opened_pay_id
    FROM public.global_currencies gc
   WHERE gc.code = upper(trim(p_currency_code))
     AND gc.is_active = true
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
