-- Cashbook lots replace pooled pots (FX tranches per point).
-- Requires: 21_money_kernel_tables.sql (pays + points); migration drops cashbook_point_pots.

-- 005b cashbook_lots (balance truth — many per point / currency at different books_rate)
CREATE TABLE IF NOT EXISTS money_kernel.cashbook_lots (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         bigint NOT NULL REFERENCES public.tenants (id),
  cashbook_point_id bigint NOT NULL REFERENCES money_kernel.cashbook_points (id) ON DELETE RESTRICT,
  currency_code     text NOT NULL DEFAULT 'BDT' REFERENCES money_kernel.currencies (code),
  amount            numeric(18, 4) NOT NULL DEFAULT 0,
  books_rate        numeric(15, 6) NOT NULL DEFAULT 1,
  opened_pay_id     bigint,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_lot_amount_non_negative CHECK (amount >= 0),
  CONSTRAINT chk_lot_books_rate_positive CHECK (books_rate > 0),
  CONSTRAINT uq_cashbook_lots_tenant_id UNIQUE (tenant_id, id)
);

CREATE INDEX IF NOT EXISTS ix_lots_point_currency
  ON money_kernel.cashbook_lots (cashbook_point_id, currency_code);

CREATE INDEX IF NOT EXISTS ix_lots_tenant ON money_kernel.cashbook_lots (tenant_id);

ALTER TABLE money_kernel.cashbook_lots SET (fillfactor = 70);

-- pay_lot_lines: manual multi-lot debits/credits per pay (DEFERRABLE apply trigger)
CREATE TABLE IF NOT EXISTS money_kernel.pay_lot_lines (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id    bigint NOT NULL REFERENCES public.tenants (id),
  pay_id       bigint NOT NULL,
  direction    text NOT NULL CHECK (direction IN ('debit', 'credit')),
  lot_id       bigint NOT NULL,
  amount       numeric(18, 4) NOT NULL CHECK (amount > 0),
  books_rate   numeric(15, 6) NOT NULL CHECK (books_rate > 0),
  books_amount numeric(18, 4) NOT NULL CHECK (books_amount >= 0),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pay_lot_lines_tenant_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_pay_lot_lines_pay
    FOREIGN KEY (tenant_id, pay_id)
    REFERENCES money_kernel.pays (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_pay_lot_lines_lot
    FOREIGN KEY (tenant_id, lot_id)
    REFERENCES money_kernel.cashbook_lots (tenant_id, id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_pay_lot_lines_pay ON money_kernel.pay_lot_lines (pay_id);

ALTER TABLE money_kernel.cashbook_accounts
  DROP CONSTRAINT IF EXISTS fk_accounts_default_pot;
ALTER TABLE money_kernel.cashbook_accounts
  DROP CONSTRAINT IF EXISTS fk_accounts_default_lot;
ALTER TABLE money_kernel.cashbook_accounts
  ADD CONSTRAINT fk_accounts_default_lot
  FOREIGN KEY (default_cashbook_lot_id)
  REFERENCES money_kernel.cashbook_lots (id);

ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_from_pot;
ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_from_lot;
ALTER TABLE money_kernel.pays
  ADD CONSTRAINT fk_pays_from_lot
  FOREIGN KEY (tenant_id, from_lot_id)
  REFERENCES money_kernel.cashbook_lots (tenant_id, id);

ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_to_pot;
ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_to_lot;
ALTER TABLE money_kernel.pays
  ADD CONSTRAINT fk_pays_to_lot
  FOREIGN KEY (tenant_id, to_lot_id)
  REFERENCES money_kernel.cashbook_lots (tenant_id, id);

-- Helper: insert line (caller must be in same txn before deferred apply)
CREATE OR REPLACE FUNCTION money_kernel.fn_insert_pay_lot_line(
  p_tenant_id    bigint,
  p_pay_id       bigint,
  p_direction    text,
  p_lot_id       bigint,
  p_amount       numeric,
  p_books_rate   numeric,
  p_books_amount numeric
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO money_kernel.pay_lot_lines (
    tenant_id, pay_id, direction, lot_id, amount, books_rate, books_amount
  ) VALUES (
    p_tenant_id, p_pay_id, p_direction, p_lot_id, p_amount, p_books_rate, p_books_amount
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Create a new lot at point (deposit / transfer credit). Returns lot id.
CREATE OR REPLACE FUNCTION money_kernel.fn_open_cashbook_lot(
  p_tenant_id         bigint,
  p_cashbook_point_id bigint,
  p_currency_code     text,
  p_books_rate        numeric DEFAULT 1,
  p_opened_pay_id     bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
  v_rate numeric(15, 6);
BEGIN
  v_rate := coalesce(nullif(p_books_rate, 0), 1);
  INSERT INTO money_kernel.cashbook_lots (
    tenant_id, cashbook_point_id, currency_code, amount, books_rate, opened_pay_id
  ) VALUES (
    p_tenant_id, p_cashbook_point_id, upper(trim(p_currency_code)), 0, v_rate, p_opened_pay_id
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
