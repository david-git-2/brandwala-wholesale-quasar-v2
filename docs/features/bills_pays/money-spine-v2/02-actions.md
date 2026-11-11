# 02-actions

Write RPCs, read RPCs, views. Writers: SECURITY DEFINER + access assert. Reads: INVOKER.

---

## Write RPCs

**17 write RPCs** (16 public + internal allocator). Each is atomic. Pass `idempotency_key` on money moves. Invariants: [00-overview.md](00-overview.md).

**Never write to tables directly.** These RPCs are the only write surface.

### Inventory

| Group | RPCs |
|---|---|
| Money spine (10) | `rpc_deposit`, `rpc_withdraw`, `rpc_transfer_same_profile`, `rpc_transfer_p2p`, `rpc_pay_bills`, `rpc_pay_bill`, `rpc_apply_document_settlement`, `rpc_void_document_settlement`, `rpc_void_pays`, `rpc_update_pays` |
| Bill lifecycle (4) | `rpc_create_bill`, `rpc_issue_bill`, `rpc_void_bill`, `rpc_write_off_bill` |
| Provisioning (2) | `rpc_provision_cashbook_currency`, `rpc_provision_tenant_cashbook` |
| Internal (1) | `rpc_allocate_invoice_no` |

### Common patterns (referenced throughout)

**Idempotency**

Every money-moving RPC accepts `p_idempotency_key text DEFAULT NULL`.

- **Permanent per tenant** (I24): void does not free the key.
- Replay: return original id(s), `idempotent: true`, and **current** status (e.g. voided pays).
- Mismatch on `request_hash` (pots, amount, allocations, resolved rates) → `idempotency_conflict`.
- New movement after void requires a **new** key.

Prefer `INSERT … ON CONFLICT DO NOTHING RETURNING` over `EXCEPTION` blocks (no subtransaction on hot path).

**Parameter match:** `fn_assert_idem_match(request_hash)` shared by deposit, withdraw, transfers, pay_bills, create_bill.

**Auth**

All **write** RPCs: `SECURITY DEFINER` with `SET search_path = money_kernel, pg_temp`, entry `PERFORM assert_kernel_money_access(p_tenant_id, p_action, p_profile_id DEFAULT NULL)`. **Read** RPCs and views: `SECURITY INVOKER`.

Full assert body, privilege matrix, RLS SQL, DEFINER lint: [05-security.md](05-security.md).

**Rates (I35)**

Writers **do not** accept caller `p_books_rate` / `p_exchange_rate` in production shape. Resolve from `books_exchange_rates`; store `rate_id` in `pays.refs`. BDT→BDT and same-currency transfers force `1`. Override only with `fx_override` action + reason inside tolerance band.

**Business dates:** `(now() AT TIME ZONE tenant.timezone)::date` — not server `CURRENT_DATE`.

**Lock timeout:** `SET LOCAL lock_timeout = '3s'` at RPC entry.

**Locking order (canonical)**

Multi-row RPCs lock in this order to prevent deadlocks:
1. `bills` (by `id`, ascending)
2. `cashbook_point_pots` (by `id`, ascending)
3. `pays` (by `id`, ascending)

Do **not** `FOR UPDATE` `cashbook_accounts` while resolving default pots — read the pot id, then lock pots. Any deviation risks deadlock under concurrency.

**Efficiency (reduce server load)**

1. **Idempotency first** — return before taking locks when a live key already matches.
2. **Set-based locks** — one statement per table: `WHERE id = ANY(...) ORDER BY id FOR UPDATE`. Never loop `PERFORM … FOR UPDATE`.
3. **Lock + read together** — `SELECT … INTO … FOR UPDATE`. Do not `PERFORM` lock then `SELECT *` again.
4. **Validate with joins** — unnest `jsonb` once and `JOIN` bills/registry; avoid N per-row `SELECT` loops for the same checks.
5. **Batch child writes** — `INSERT … SELECT` from `jsonb_array_elements` / `WITH ORDINALITY` for bill lines and settlement impacts (`jsonb_agg`).
6. **Reads stay cheap** — cursor/`LIMIT` only (no `OFFSET`, no `total_pages` / `total_count`); default includes = summary only; prefer equality / prefix filters over leading-wildcard `ILIKE`.
7. **Indexes** — settlement lookups by `pays_id` need `ix_settle_pays` (see [01-schema.md](01-schema.md)).

**Error format**

Every `RAISE EXCEPTION` uses a prefixed message (`insufficient_balance:`, `not_found:`, `invalid_state:`, `idempotency_conflict:`) so clients can pattern-match.

**Return shape**

Every write RPC returns `jsonb`. The response always includes:
- Primary identifier (`pays_id` or `bill_id`)
- `status`
- `idempotent boolean`
- Relevant balance/state snapshots

### Ship contract (RPC amendments)

SQL bodies in this file are **target** implementations; amend as follows before ship:

| RPC | Amendment |
| :--- | :--- |
| `rpc_deposit` / `withdraw` / transfers | Server rates; `fn_assert_idem_match`; null checks; max amount sanity; no idempotent return before param validation on transfers |
| `rpc_transfer_p2p` | Spend authority on `from` profile pot; tenant transfer permission |
| `rpc_pay_bills` | Params: required first (`tenant`, payer, from_pot, amount, allocations) then defaults; derive `to_pot` per bill payee + currency (Option C); one payee; `from_pot ≠ to_pot`; normalize allocations (sort by `bill_id`, cap 200); set-based settlement INSERT |
| `rpc_apply_document_settlement` | `AND tenant_id = p_tenant_id` on both bill SELECTs; null-safe amount compares |
| `rpc_void_document_settlement` | Idempotent repeat; tenant filter on bill lock |
| `rpc_update_pays` | `kind=payment` only; post via `fn_post_pays()`; fix alloc numeric width; reject draft bills |
| `rpc_create_bill` | Validate `issued_by_tenant_id` vs caller hierarchy; tenant-scoped profiles; stock line math; CN parent lock + I33; `request_hash` idempotency |
| `rpc_issue_bill` | Lines exist; Σ lines = total; total > 0; allocate invoice_no here |
| `rpc_void_bill` | Pre-lock all related bills id order; refuse live CN children |
| `rpc_write_off_bill` | `issued`/`partial` only; idempotency or `p_expected_due` |
| `rpc_void_pays` | Required reason; `voided_by`; period lock |
| `rpc_profile_transactions` | Use `from_balance_after` / `to_balance_after`; fix nested aggregate; keyset on pays id |
| `rpc_query_bills` | NULL-safe due_date cursor; enum order_by; `starts_with` search; group by currency |
| Views | `v_pot_balances` LATERAL join; no gapless `bill_events` poll — use outbox |

Legacy signatures below still show `p_books_rate` / `p_exchange_rate` until bodies are rewritten.

---

## 2. Money Spine RPCs (10)

### 2.1 `rpc_deposit`

**Purpose:** External cash flows into a profile's pot.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_deposit(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_books_rate      numeric DEFAULT 1,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays    pays;
  v_pot_id  bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  -- Validation
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_books_rate IS NULL OR p_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  PERFORM 1 FROM public.profiles
    WHERE id = p_profile_id AND tenant_id = p_tenant_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_tenant_id;
  END IF;

  -- Idempotency (posted only)
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM public.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
        AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Resolve destination pot
  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_pot_id
      FROM public.cashbook_point_pots pp
      JOIN public.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN public.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: pot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
  ELSE
    SELECT pp.id INTO v_pot_id
      FROM public.cashbook_accounts a
      JOIN public.cashbook_points    pt ON pt.cashbook_account_id = a.id
      JOIN public.cashbook_point_pots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id AND pp.currency_code = p_currency_code
     ORDER BY (a.default_cashbook_point_pot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: no % pot for profile %; call rpc_provision_cashbook_currency',
        p_currency_code, p_profile_id;
    END IF;
  END IF;

  PERFORM 1 FROM public.cashbook_point_pots WHERE id = v_pot_id FOR UPDATE;
  v_books := round(p_amount * p_books_rate, 4);

  BEGIN
    INSERT INTO public.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'deposit', NULL, v_pot_id,
      p_amount, p_currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;
```

**Error cases**

| Error | Cause |
|---|---|
| `invalid_amount` | `p_amount ≤ 0` |
| `not_found: profile` | Wrong profile or cross-tenant |
| `not_found: no N pot for profile` | Profile has no pot in that currency |
| `idempotency_conflict` | Same key, different parameters |

---

### 2.2 `rpc_withdraw`

**Purpose:** Money leaves a profile's pot.

Identical to deposit except: destination is external (`to_pot_id = NULL`), source is the resolved pot, and `FOR UPDATE` lock is taken before balance check.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_withdraw(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_books_rate      numeric DEFAULT 1,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays    pays;
  v_pot_id  bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_books_rate IS NULL OR p_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  PERFORM 1 FROM public.profiles
    WHERE id = p_profile_id AND tenant_id = p_tenant_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_tenant_id;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM public.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_pot_id
      FROM public.cashbook_point_pots pp
      JOIN public.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN public.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: pot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
  ELSE
    SELECT pp.id INTO v_pot_id
      FROM public.cashbook_accounts a
      JOIN public.cashbook_points    pt ON pt.cashbook_account_id = a.id
      JOIN public.cashbook_point_pots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id AND pp.currency_code = p_currency_code
     ORDER BY (a.default_cashbook_point_pot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: no % pot for profile %', p_currency_code, p_profile_id;
    END IF;
  END IF;

  -- Lock + balance check (only withdraw needs this)
  SELECT amount INTO v_balance
    FROM public.cashbook_point_pots WHERE id = v_pot_id FOR UPDATE;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, withdrawal is %', v_pot_id, v_balance, p_amount;
  END IF;

  v_books := round(p_amount * p_books_rate, 4);

  BEGIN
    INSERT INTO public.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'withdrawal', v_pot_id, NULL,
      p_amount, p_currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  SELECT amount INTO v_balance FROM public.cashbook_point_pots WHERE id = v_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;
```

**Additional error:** `insufficient_balance`.

---

### 2.3 `rpc_transfer_same_profile`

**Purpose:** Move money between two pots owned by the **same profile** — change location (branch → bank) or convert currency.

**Rules**
- Both pots must belong to the same profile
- Same currency ⇒ `exchange_rate` must be `1`
- `from_pot_id ≠ to_pot_id`
- `to_pot` credited by `amount × exchange_rate`
- `books_amount = amount × books_rate`

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_transfer_same_profile(
  p_tenant_id       bigint,
  p_from_pot_id     bigint,
  p_to_pot_id       bigint,
  p_amount          numeric,
  p_exchange_rate   numeric DEFAULT 1,
  p_books_rate      numeric DEFAULT 1,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays         pays;
  v_from_pot     cashbook_point_pots;
  v_to_pot       cashbook_point_pots;
  v_from_bal     numeric(18,4);
  v_to_bal       numeric(18,4);
  v_to_amount    numeric(18,4);
  v_books        numeric(18,4);
  v_from_profile bigint;
  v_to_profile   bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_exchange_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: exchange_rate'; END IF;
  IF p_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: books_rate'; END IF;
  IF p_from_pot_id = p_to_pot_id THEN
    RAISE EXCEPTION 'invalid_arguments: from_pot_id and to_pot_id must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM public.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
      SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'transfer',
        'from_pot_id', v_pays.from_pot_id, 'to_pot_id', v_pays.to_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
        'books_amount', v_pays.books_amount, 'exchange_rate', v_pays.exchange_rate,
        'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
        'status', v_pays.status, 'idempotent', true
      );
    END IF;
  END IF;

  -- Lock both pots in id order (deadlock-safe)
  IF p_from_pot_id < p_to_pot_id THEN
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = p_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = p_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
  END IF;

  IF v_from_pot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: from_pot %', p_from_pot_id;
  END IF;
  IF v_to_pot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: to_pot %', p_to_pot_id;
  END IF;
  IF v_from_pot.tenant_id <> p_tenant_id OR v_to_pot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to tenant %', p_tenant_id;
  END IF;

  -- Both pots must belong to the same profile
  SELECT a.entity_id INTO v_from_profile
    FROM public.cashbook_points pt
    JOIN public.cashbook_accounts a ON a.id = pt.cashbook_account_id
   WHERE pt.id = v_from_pot.cashbook_point_id AND a.entity_type = 'profile';
  SELECT a.entity_id INTO v_to_profile
    FROM public.cashbook_points pt
    JOIN public.cashbook_accounts a ON a.id = pt.cashbook_account_id
   WHERE pt.id = v_to_pot.cashbook_point_id AND a.entity_type = 'profile';

  IF v_from_profile IS NULL OR v_to_profile IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to a profile';
  END IF;
  IF v_from_profile <> v_to_profile THEN
    RAISE EXCEPTION
      'invalid_arguments: pots belong to different profiles (% vs %); use rpc_transfer_p2p',
      v_from_profile, v_to_profile;
  END IF;

  IF v_from_pot.currency_code = v_to_pot.currency_code AND p_exchange_rate <> 1 THEN
    RAISE EXCEPTION
      'invalid_rate: exchange_rate must be 1 for same-currency transfer';
  END IF;

  IF v_from_pot.amount < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, transfer is %',
      p_from_pot_id, v_from_pot.amount, p_amount;
  END IF;

  v_to_amount := round(p_amount * p_exchange_rate, 4);
  v_books     := round(p_amount * p_books_rate, 4);

  BEGIN
    INSERT INTO public.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'transfer', p_from_pot_id, p_to_pot_id,
      p_amount, v_from_pot.currency_code, v_books, p_exchange_rate,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'transfer' OR v_pays.amount <> p_amount
       OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_pot_id IS DISTINCT FROM p_to_pot_id THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'transfer',
      'from_pot_id', v_pays.from_pot_id, 'to_pot_id', v_pays.to_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
      'books_amount', v_pays.books_amount, 'exchange_rate', v_pays.exchange_rate,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'status', v_pays.status, 'idempotent', true
    );
  END;

  SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = p_from_pot_id;
  SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = p_to_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'transfer',
    'from_pot_id', p_from_pot_id, 'to_pot_id', p_to_pot_id,
    'amount', p_amount, 'currency_code', v_from_pot.currency_code,
    'to_amount', v_to_amount, 'to_currency_code', v_to_pot.currency_code,
    'books_amount', v_books, 'exchange_rate', p_exchange_rate,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', v_pays.status, 'idempotent', false
  );
END;
$$;
```

---

### 2.4 `rpc_transfer_p2p`

**Purpose:** Move money between pots owned by **different profiles** (refund, inter-account settlement, courier payout).

Same shape as `rpc_transfer_same_profile` except: the same-profile check is removed (both profiles must exist but may differ), and idempotency check verifies `kind='transfer'` matches.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_transfer_p2p(
  p_tenant_id       bigint,
  p_from_pot_id     bigint,
  p_to_pot_id       bigint,
  p_amount          numeric,
  p_exchange_rate   numeric DEFAULT 1,
  p_books_rate      numeric DEFAULT 1,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays     pays;
  v_from_pot cashbook_point_pots;
  v_to_pot   cashbook_point_pots;
  v_from_bal numeric(18,4);
  v_to_bal   numeric(18,4);
  v_to_amount numeric(18,4);
  v_books    numeric(18,4);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_exchange_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: exchange_rate'; END IF;
  IF p_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: books_rate'; END IF;
  IF p_from_pot_id = p_to_pot_id THEN
    RAISE EXCEPTION 'invalid_arguments: from_pot_id and to_pot_id must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM public.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
      SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'transfer',
        'from_pot_id', v_pays.from_pot_id, 'to_pot_id', v_pays.to_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
        'books_amount', v_pays.books_amount,
        'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
        'status', v_pays.status, 'idempotent', true
      );
    END IF;
  END IF;

  IF p_from_pot_id < p_to_pot_id THEN
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = p_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = p_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
  END IF;

  IF v_from_pot.id IS NULL THEN RAISE EXCEPTION 'not_found: from_pot %', p_from_pot_id; END IF;
  IF v_to_pot.id IS NULL   THEN RAISE EXCEPTION 'not_found: to_pot %', p_to_pot_id;     END IF;
  IF v_from_pot.tenant_id <> p_tenant_id OR v_to_pot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to tenant %', p_tenant_id;
  END IF;

  IF v_from_pot.currency_code = v_to_pot.currency_code AND p_exchange_rate <> 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for same-currency transfer';
  END IF;

  IF v_from_pot.amount < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, transfer is %',
      p_from_pot_id, v_from_pot.amount, p_amount;
  END IF;

  v_to_amount := round(p_amount * p_exchange_rate, 4);
  v_books     := round(p_amount * p_books_rate, 4);

  BEGIN
    INSERT INTO public.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'transfer', p_from_pot_id, p_to_pot_id,
      p_amount, v_from_pot.currency_code, v_books, p_exchange_rate,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'transfer' OR v_pays.amount <> p_amount
       OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_pot_id IS DISTINCT FROM p_to_pot_id THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'transfer',
      'from_pot_id', v_pays.from_pot_id, 'to_pot_id', v_pays.to_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
      'books_amount', v_pays.books_amount,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'status', v_pays.status, 'idempotent', true
    );
  END;

  SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = p_from_pot_id;
  SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = p_to_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'transfer',
    'from_pot_id', p_from_pot_id, 'to_pot_id', p_to_pot_id,
    'amount', p_amount, 'currency_code', v_from_pot.currency_code,
    'to_amount', v_to_amount, 'to_currency_code', v_to_pot.currency_code,
    'books_amount', v_books, 'exchange_rate', p_exchange_rate,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', v_pays.status, 'idempotent', false
  );
END;
$$;
```

**Note:** The only difference from `same_profile` is the removed same-profile check. Could be a shared internal function; separate public RPCs for API clarity.

---

### 2.5 `rpc_pay_bills`

**Job:** One `pays` + N `pay` settlements. `rpc_pay_bill` wraps this with one allocation.

```sql
-- Target signature (required params before DEFAULTs; books_rate resolved server-side)
CREATE OR REPLACE FUNCTION public.rpc_pay_bills(
  p_tenant_id        bigint,
  p_payer_profile_id bigint,
  p_from_pot_id      bigint,
  p_amount           numeric,
  p_allocations      jsonb,
  p_to_pot_id        bigint DEFAULT NULL,
  p_meta             jsonb DEFAULT '{}'::jsonb,
  p_idempotency_key  text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays       pays;
  v_from_pot   cashbook_point_pots;
  v_to_pot     cashbook_point_pots;
  v_to_pot_id  bigint;
  v_books      numeric(18,4);
  v_bill_ids   bigint[];
  v_bill_id    bigint;
  v_alloc_amt  numeric(18,4);
  v_alloc      jsonb;
  v_bill       bills;
  v_settlements jsonb := '[]'::jsonb;
  v_settlement bill_settlements;
  v_sum_alloc  numeric(18,4);
  v_settle_books numeric(18,4);
  v_books_left numeric(18,4);
  v_line_books numeric(18,4);
  v_alloc_n    int;
  v_alloc_i    int;
  v_err        text;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_books_rate IS NULL OR p_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;
  IF p_allocations IS NULL OR jsonb_typeof(p_allocations) <> 'array'
     OR jsonb_array_length(p_allocations) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: p_allocations must be a non-empty array';
  END IF;
  IF (
    SELECT count(*) <> count(DISTINCT (a->>'bill_id')::bigint)
      FROM jsonb_array_elements(p_allocations) a
  ) THEN
    RAISE EXCEPTION 'invalid_arguments: duplicate bill_id in p_allocations';
  END IF;

  -- [SHIP] Derive to_pot from bill.to_profile_id + currency (Option C / I30–I32).
  -- If p_to_pot_id passed, must equal derived pot for every bill in p_allocations.
  -- Reject mixed payees; reject from_pot = to_pot.
  -- Body below still shows legacy tenant-default path until rewritten.
  IF p_to_pot_id IS NOT NULL THEN
    v_to_pot_id := p_to_pot_id;
  ELSE
    SELECT default_cashbook_point_pot_id INTO v_to_pot_id
      FROM public.cashbook_accounts
     WHERE tenant_id = p_tenant_id AND entity_type = 'tenant'
       AND entity_id = p_tenant_id;
    IF v_to_pot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: payee pot; provision payee cashbook';
    END IF;
  END IF;

  -- Idempotency before locks
  -- [CORRECTED: was kind+amount only → also pots, books_rate, allocations]
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'payment'
         OR v_pays.amount <> p_amount
         OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
         OR v_pays.to_pot_id IS DISTINCT FROM v_to_pot_id
         OR v_pays.books_amount <> round(p_amount * p_books_rate, 4)
         OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
            IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
      THEN
        RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_bill_ids
    FROM (
      SELECT DISTINCT (a->>'bill_id')::bigint AS x
        FROM jsonb_array_elements(p_allocations) a
    ) s;

  -- One lock statement for all bills (ascending id)
  PERFORM 1 FROM public.bills
   WHERE tenant_id = p_tenant_id AND id = ANY(v_bill_ids)
   ORDER BY id
   FOR UPDATE;

  -- Lock + read pots in id order (no second SELECT)
  IF p_from_pot_id < v_to_pot_id THEN
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = v_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_pot   FROM public.cashbook_point_pots WHERE id = v_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
  END IF;
  IF v_from_pot.id IS NULL OR v_to_pot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: pot';
  END IF;
  IF v_from_pot.tenant_id <> p_tenant_id OR v_to_pot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: pots must belong to tenant %', p_tenant_id;
  END IF;

  PERFORM 1 FROM public.profiles
   WHERE id = p_payer_profile_id AND tenant_id = p_tenant_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: payer profile % in tenant %', p_payer_profile_id, p_tenant_id;
  END IF;

  PERFORM 1 FROM public.cashbook_point_pots pp
    JOIN public.cashbook_points pt ON pt.id = pp.cashbook_point_id
    JOIN public.cashbook_accounts a ON a.id = pt.cashbook_account_id
   WHERE pp.id = p_from_pot_id AND a.entity_type = 'profile'
     AND a.entity_id = p_payer_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: from_pot % does not belong to profile %', p_from_pot_id, p_payer_profile_id;
  END IF;

  IF v_from_pot.amount < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance: pot % has %, payment is %',
      p_from_pot_id, v_from_pot.amount, p_amount;
  END IF;

  -- Set-based allocation validation (one join pass; first failure wins)
  SELECT x.err INTO v_err
    FROM (
      SELECT
        (a.elem->>'bill_id')::bigint AS bill_id,
        round((a.elem->>'amount')::numeric, 2) AS alloc_amt,
        CASE
          WHEN round((a.elem->>'amount')::numeric, 2) IS NULL
            OR round((a.elem->>'amount')::numeric, 2) <= 0
            THEN 'invalid_amount: each allocation amount must be > 0'
          WHEN b.id IS NULL
            THEN format('not_found: bill %s', a.elem->>'bill_id')
          WHEN b.kind = 'credit_note' OR COALESCE(r.can_be_paid, true) = false
            THEN format(
              'invalid_arguments: bill %s kind %s cannot be cash-paid; use rpc_apply_document_settlement',
              b.id, b.kind)
          WHEN b.status IN ('draft','voided')
            THEN format('invalid_state: cannot pay bill %s status %s', b.id, b.status)
          WHEN b.from_profile_id IS NULL OR b.from_profile_id <> p_payer_profile_id
            THEN format(
              'invalid_arguments: payer_profile %s must equal bill.from_profile_id %s',
              p_payer_profile_id, b.from_profile_id)
          WHEN b.currency_code <> v_from_pot.currency_code
            OR b.currency_code <> v_to_pot.currency_code
            THEN format('invalid_arguments: pots and bill %s must share currency (I7b)', b.id)
          WHEN round((a.elem->>'amount')::numeric, 2) > b.due_amount
            THEN format(
              'invalid_amount: allocation %s exceeds bill %s due %s',
              round((a.elem->>'amount')::numeric, 2), b.id, b.due_amount)
          ELSE NULL
        END AS err
      FROM jsonb_array_elements(p_allocations) WITH ORDINALITY AS a(elem, ord)
      LEFT JOIN public.bills b
        ON b.id = (a.elem->>'bill_id')::bigint AND b.tenant_id = p_tenant_id
      LEFT JOIN public.bill_kind_registry r ON r.kind = b.kind
      ORDER BY a.ord
    ) x
   WHERE x.err IS NOT NULL
   LIMIT 1;
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err;
  END IF;

  SELECT COALESCE(SUM(round((a->>'amount')::numeric, 2)), 0) INTO v_sum_alloc
    FROM jsonb_array_elements(p_allocations) a;
  IF v_sum_alloc > round(p_amount, 2) THEN
    RAISE EXCEPTION 'invalid_amount: sum(allocations) % exceeds pays amount %',
      v_sum_alloc, p_amount;
  END IF;

  v_books := round(p_amount * p_books_rate, 4);
  -- Books for settlements cover allocated cash only; unapplied cash leaves books on pays
  v_settle_books := round(v_sum_alloc * p_books_rate, 4);
  v_books_left := v_settle_books;
  v_alloc_n := jsonb_array_length(p_allocations);

  BEGIN
    INSERT INTO public.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'payment', p_from_pot_id, v_to_pot_id,
      p_amount, v_from_pot.currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key,
      jsonb_build_object('allocations', p_allocations),
      COALESCE(p_meta, '{}'::jsonb), auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM public.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    -- [CORRECTED: same full param match as pre-lock path]
    IF v_pays.kind <> 'payment'
       OR v_pays.amount <> p_amount
       OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_pot_id IS DISTINCT FROM v_to_pot_id
       OR v_pays.books_amount <> round(p_amount * p_books_rate, 4)
       OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
          IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
    THEN
      RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  v_alloc_i := 0;
  FOR v_alloc IN SELECT * FROM jsonb_array_elements(p_allocations) LOOP
    v_alloc_i := v_alloc_i + 1;
    v_bill_id := (v_alloc->>'bill_id')::bigint;
    v_alloc_amt := round((v_alloc->>'amount')::numeric, 2);
    IF v_alloc_i = v_alloc_n THEN
      v_line_books := v_books_left;  -- absorb rounding residue
    ELSE
      v_line_books := round(v_alloc_amt * p_books_rate, 4);
      v_books_left := v_books_left - v_line_books;
    END IF;
    INSERT INTO public.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount
    ) VALUES (
      p_tenant_id, v_bill_id, 'pay', v_pays.id, NULL,
      v_alloc_amt, v_line_books
    ) RETURNING * INTO v_settlement;
    v_settlements := v_settlements || jsonb_build_object(
      'settlement_id', v_settlement.id,
      'bill_id', v_bill_id,
      'allocated_amount', v_alloc_amt
    );
  END LOOP;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'amount', p_amount, 'books_amount', v_books,
    'from_pot_id', p_from_pot_id, 'to_pot_id', v_to_pot_id,
    'settlements', v_settlements, 'status', 'posted', 'idempotent', false
  );
END;
$$;
```

---

### 2.5b `rpc_pay_bill`

**Job:** Pay one bill. Wrapper around `rpc_pay_bills` (deploy `rpc_pay_bills` first).

**Currency (I7b):** from pot, to pot, bill same currency. AP: pass vendor `p_to_pot_id`.

```sql
CREATE OR REPLACE FUNCTION public.rpc_pay_bill(
  p_tenant_id        bigint,
  p_bill_id          bigint,
  p_payer_profile_id bigint,
  p_from_pot_id      bigint,
  p_amount           numeric,
  p_exchange_rate    numeric DEFAULT 1,
  p_books_rate       numeric DEFAULT 1,
  p_to_pot_id        bigint  DEFAULT NULL,
  p_meta             jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key  text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_exchange_rate IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for kind=payment (I7b)';
  END IF;
  RETURN public.rpc_pay_bills(
    p_tenant_id,
    p_payer_profile_id,
    p_from_pot_id,
    p_to_pot_id,
    p_amount,
    p_books_rate,
    jsonb_build_array(jsonb_build_object('bill_id', p_bill_id, 'amount', p_amount)),
    p_meta,
    p_idempotency_key
  );
END;
$$;
```

---

### 2.5c `rpc_apply_document_settlement`

**Job:** Apply issued **credit_note** remaining due onto a target bill with the same party pair (I29). No pays / pots.

```sql
CREATE OR REPLACE FUNCTION public.rpc_apply_document_settlement(
  p_tenant_id       bigint,
  p_source_bill_id  bigint,
  p_target_bill_id  bigint,
  p_amount          numeric,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_source bills;
  v_target bills;
  v_settle bill_settlements;
  v_amt    numeric(18,4);
  v_first  bigint;
  v_second bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_source_bill_id = p_target_bill_id THEN
    RAISE EXCEPTION 'invalid_arguments: source and target must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_settle FROM public.bill_settlements
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key;
    IF FOUND THEN
      IF v_settle.settlement_kind <> 'document'
         OR v_settle.bill_id <> p_target_bill_id
         OR v_settle.source_bill_id <> p_source_bill_id
         OR v_settle.allocated_amount <> round(p_amount, 2) THEN
        RAISE EXCEPTION 'idempotency_conflict: key %', p_idempotency_key;
      END IF;
      RETURN jsonb_build_object(
        'settlement_id', v_settle.id,
        'source_bill_id', p_source_bill_id,
        'target_bill_id', p_target_bill_id,
        'allocated_amount', v_settle.allocated_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  v_amt := round(p_amount, 2);
  IF p_source_bill_id < p_target_bill_id THEN
    v_first := p_source_bill_id; v_second := p_target_bill_id;
  ELSE
    v_first := p_target_bill_id; v_second := p_source_bill_id;
  END IF;
  PERFORM 1 FROM public.bills
   WHERE tenant_id = p_tenant_id AND id = ANY(ARRAY[v_first, v_second])
   ORDER BY id
   FOR UPDATE;

  SELECT * INTO v_source FROM public.bills WHERE id = p_source_bill_id;
  SELECT * INTO v_target FROM public.bills WHERE id = p_target_bill_id;
  IF v_source.id IS NULL OR v_target.id IS NULL THEN
    RAISE EXCEPTION 'not_found: bill';
  END IF;
  IF v_source.kind <> 'credit_note' THEN
    RAISE EXCEPTION 'invalid_arguments: source must be credit_note, got %', v_source.kind;
  END IF;
  IF v_target.kind = 'credit_note' THEN
    RAISE EXCEPTION 'invalid_arguments: cannot apply credit_note onto another credit_note';
  END IF;
  IF v_source.status IN ('draft','voided') OR v_target.status IN ('draft','voided') THEN
    RAISE EXCEPTION 'invalid_state: both bills must be live (issued/partial/paid/written_off)';
  END IF;
  IF v_source.currency_code <> v_target.currency_code THEN
    RAISE EXCEPTION 'invalid_arguments: currency mismatch';
  END IF;
  -- I29: CN parties are swap of obligation; target must be same pair (payer/payee)
  IF v_target.from_profile_id IS DISTINCT FROM v_source.to_profile_id
     OR v_target.to_profile_id IS DISTINCT FROM v_source.from_profile_id THEN
    RAISE EXCEPTION
      'invalid_arguments: document apply requires target.from=source.to and target.to=source.from';
  END IF;
  IF v_amt > v_target.due_amount THEN
    RAISE EXCEPTION 'invalid_amount: % exceeds target due %', v_amt, v_target.due_amount;
  END IF;
  IF v_amt > v_source.due_amount THEN
    RAISE EXCEPTION 'invalid_amount: % exceeds credit remaining %', v_amt, v_source.due_amount;
  END IF;

  BEGIN
    INSERT INTO public.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount, idempotency_key
    ) VALUES (
      p_tenant_id, p_target_bill_id, 'document', NULL, p_source_bill_id,
      v_amt, v_amt, p_idempotency_key
    ) RETURNING * INTO v_settle;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_settle FROM public.bill_settlements
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key;
    IF NOT FOUND THEN RAISE; END IF;
    IF v_settle.settlement_kind <> 'document'
       OR v_settle.bill_id <> p_target_bill_id
       OR v_settle.source_bill_id <> p_source_bill_id
       OR v_settle.allocated_amount <> v_amt THEN
      RAISE EXCEPTION 'idempotency_conflict: key %', p_idempotency_key;
    END IF;
    RETURN jsonb_build_object(
      'settlement_id', v_settle.id,
      'source_bill_id', p_source_bill_id,
      'target_bill_id', p_target_bill_id,
      'allocated_amount', v_settle.allocated_amount,
      'idempotent', true
    );
  END;

  RETURN jsonb_build_object(
    'settlement_id', v_settle.id,
    'source_bill_id', p_source_bill_id,
    'target_bill_id', p_target_bill_id,
    'allocated_amount', v_amt,
    'idempotent', false
  );
END;
$$;
```

---

### 2.5d `rpc_void_document_settlement`

**Job:** DELETE one `document` settlement (T7 restores target + source dues).

```sql
CREATE OR REPLACE FUNCTION public.rpc_void_document_settlement(
  p_tenant_id     bigint,
  p_settlement_id bigint,
  p_reason        text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_settle bill_settlements;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT * INTO v_settle FROM public.bill_settlements
   WHERE id = p_settlement_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: settlement %', p_settlement_id;
  END IF;
  IF v_settle.settlement_kind <> 'document' THEN
    RAISE EXCEPTION 'invalid_arguments: settlement % is not document; use rpc_void_pays', p_settlement_id;
  END IF;

  -- Lock target + source bills in one statement (id order)
  PERFORM 1 FROM public.bills
   WHERE id = ANY(ARRAY[v_settle.bill_id, v_settle.source_bill_id])
   ORDER BY id
   FOR UPDATE;

  DELETE FROM public.bill_settlements WHERE id = p_settlement_id;

  RETURN jsonb_build_object(
    'settlement_id', p_settlement_id,
    'target_bill_id', v_settle.bill_id,
    'source_bill_id', v_settle.source_bill_id,
    'voided', true,
    'reason', p_reason
  );
END;
$$;
```

**Note:** `rpc_void_pays` deletes only `settlement_kind = 'pay'` rows for that pays_id.

---

### 2.6 `rpc_void_pays`

**Purpose:** Reverse a posted `pays`. Deletes pay settlements first (bill restores), then flips status (pot restores).

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_void_pays(
  p_tenant_id bigint,
  p_pays_id   bigint,
  p_reason    text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pays      pays;
  v_from_bal  numeric(18,4);
  v_to_bal    numeric(18,4);
  v_bill_ids  bigint[];
  v_impacts   jsonb := '[]'::jsonb;
  v_pot_ids   bigint[];
  v_to_credit numeric(18,4);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  -- Peek pays (no lock) so we can follow bills → pots → pays lock order
  SELECT * INTO v_pays FROM public.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pays_id, p_tenant_id;
  END IF;

  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  SELECT COALESCE(array_agg(bill_id ORDER BY bill_id), '{}')
    INTO v_bill_ids
    FROM (SELECT DISTINCT bill_id FROM public.bill_settlements WHERE pays_id = p_pays_id) s;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}')
    INTO v_pot_ids
    FROM unnest(ARRAY[v_pays.from_pot_id, v_pays.to_pot_id]) AS x
   WHERE x IS NOT NULL;

  IF cardinality(v_bill_ids) > 0 THEN
    PERFORM 1 FROM public.bills WHERE id = ANY(v_bill_ids) ORDER BY id FOR UPDATE;
  END IF;
  IF cardinality(v_pot_ids) > 0 THEN
    PERFORM 1 FROM public.cashbook_point_pots WHERE id = ANY(v_pot_ids) ORDER BY id FOR UPDATE;
  END IF;

  -- Lock pays last; re-check status under lock
  SELECT * INTO v_pays FROM public.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  -- Must match T1 fn_pays_apply credit expression (I22); pot rows already locked
  v_to_credit := CASE
    WHEN v_pays.kind = 'transfer' THEN round(v_pays.amount * v_pays.exchange_rate, 4)
    ELSE v_pays.amount
  END;
  IF v_pays.to_pot_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    IF v_to_bal < v_to_credit THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot void pays %; to_pot % has % but reverse needs %',
        p_pays_id, v_pays.to_pot_id, v_to_bal, v_to_credit;
    END IF;
  END IF;

  DELETE FROM public.bill_settlements
   WHERE pays_id = p_pays_id AND settlement_kind = 'pay';

  UPDATE public.pays
     SET status = 'voided',
         voided_at = now(),
         updated_at = now(),
         meta = COALESCE(meta, '{}'::jsonb)
                || jsonb_build_object('void_reason', p_reason)
   WHERE id = p_pays_id;

  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object('bill_id', id, 'due_after', due_amount)
             ORDER BY id
           ),
           '[]'::jsonb
         )
    INTO v_impacts
    FROM public.bills
   WHERE id = ANY(v_bill_ids);

  IF v_pays.from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_pays.from_pot_id;
  END IF;
  IF v_pays.to_pot_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM public.cashbook_point_pots WHERE id = v_pays.to_pot_id;
  END IF;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', v_pays.kind, 'amount', v_pays.amount,
    'status', 'voided',
    'from_pot_id', v_pays.from_pot_id, 'to_pot_id', v_pays.to_pot_id,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'bill_impacts', v_impacts, 'idempotent', false
  );
END;
$$;
```

---

### 2.7 `rpc_update_pays`

**Purpose:** Correct a posted `pays` by voiding and recreating in one transaction. Preserves full audit trail via `refs.replaces_pays_id`.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_update_pays(
  p_tenant_id        bigint,
  p_pays_id          bigint,
  p_kind             text,
  p_from_pot_id      bigint,
  p_to_pot_id        bigint,
  p_amount           numeric,
  p_exchange_rate    numeric DEFAULT 1,
  p_books_rate       numeric DEFAULT 1,
  p_bill_id          bigint  DEFAULT NULL,
  p_meta             jsonb   DEFAULT '{}'::jsonb,
  p_refs             jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key  text    DEFAULT NULL,
  p_reason           text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old       pays;
  v_new       pays;
  v_bill      bills;
  v_from_pot  cashbook_point_pots;
  v_to_pot    cashbook_point_pots;
  v_settle    bill_settlements;
  v_from_bal  numeric(18,4);
  v_to_bal    numeric(18,4);
  v_to_amt    numeric(18,4);
  v_alloc     numeric(12,2);
  v_books     numeric(18,4);
  v_pot_ids   bigint[];
  v_bill_ids  bigint[];
  v_new_refs  jsonb;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  -- Idempotency before locks
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_new FROM public.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
        AND status = 'posted';
    IF FOUND THEN
      IF (v_new.refs->>'replaces_pays_id')::bigint = p_pays_id THEN
        SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = v_new.from_pot_id;
        SELECT amount INTO v_to_bal   FROM public.cashbook_point_pots WHERE id = v_new.to_pot_id;
        RETURN jsonb_build_object(
          'voided_pays_id', p_pays_id, 'new_pays_id', v_new.id,
          'kind', v_new.kind, 'amount', v_new.amount, 'status', v_new.status,
          'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
          'idempotent', true
        );
      ELSE
        RAISE EXCEPTION
          'idempotency_conflict: key % already used by pays %', p_idempotency_key, v_new.id;
      END IF;
    END IF;
  END IF;

  -- Peek original pays (lock later: bills → pots → pays)
  SELECT * INTO v_old FROM public.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays %', p_pays_id;
  END IF;
  IF v_old.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: pays % already voided', p_pays_id;
  END IF;

  -- Multi-bill payment: void + rpc_pay_bills (this RPC re-settles at most one bill)
  IF (
    SELECT count(*) FROM public.bill_settlements
     WHERE pays_id = p_pays_id AND settlement_kind = 'pay'
  ) > 1 THEN
    RAISE EXCEPTION
      'invalid_arguments: pays % has multiple bill settlements; use rpc_void_pays + rpc_pay_bills',
      p_pays_id;
  END IF;

  -- Validation
  IF p_kind NOT IN ('deposit','withdrawal','transfer','payment') THEN
    RAISE EXCEPTION 'invalid_arguments: unknown kind %', p_kind;
  END IF;
  IF p_kind = 'deposit' AND (p_from_pot_id IS NOT NULL OR p_to_pot_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: deposit requires from=NULL, to!=NULL';
  END IF;
  IF p_kind = 'withdrawal' AND (p_from_pot_id IS NULL OR p_to_pot_id IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: withdrawal requires from!=NULL, to=NULL';
  END IF;
  IF p_kind IN ('transfer','payment')
     AND (p_from_pot_id IS NULL OR p_to_pot_id IS NULL OR p_from_pot_id = p_to_pot_id) THEN
    RAISE EXCEPTION 'invalid_arguments: % requires distinct from/to pots', p_kind;
  END IF;
  IF p_kind = 'payment' AND p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: payment requires p_bill_id';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_exchange_rate <= 0 OR p_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate'; END IF;

  -- Lock bills → pots → pays (set-based)
  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_bill_ids
    FROM (
      SELECT DISTINCT bill_id AS x FROM public.bill_settlements
       WHERE pays_id = p_pays_id AND settlement_kind = 'pay'
      UNION
      SELECT p_bill_id WHERE p_kind = 'payment' AND p_bill_id IS NOT NULL
    ) s;
  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_pot_ids
    FROM unnest(ARRAY[
      v_old.from_pot_id, v_old.to_pot_id, p_from_pot_id, p_to_pot_id
    ]) AS x
   WHERE x IS NOT NULL;

  IF cardinality(v_bill_ids) > 0 THEN
    PERFORM 1 FROM public.bills WHERE id = ANY(v_bill_ids) ORDER BY id FOR UPDATE;
  END IF;
  IF cardinality(v_pot_ids) > 0 THEN
    PERFORM 1 FROM public.cashbook_point_pots WHERE id = ANY(v_pot_ids) ORDER BY id FOR UPDATE;
  END IF;
  SELECT * INTO v_old FROM public.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF v_old.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: pays % already voided', p_pays_id;
  END IF;

  IF p_from_pot_id IS NOT NULL THEN
    SELECT * INTO v_from_pot FROM public.cashbook_point_pots WHERE id = p_from_pot_id;
    IF v_from_pot.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'invalid_arguments: from_pot % not in tenant', p_from_pot_id;
    END IF;
  END IF;
  IF p_to_pot_id IS NOT NULL THEN
    SELECT * INTO v_to_pot FROM public.cashbook_point_pots WHERE id = p_to_pot_id;
    IF v_to_pot.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'invalid_arguments: to_pot % not in tenant', p_to_pot_id;
    END IF;
  END IF;
  IF v_from_pot.id IS NOT NULL AND v_to_pot.id IS NOT NULL
     AND v_from_pot.currency_code = v_to_pot.currency_code
     AND p_exchange_rate <> 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for same-currency';
  END IF;

  -- I20: old to-pot must still hold credit before reverse (same as rpc_void_pays)
  IF v_old.to_pot_id IS NOT NULL THEN
    v_to_amt := CASE
      WHEN v_old.kind = 'transfer' THEN round(v_old.amount * v_old.exchange_rate, 4)
      ELSE v_old.amount
    END;
    SELECT amount INTO v_to_bal FROM public.cashbook_point_pots WHERE id = v_old.to_pot_id;
    IF v_to_bal < v_to_amt THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot update pays %; to_pot % has % but reverse needs %',
        p_pays_id, v_old.to_pot_id, v_to_bal, v_to_amt;
    END IF;
  END IF;

  -- Reverse old
  DELETE FROM public.bill_settlements
   WHERE pays_id = p_pays_id AND settlement_kind = 'pay';
  UPDATE public.pays
     SET status = 'voided', voided_at = now(), updated_at = now(),
         meta = COALESCE(meta, '{}'::jsonb)
                || jsonb_build_object(
                     'void_reason', p_reason,
                     'replaced_by_key', p_idempotency_key
                   )
   WHERE id = p_pays_id;

  -- Validate new payment against restored due
  IF p_kind = 'payment' THEN
    SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
    IF v_bill.id IS NULL OR v_bill.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'not_found: bill %', p_bill_id;
    END IF;
    IF v_bill.kind = 'credit_note' THEN
      RAISE EXCEPTION
        'invalid_arguments: credit_note cannot be cash-paid; use rpc_apply_document_settlement';
    END IF;
    IF v_bill.status = 'voided' THEN
      RAISE EXCEPTION 'invalid_state: cannot pay voided bill %', p_bill_id;
    END IF;
    -- from_pot must belong to bill.from_profile_id (payer)
    IF v_bill.from_profile_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.cashbook_point_pots pp
        JOIN public.cashbook_points pt ON pt.id = pp.cashbook_point_id
        JOIN public.cashbook_accounts a ON a.id = pt.cashbook_account_id
       WHERE pp.id = p_from_pot_id
         AND a.entity_type = 'profile'
         AND a.entity_id = v_bill.from_profile_id
    ) THEN
      RAISE EXCEPTION
        'invalid_arguments: from_pot must belong to bill.from_profile_id %',
        v_bill.from_profile_id;
    END IF;
    IF v_from_pot.currency_code <> v_bill.currency_code
       OR v_to_pot.currency_code <> v_bill.currency_code THEN
      RAISE EXCEPTION 'invalid_arguments: both pots must match bill currency for payment';
    END IF;
    IF p_exchange_rate <> 1 THEN
      RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for kind=payment';
    END IF;
    v_alloc := round(p_amount, 2);
    v_to_amt := p_amount;
    IF v_alloc > v_bill.due_amount THEN
      RAISE EXCEPTION
        'invalid_amount: allocation % exceeds bill due % (post-void)',
        v_alloc, v_bill.due_amount;
    END IF;
  END IF;

  -- After reverse, from-pot must cover the new debit
  IF p_from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = p_from_pot_id;
    IF v_from_bal < p_amount THEN
      RAISE EXCEPTION
        'insufficient_balance: pot % has % after reverse; new pays needs %',
        p_from_pot_id, v_from_bal, p_amount;
    END IF;
  END IF;

  v_books := round(p_amount * p_books_rate, 4);

  -- Build refs with traceability
  v_new_refs := COALESCE(p_refs, '{}'::jsonb)
                || jsonb_build_object('replaces_pays_id', p_pays_id);
  IF p_kind = 'payment' AND p_bill_id IS NOT NULL THEN
    v_new_refs := v_new_refs || jsonb_build_object('bill_id', p_bill_id);
  END IF;

  INSERT INTO public.pays (
    tenant_id, kind, from_pot_id, to_pot_id,
    amount, currency_code, books_amount, exchange_rate,
    payment_date, status, idempotency_key, refs, meta, created_by
  ) VALUES (
    p_tenant_id, p_kind, p_from_pot_id, p_to_pot_id,
    p_amount,
    COALESCE(v_from_pot.currency_code, v_to_pot.currency_code),
    v_books,
    CASE WHEN p_kind = 'payment' THEN 1 ELSE p_exchange_rate END,
    CURRENT_DATE, 'posted', p_idempotency_key, v_new_refs,
    COALESCE(p_meta, '{}'::jsonb) || jsonb_build_object('update_reason', p_reason),
    auth.uid()
  ) RETURNING * INTO v_new;

  IF p_kind = 'payment' THEN
    INSERT INTO public.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount
    ) VALUES (
      p_tenant_id, p_bill_id, 'pay', v_new.id, NULL, v_alloc, v_books
    ) RETURNING * INTO v_settle;
  END IF;

  IF p_from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM public.cashbook_point_pots WHERE id = p_from_pot_id;
  END IF;
  IF p_to_pot_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM public.cashbook_point_pots WHERE id = p_to_pot_id;
  END IF;

  RETURN jsonb_build_object(
    'voided_pays_id', p_pays_id, 'new_pays_id', v_new.id, 'kind', p_kind,
    'amount', p_amount, 'currency_code', v_new.currency_code,
    'to_amount', v_to_amt, 'allocated_amount', v_alloc, 'bill_id', p_bill_id,
    'from_pot_id', p_from_pot_id, 'to_pot_id', p_to_pot_id,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', 'posted', 'idempotent', false
  );
END;
$$;
```

**Note:** The over-payment check against the restored due runs **after** the old pays is voided — because the old settlement held down the bill's paid_amount. If checked before, valid corrections would be rejected.

---

## 3. Bill Lifecycle RPCs (4)

### 3.1 `rpc_create_bill`

**Purpose:** Create any bill kind. Validates registry, allocates invoice_no, inserts bill + lines + events atomically, optionally issues.

**Idempotency:** Supports `idempotency_key` AND upsert via `(source_type, source_id, source_key)` unique index. Concurrent duplicate inserts catch `unique_violation` and return the winner (`idempotent: true`). A burned `invoice_no` from the losing allocate is acceptable (gap in sequence).

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_create_bill(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tenant_id     bigint := (p_payload->>'tenant_id')::bigint;
  v_issued_by     bigint := COALESCE((p_payload->>'issued_by_tenant_id')::bigint, v_tenant_id);
  v_kind          text   := p_payload->>'kind';
  v_idem          text   := p_payload->>'idempotency_key';
  v_source_type   text   := p_payload->>'source_type';
  v_source_id     text   := p_payload->>'source_id';
  v_source_key    text   := p_payload->>'source_key';
  v_bill          bills;
  v_existing      bills;
  v_registry      bill_kind_registry;
  v_invoice_no    text;
  v_total         numeric(18,4) := 0;
  v_lines         jsonb;
  v_line          jsonb;
  v_line_no       int := 0;
  v_line_total    numeric(18,4);
  v_qty           numeric(18,4);
  v_price         numeric(18,4);
  v_meta          jsonb := COALESCE(p_payload->'meta', '{}'::jsonb);
  v_required_key  text;
BEGIN
  -- Basic validation
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'invalid_arguments: tenant_id required'; END IF;
  PERFORM public.assert_kernel_money_access(v_tenant_id);
  IF v_kind IS NULL THEN RAISE EXCEPTION 'invalid_arguments: kind required'; END IF;

  -- Registry lookup
  SELECT * INTO v_registry FROM public.bill_kind_registry
    WHERE kind = v_kind AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive kind %', v_kind;
  END IF;

  -- required_meta check
  FOREACH v_required_key IN ARRAY v_registry.required_meta LOOP
    IF NOT (v_meta ? v_required_key) THEN
      RAISE EXCEPTION
        'invalid_arguments: kind % requires meta key %', v_kind, v_required_key;
    END IF;
  END LOOP;

  -- Idempotency short-circuit
  IF v_idem IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.bills
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem
        AND status <> 'voided';
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Upsert short-circuit (for source-keyed kinds)
  IF v_source_type IS NOT NULL AND v_source_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.bills
      WHERE tenant_id = v_tenant_id
        AND source_type = v_source_type
        AND source_id = v_source_id
        AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
        AND status <> 'voided';
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Compute total from lines
  v_lines := COALESCE(p_payload->'lines', '[]'::jsonb);
  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: lines required';
  END IF;
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    v_qty   := COALESCE((v_line->>'quantity')::numeric,   1);
    v_price := COALESCE((v_line->>'unit_price')::numeric, 0);
    v_line_total := COALESCE((v_line->>'line_total')::numeric, v_qty * v_price);
    v_total := v_total + v_line_total;
  END LOOP;

  IF v_kind = 'credit_note' THEN
    IF (p_payload->>'parent_bill_id') IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note requires parent_bill_id';
    END IF;
    SELECT * INTO v_existing FROM public.bills
     WHERE id = (p_payload->>'parent_bill_id')::bigint
       AND tenant_id = v_tenant_id;
    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'not_found: parent_bill_id %', (p_payload->>'parent_bill_id')::bigint;
    END IF;
    IF v_existing.status NOT IN ('issued','partial','paid','written_off') THEN
      RAISE EXCEPTION
        'invalid_state: credit_note parent must be issued/partial/paid/written_off, got %',
        v_existing.status;
    END IF;
    -- Parties = swap of parent (payer/payee reversed). Omit both → inherit swap.
    IF (p_payload->>'from_profile_id') IS NULL
       <> ((p_payload->>'to_profile_id') IS NULL) THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note from/to must both be set or both omitted';
    END IF;
    IF (p_payload->>'from_profile_id') IS NOT NULL AND (
         (p_payload->>'from_profile_id')::bigint IS DISTINCT FROM v_existing.to_profile_id
      OR (p_payload->>'to_profile_id')::bigint IS DISTINCT FROM v_existing.from_profile_id
    ) THEN
      RAISE EXCEPTION
        'invalid_arguments: credit_note from/to must be swap of parent (from=parent.to, to=parent.from)';
    END IF;
    -- Only validate when caller sends currency; omitted → inherit parent on INSERT
    IF (p_payload->>'currency_code') IS NOT NULL
       AND (p_payload->>'currency_code') <> v_existing.currency_code THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note currency must match parent';
    END IF;
  END IF;

  -- Allocate invoice_no atomically
  v_invoice_no := public.rpc_allocate_invoice_no(v_tenant_id, v_kind);

  -- Insert bill
  BEGIN
    INSERT INTO public.bills (
      tenant_id, issued_by_tenant_id, kind, status,
      invoice_no, invoice_date, due_date,
      from_profile_id, to_profile_id,
      counterparty_profile_id, counterparty_tenant_id,
      currency_code, total_amount, paid_amount, due_amount, written_off_amount,
      parent_bill_id,
      source_type, source_id, source_key, idempotency_key,
      meta, note, created_by
    ) VALUES (
      v_tenant_id, v_issued_by, v_kind, 'draft',  -- always draft; issue via auto_issue / rpc_issue_bill
      v_invoice_no,
      COALESCE((p_payload->>'invoice_date')::date, CURRENT_DATE),
      (p_payload->>'due_date')::date,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'from_profile_id') IS NULL
           THEN v_existing.to_profile_id
           ELSE (p_payload->>'from_profile_id')::bigint END,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'to_profile_id') IS NULL
           THEN v_existing.from_profile_id
           ELSE (p_payload->>'to_profile_id')::bigint END,
      (p_payload->>'counterparty_profile_id')::bigint,
      (p_payload->>'counterparty_tenant_id')::bigint,
      CASE WHEN v_kind = 'credit_note' THEN v_existing.currency_code
           ELSE COALESCE(p_payload->>'currency_code', 'BDT') END,
      v_total, 0, v_total, 0,
      (p_payload->>'parent_bill_id')::bigint,
      v_source_type, v_source_id, v_source_key, v_idem,
      v_meta,
      p_payload->>'note',
      auth.uid()
    ) RETURNING * INTO v_bill;
  EXCEPTION WHEN unique_violation THEN
    -- Concurrent create with same idempotency_key or source key
    IF v_idem IS NOT NULL THEN
      SELECT * INTO v_bill FROM public.bills
       WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem AND status <> 'voided';
    END IF;
    IF v_bill.id IS NULL AND v_source_type IS NOT NULL AND v_source_id IS NOT NULL THEN
      SELECT * INTO v_bill FROM public.bills
       WHERE tenant_id = v_tenant_id
         AND source_type = v_source_type
         AND source_id = v_source_id
         AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
         AND status <> 'voided';
    END IF;
    IF v_bill.id IS NULL THEN RAISE; END IF;
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', v_bill.status, 'kind', v_bill.kind,
      'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
      'idempotent', true
    );
  END;

  -- Insert lines in one statement
  INSERT INTO public.bill_lines (
    tenant_id, bill_id, line_no, item_kind, product_id,
    description, quantity, unit_price, line_total, meta
  )
  SELECT
    v_tenant_id,
    v_bill.id,
    a.ord::int,
    COALESCE(a.elem->>'item_kind', 'stock'),
    (a.elem->>'product_id')::bigint,
    a.elem->>'description',
    COALESCE((a.elem->>'quantity')::numeric, 1),
    COALESCE((a.elem->>'unit_price')::numeric, 0),
    COALESCE(
      (a.elem->>'line_total')::numeric,
      COALESCE((a.elem->>'quantity')::numeric, 1)
        * COALESCE((a.elem->>'unit_price')::numeric, 0)
    ),
    COALESCE(a.elem->'meta', '{}'::jsonb)
  FROM jsonb_array_elements(v_lines) WITH ORDINALITY AS a(elem, ord);

  -- Optional auto-issue
  IF (p_payload->>'auto_issue')::boolean = true AND v_registry.can_be_issued THEN
    PERFORM public.rpc_issue_bill(v_tenant_id, v_bill.id);
    SELECT * INTO v_bill FROM public.bills WHERE id = v_bill.id;
  END IF;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', v_bill.status, 'kind', v_bill.kind,
    'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
    'idempotent', false
  );
END;
$$;
```

---

### 3.2 `rpc_issue_bill`

**Purpose:** Transition `draft → issued`.

```sql
CREATE OR REPLACE FUNCTION public.rpc_issue_bill(
  p_tenant_id bigint,
  p_bill_id   bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bill     bills;
  v_registry bill_kind_registry;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  IF v_bill.status = 'issued' THEN
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', 'issued', 'idempotent', true
    );
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'invalid_state: cannot issue bill with status %', v_bill.status;
  END IF;
  IF v_bill.from_profile_id IS NULL OR v_bill.to_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: from_profile_id and to_profile_id required before issue';
  END IF;

  SELECT * INTO v_registry FROM public.bill_kind_registry WHERE kind = v_bill.kind;
  IF NOT v_registry.can_be_issued THEN
    RAISE EXCEPTION 'invalid_state: kind % cannot be issued', v_bill.kind;
  END IF;

  UPDATE public.bills
     SET status = 'issued', updated_at = now()
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', 'issued', 'idempotent', false
  );
END;
$$;
```

---

### 3.3 `rpc_void_bill`

**Purpose:** Kill a bill. If `reverse_payments=true`, voids every payment that settled it.

```sql
CREATE OR REPLACE FUNCTION public.rpc_void_bill(
  p_tenant_id        bigint,
  p_bill_id          bigint,
  p_reason           text    DEFAULT NULL,
  p_reverse_payments boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bill          bills;
  v_settlement    record;
  v_reversed_pays bigint[] := '{}';
  v_impact        jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  IF v_bill.status = 'voided' THEN
    RETURN jsonb_build_object(
      'bill_id', p_bill_id, 'status', 'voided',
      'reversed_pays', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  IF NOT p_reverse_payments AND EXISTS (
    SELECT 1 FROM public.bill_settlements
     WHERE bill_id = p_bill_id OR source_bill_id = p_bill_id
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: bill % has settlements; reverse_payments must be true',
      p_bill_id;
  END IF;

  -- Multi-bill pays: voiding this bill must not silently reverse sibling bills
  IF p_reverse_payments AND EXISTS (
    SELECT 1
      FROM public.bill_settlements bs
      JOIN public.bill_settlements other
        ON other.pays_id = bs.pays_id
       AND other.settlement_kind = 'pay'
       AND other.bill_id <> p_bill_id
     WHERE bs.bill_id = p_bill_id
       AND bs.settlement_kind = 'pay'
       AND bs.pays_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: bill % is on a multi-bill pays; call rpc_void_pays on that pays first',
      p_bill_id;
  END IF;

  IF p_reverse_payments THEN
    -- As target of pay/document settles
    FOR v_settlement IN
      SELECT id, settlement_kind, pays_id
        FROM public.bill_settlements
       WHERE bill_id = p_bill_id
    LOOP
      IF v_settlement.settlement_kind = 'pay' AND v_settlement.pays_id IS NOT NULL THEN
        PERFORM public.rpc_void_pays(
          p_tenant_id, v_settlement.pays_id,
          COALESCE(p_reason, 'parent bill voided')
        );
        v_reversed_pays := v_reversed_pays || v_settlement.pays_id;
      ELSIF v_settlement.settlement_kind = 'document' THEN
        PERFORM public.rpc_void_document_settlement(
          p_tenant_id, v_settlement.id,
          COALESCE(p_reason, 'parent bill voided')
        );
      END IF;
    END LOOP;
    -- As credit_note source of document settles
    FOR v_settlement IN
      SELECT id FROM public.bill_settlements
       WHERE source_bill_id = p_bill_id AND settlement_kind = 'document'
    LOOP
      PERFORM public.rpc_void_document_settlement(
        p_tenant_id, v_settlement.id,
        COALESCE(p_reason, 'credit note voided')
      );
    END LOOP;
  END IF;

  UPDATE public.bills
     SET status             = 'voided',
         due_amount         = 0,
         written_off_amount = 0,
         updated_at         = now(),
         note               = COALESCE(note, '') || E'\n[voided] ' || COALESCE(p_reason, '')
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id, 'status', 'voided',
    'reversed_pays', to_jsonb(v_reversed_pays),
    'payments_reversed', p_reverse_payments,
    'idempotent', false
  );
END;
$$;
```

**T4:** `draft → voided` is allowed (cancel draft). `issued`/`partial`/`paid`/`written_off → voided` also allowed.

---

### 3.4 `rpc_write_off_bill`

**Purpose:** Forgive part or all of a bill's due. No money movement.

```sql
CREATE OR REPLACE FUNCTION public.rpc_write_off_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_amount    numeric,
  p_reason    text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bill        bills;
  v_new_due     numeric;
  v_new_written numeric;
  v_new_status  text;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: reason is required';
  END IF;

  SELECT * INTO v_bill FROM public.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;
  IF v_bill.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: cannot write off voided bill %', p_bill_id;
  END IF;
  IF v_bill.kind = 'credit_note' THEN
    RAISE EXCEPTION
      'invalid_arguments: credit_note cannot be written off; void or apply it';
  END IF;
  IF p_amount > v_bill.due_amount THEN
    RAISE EXCEPTION
      'invalid_amount: write-off % exceeds due %', p_amount, v_bill.due_amount;
  END IF;

  v_new_due     := v_bill.due_amount         - p_amount;
  v_new_written := v_bill.written_off_amount + p_amount;
  v_new_status  := public.derive_bill_status(
    v_bill.total_amount, v_bill.paid_amount, v_new_due, v_new_written
  );

  UPDATE public.bills
     SET due_amount         = v_new_due,
         written_off_amount = v_new_written,
         status             = v_new_status,
         updated_at         = now(),
         meta               = COALESCE(meta, '{}'::jsonb)
                              || jsonb_build_object(
                                   'last_write_off_reason', p_reason,
                                   'last_write_off_at',     now()
                                 )
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id, 'status', v_new_status,
    'written_off_amount', v_new_written, 'due_amount', v_new_due,
    'idempotent', false
  );
END;
$$;
```

---

## 4. Provisioning RPCs (2)

### 4.1 `rpc_provision_cashbook_currency`

**Purpose:** Ensure a profile has a point + pot for a currency. Used at onboarding (extra currencies) and lazily when a new currency is needed.

```sql
CREATE OR REPLACE FUNCTION public.rpc_provision_cashbook_currency(
  p_tenant_id     bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_pot_id     bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT id INTO v_account_id FROM public.cashbook_accounts
    WHERE tenant_id = p_tenant_id AND entity_type = 'profile'
      AND entity_id = p_profile_id;
  IF v_account_id IS NULL THEN
    RAISE EXCEPTION
      'not_found: cashbook account for profile %; profile may not exist', p_profile_id;
  END IF;

  SELECT id INTO v_point_id FROM public.cashbook_points
    WHERE cashbook_account_id = v_account_id AND code = p_point_code;
  IF v_point_id IS NULL THEN
    INSERT INTO public.cashbook_points
      (tenant_id, cashbook_account_id, code, name)
    VALUES
      (p_tenant_id, v_account_id, p_point_code, initcap(p_point_code))
    RETURNING id INTO v_point_id;
  END IF;

  INSERT INTO public.cashbook_point_pots
    (tenant_id, cashbook_point_id, currency_code)
  VALUES
    (p_tenant_id, v_point_id, p_currency_code)
  ON CONFLICT (cashbook_point_id, currency_code) DO NOTHING
  RETURNING id INTO v_pot_id;

  IF v_pot_id IS NULL THEN
    SELECT id INTO v_pot_id FROM public.cashbook_point_pots
      WHERE cashbook_point_id = v_point_id AND currency_code = p_currency_code;
  END IF;

  RETURN jsonb_build_object(
    'cashbook_account_id', v_account_id,
    'cashbook_point_id',   v_point_id,
    'pot_id',              v_pot_id,
    'currency_code',       p_currency_code
  );
END;
$$;
```

---

### 4.2 `rpc_provision_tenant_cashbook`

**Purpose:** Ensure the tenant's own cashbook exists with a pot in the given currency. Required before `rpc_pay_bill` can use the default to-pot resolver.

```sql
CREATE OR REPLACE FUNCTION public.rpc_provision_tenant_cashbook(
  p_tenant_id     bigint,
  p_currency_code text DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_pot_id     bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  INSERT INTO public.cashbook_accounts (tenant_id, entity_type, entity_id)
  VALUES (p_tenant_id, 'tenant', p_tenant_id)
  ON CONFLICT (tenant_id, entity_type, entity_id) DO NOTHING
  RETURNING id INTO v_account_id;

  IF v_account_id IS NULL THEN
    SELECT id INTO v_account_id FROM public.cashbook_accounts
      WHERE tenant_id = p_tenant_id AND entity_type = 'tenant'
        AND entity_id = p_tenant_id;
  END IF;

  SELECT id INTO v_point_id FROM public.cashbook_points
    WHERE cashbook_account_id = v_account_id AND code = 'main';
  IF v_point_id IS NULL THEN
    INSERT INTO public.cashbook_points
      (tenant_id, cashbook_account_id, code, name)
    VALUES (p_tenant_id, v_account_id, 'main', 'Main')
    RETURNING id INTO v_point_id;
  END IF;

  INSERT INTO public.cashbook_point_pots
    (tenant_id, cashbook_point_id, currency_code)
  VALUES (p_tenant_id, v_point_id, p_currency_code)
  ON CONFLICT (cashbook_point_id, currency_code) DO NOTHING
  RETURNING id INTO v_pot_id;

  IF v_pot_id IS NULL THEN
    SELECT id INTO v_pot_id FROM public.cashbook_point_pots
      WHERE cashbook_point_id = v_point_id AND currency_code = p_currency_code;
  END IF;

  UPDATE public.cashbook_accounts
     SET default_cashbook_point_pot_id = COALESCE(default_cashbook_point_pot_id, v_pot_id)
   WHERE id = v_account_id;

  RETURN jsonb_build_object(
    'cashbook_account_id', v_account_id,
    'cashbook_point_id',   v_point_id,
    'pot_id',              v_pot_id,
    'currency_code',       p_currency_code
  );
END;
$$;
```

---

## 5. Internal RPC (1)

### 5.1 `rpc_allocate_invoice_no`

**Purpose:** Atomic sequence allocation. Called only by `rpc_create_bill`.

**`SECURITY DEFINER`** — owns writes to `invoice_no_counters`, which the calling role cannot touch.

```sql
CREATE OR REPLACE FUNCTION public.rpc_allocate_invoice_no(
  p_tenant_id bigint,
  p_kind      text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prefix text;
  v_seq    bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT numbering_prefix INTO v_prefix FROM public.bill_kind_registry
    WHERE kind = p_kind AND is_active = true;
  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive kind %', p_kind;
  END IF;

  INSERT INTO public.invoice_no_counters (tenant_id, prefix, next_seq)
    VALUES (p_tenant_id, v_prefix, 2)
  ON CONFLICT (tenant_id, prefix)
  DO UPDATE SET next_seq = public.invoice_no_counters.next_seq + 1
  RETURNING next_seq - 1 INTO v_seq;

  RETURN v_prefix || '-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-'
         || lpad(v_seq::text, 5, '0');
END;
$$;
```

**Format:** `<prefix>-<YYYYMMDD>-<5-digit-sequence>` → e.g. `INV-WS-20261110-00042`.

**Concurrency:** The `ON CONFLICT DO UPDATE` handles two simultaneous allocators — one gets seq N, the other N+1. No gap unless a transaction rolls back after allocation (acceptable — invoice numbers need not be gapless, only unique).

---

## 6. Grants

```sql
-- Revoke Supabase defaults (PUBLIC does not remove anon/authenticated grants)
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- Public RPCs (16 only — not rpc_allocate_invoice_no)
GRANT EXECUTE ON FUNCTION public.rpc_deposit                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_withdraw                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_transfer_same_profile       TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_transfer_p2p                TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_pay_bills                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_pay_bill                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_apply_document_settlement   TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_void_document_settlement    TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_void_pays                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_pays                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_create_bill                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_issue_bill                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_void_bill                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_write_off_bill              TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_provision_cashbook_currency TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_provision_tenant_cashbook   TO authenticated;

-- Internal allocator: NOT granted to authenticated
-- (called via rpc_create_bill, but the EXECUTE privilege inside a DEFINER function comes from owner)
REVOKE ALL ON FUNCTION public.rpc_allocate_invoice_no FROM PUBLIC;
```

**`rpc_allocate_invoice_no`:** not granted to `authenticated`. Same owner as `rpc_create_bill` (DEFINER) can call it internally.

---

## Read RPCs

**6 read RPCs.** Prefer these and the views below over raw `SELECT` on kernel tables.

### Inventory

| # | RPC | Purpose | Category |
|---|---|---|---|
| R1 | `rpc_get_bill` | Single bill + selected includes | Single entity |
| R2 | `rpc_query_bills` | Universal filtered / grouped / paginated bill query | List / aggregation |
| R3 | `rpc_get_pot_balance` | Single pot balance lookup | Single entity |
| R4 | `rpc_get_pot_balances` | Bulk pot balance lookup | Bulk |
| R5 | `rpc_profile_transactions` | Statement with running balance | Ledger |
| R6 | `rpc_list_bill_kinds` | Registry discovery | Metadata |

### Common principles

- **Read-only.** Never write. Safe to retry, safe to call from any client.
- **`SECURITY INVOKER`.** RLS scopes rows to `auth.uid()`'s tenant(s) unless the caller has elevated role.
- **`jsonb` response.** Consistent envelope; list RPCs include `echoed_filters`. Read calls are safe to retry but are not write-idempotent.
- **Pagination.** List/ledger RPCs use **cursor (keyset)** pagination: `p_limit` + `p_cursor` → `has_more` + `next_cursor`. No `page`, `OFFSET`, `total_count`, or `total_pages`.
- **No `SELECT *` in results.** Every response field is named and stable — adding columns later never breaks consumers.
- **Performance.** All RPCs target < 100ms p99 for pages of 50 rows. Heavier queries should be moved to the reporting layer's materialized views.

### Error format

All read RPCs raise with prefixed messages consistent with write RPCs:

- `not_found:` — entity doesn't exist or is outside tenant scope
- `invalid_arguments:` — bad filter / pagination
- `access_denied:` — RLS or explicit check failed

### Response envelope

Every read RPC returns:

```json
{
  "echoed_filters": {...},
  "rows": [...],
  "limit": N,
  "has_more": true,
  "next_cursor": { "k": "...", "id": 123 },
  // ...plus RPC-specific fields (no page / total_count / total_pages)
}
```

For single-entity RPCs (R1, R3), list pagination fields are absent; the entity fields are at the top level.

---

## 2. R1 — `rpc_get_bill`

**Purpose:** Fetch one bill with selected related data in one call. Replaces multiple round-trips from bill-detail screens.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_get_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_include   text[] DEFAULT '{lines}'
    -- any subset of: lines | settlements | events | meta_expanded
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_bill       bills;
  v_result     jsonb;
  v_lines      jsonb;
  v_settlements jsonb;
  v_events     jsonb;
  v_meta_exp   jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id are required';
  END IF;

  SELECT * INTO v_bill FROM public.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  -- Core bill fields (always present)
  v_result := jsonb_build_object(
    'bill_id',                 v_bill.id,
    'tenant_id',               v_bill.tenant_id,
    'issued_by_tenant_id',     v_bill.issued_by_tenant_id,
    'kind',                    v_bill.kind,
    'status',                  v_bill.status,
    'invoice_no',              v_bill.invoice_no,
    'invoice_date',            v_bill.invoice_date,
    'due_date',                v_bill.due_date,
    'from_profile_id',         v_bill.from_profile_id,
    'to_profile_id',           v_bill.to_profile_id,
    'counterparty_profile_id', v_bill.counterparty_profile_id,
    'counterparty_tenant_id',  v_bill.counterparty_tenant_id,
    'currency_code',           v_bill.currency_code,
    'total_amount',            v_bill.total_amount,
    'paid_amount',             v_bill.paid_amount,
    'due_amount',              v_bill.due_amount,
    'written_off_amount',      v_bill.written_off_amount,
    'parent_bill_id',          v_bill.parent_bill_id,
    'source_type',             v_bill.source_type,
    'source_id',               v_bill.source_id,
    'source_key',              v_bill.source_key,
    'note',                    v_bill.note,
    'meta',                    v_bill.meta,
    'created_by',              v_bill.created_by,
    'created_at',              v_bill.created_at,
    'updated_at',              v_bill.updated_at
  );

  -- Lines
  IF 'lines' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',          bl.id,
      'line_no',     bl.line_no,
      'item_kind',   bl.item_kind,
      'product_id',  bl.product_id,
      'description', bl.description,
      'quantity',    bl.quantity,
      'unit_price',  bl.unit_price,
      'line_total',  bl.line_total,
      'meta',        bl.meta
    ) ORDER BY bl.line_no), '[]'::jsonb)
    INTO v_lines
    FROM public.bill_lines bl WHERE bl.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('lines', v_lines);
  END IF;

  -- Settlements (payments applied)
  IF 'settlements' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'settlement_id',          bs.id,
      'settlement_kind',        bs.settlement_kind,
      'pays_id',                bs.pays_id,
      'source_bill_id',         bs.source_bill_id,
      'allocated_amount',       bs.allocated_amount,
      'allocated_books_amount', bs.allocated_books_amount,
      'payment_date',           p.payment_date,
      'payment_kind',           p.kind,
      'payment_status',         p.status,
      'payment_amount',         p.amount,
      'payment_currency',       p.currency_code,
      'from_pot_id',            p.from_pot_id,
      'to_pot_id',              p.to_pot_id,
      'payment_meta',           p.meta,
      'settled_at',             bs.created_at
    ) ORDER BY bs.created_at DESC), '[]'::jsonb)
    INTO v_settlements
    FROM public.bill_settlements bs
    LEFT JOIN public.pays p ON p.id = bs.pays_id
    WHERE bs.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('settlements', v_settlements);
  END IF;

  -- Events (lifecycle)
  IF 'events' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_id',   be.id,
      'event_type', be.event_type,
      'payload',    be.payload,
      'actor_id',   be.actor_id,
      'created_at', be.created_at
    ) ORDER BY be.created_at DESC, be.id DESC), '[]'::jsonb)
    INTO v_events
    FROM public.bill_events be WHERE be.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('events', v_events);
  END IF;

  -- Meta expanded: raw meta + well-known keys extracted for typed access
  IF 'meta_expanded' = ANY(p_include) THEN
    v_meta_exp := jsonb_build_object(
      'raw', v_bill.meta,
      'well_known', jsonb_build_object(
        'shipment_id',          (v_bill.meta->>'shipment_id')::bigint,
        'ap_kind',              v_bill.meta->>'ap_kind',
        'original_bill_id',     (v_bill.meta->>'original_bill_id')::bigint,
        'retail_billing_mode',  v_bill.meta->>'retail_billing_mode',
        'reason',               v_bill.meta->>'reason'
      )
    );
    v_result := v_result || jsonb_build_object('meta_expanded', v_meta_exp);
  END IF;

  RETURN v_result || jsonb_build_object('echoed_filters', jsonb_build_object(
    'tenant_id', p_tenant_id,
    'bill_id',   p_bill_id,
    'include',   to_jsonb(p_include)
  ));
END;
$$;
```

**Parameters**

| Param | Type | Required | Notes |
|---|---|---|---|
| `p_tenant_id` | bigint | yes | Scope check |
| `p_bill_id` | bigint | yes | The bill |
| `p_include` | text[] | no | Default `{lines}`; subset of `lines`, `settlements`, `events`, `meta_expanded` |

**Indexes used**

- `bills` PK on `id`
- `bill_lines_ix_bill` (via `bill_id` in where)
- `bill_settlements_ix_bill`
- `bill_events_bill_ix`

**Use cases**

| Consumer | Include |
|---|---|
| Bill detail screen | `['lines','settlements','events']` |
| Report drill-down | `['lines']` |
| Audit view | `['events']` |
| Payment history | `['settlements']` |
| Admin with meta inspection | `['lines','meta_expanded']` |

**Errors**

| Error | Cause |
|---|---|
| `invalid_arguments` | Missing tenant_id or bill_id |
| `not_found` | Bill doesn't exist or is outside tenant scope |

---

## 3. R2 — `rpc_query_bills`

**Purpose:** The universal query engine. Filters, groups, **cursor-paginates** rows. Replaces `list_bills`, `get_bills_by_source`, `get_open_bills`, and any other bill-list RPC.

**Cursor:** `p_cursor = {"k": <sort key>, "id": <bill_id>}` from prior `next_cursor`. Sort key matches `p_order_by` (all DESC + `id DESC`). Fetch `limit+1` to set `has_more`. No totals.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_query_bills(
  p_tenant_id          bigint,
  p_kinds              text[]      DEFAULT NULL,
  p_statuses           text[]      DEFAULT NULL,
  p_source_type        text        DEFAULT NULL,
  p_source_id          text        DEFAULT NULL,
  p_source_key         text        DEFAULT NULL,
  p_counterparty_profile_id  bigint  DEFAULT NULL,
  p_counterparty_tenant_id   bigint  DEFAULT NULL,
  p_parent_bill_id     bigint      DEFAULT NULL,
  p_invoice_no         text        DEFAULT NULL,
  p_from_date          date        DEFAULT NULL,
  p_to_date            date        DEFAULT NULL,
  p_due_before         date        DEFAULT NULL,
  p_has_due            boolean     DEFAULT NULL,
  p_changed_since      timestamptz DEFAULT NULL,
  p_include_voided     boolean     DEFAULT false,
  p_include            text[]      DEFAULT '{summary}',
    -- any subset of: summary | lines | settlements | events
  p_group_by           text        DEFAULT NULL,
    -- NULL (rows) | kind | status | counterparty | month  (groups: no cursor; full agg)
  p_order_by           text        DEFAULT 'invoice_date DESC, id DESC',
  p_limit              int         DEFAULT 50,
  p_cursor             jsonb       DEFAULT NULL
    -- {"k": "...", "id": 123}; null = first page
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_order_mode text;
  v_result     jsonb;
  v_rows       jsonb;
  v_groups     jsonb;
  v_filters    jsonb;
  v_has_more   boolean := false;
  v_next       jsonb := NULL;
  v_cursor_id  bigint;
  v_cursor_k   text;
  v_include_lines        boolean := 'lines'       = ANY(p_include);
  v_include_settlements  boolean := 'settlements' = ANY(p_include);
  v_include_events       boolean := 'events'      = ANY(p_include);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_group_by IS NULL
     AND (v_include_lines OR v_include_settlements OR v_include_events)
     AND p_limit > 50 THEN
    RAISE EXCEPTION 'invalid_arguments: heavy includes require limit <= 50';
  END IF;
  IF p_group_by IS NOT NULL AND p_group_by NOT IN ('kind','status','counterparty','month') THEN
    RAISE EXCEPTION
      'invalid_arguments: group_by must be kind/status/counterparty/month, got %', p_group_by;
  END IF;
  IF p_cursor IS NOT NULL AND (p_cursor ? 'id') IS NOT TRUE THEN
    RAISE EXCEPTION 'invalid_arguments: cursor requires id';
  END IF;

  v_order_mode := CASE
    WHEN p_order_by LIKE '%created_at%'   THEN 'created_at'
    WHEN p_order_by LIKE '%updated_at%'   THEN 'updated_at'
    WHEN p_order_by LIKE '%due_date%'     THEN 'due_date'
    WHEN p_order_by LIKE '%total_amount%' THEN 'total_amount'
    WHEN p_order_by LIKE '%due_amount%'   THEN 'due_amount'
    ELSE 'invoice_date'
  END;

  IF p_cursor IS NOT NULL THEN
    v_cursor_id := (p_cursor->>'id')::bigint;
    v_cursor_k  := p_cursor->>'k';
    IF v_cursor_id IS NULL OR v_cursor_k IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires k and id';
    END IF;
  END IF;

  -- Rows mode (cursor keyset)
  IF p_group_by IS NULL THEN
    WITH filtered AS (
      SELECT b.*
      FROM public.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
        AND (
          p_cursor IS NULL
          OR CASE v_order_mode
               WHEN 'invoice_date' THEN
                 (b.invoice_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'created_at' THEN
                 (b.created_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'updated_at' THEN
                 (b.updated_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'due_date' THEN
                 (b.due_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'total_amount' THEN
                 (b.total_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
               WHEN 'due_amount' THEN
                 (b.due_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
             END
        )
      ORDER BY
        CASE v_order_mode WHEN 'invoice_date'  THEN b.invoice_date  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'created_at'    THEN b.created_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'updated_at'    THEN b.updated_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_date'      THEN b.due_date      END DESC NULLS LAST,
        CASE v_order_mode WHEN 'total_amount'  THEN b.total_amount  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_amount'    THEN b.due_amount    END DESC NULLS LAST,
        b.id DESC
      LIMIT p_limit + 1
    ),
    page_rows AS (
      SELECT f.*, row_number() OVER () AS _rn
        FROM filtered f
       LIMIT p_limit
    )
    SELECT
      (SELECT count(*) > p_limit FROM filtered),
      COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'bill_id',                 b.id,
          'tenant_id',               b.tenant_id,
          'issued_by_tenant_id',     b.issued_by_tenant_id,
          'kind',                    b.kind,
          'status',                  b.status,
          'invoice_no',              b.invoice_no,
          'invoice_date',            b.invoice_date,
          'due_date',                b.due_date,
          'counterparty_profile_id', b.counterparty_profile_id,
          'counterparty_tenant_id',  b.counterparty_tenant_id,
          'currency_code',           b.currency_code,
          'total_amount',            b.total_amount,
          'paid_amount',             b.paid_amount,
          'due_amount',              b.due_amount,
          'written_off_amount',      b.written_off_amount,
          'parent_bill_id',          b.parent_bill_id,
          'source_type',             b.source_type,
          'source_id',               b.source_id,
          'source_key',              b.source_key,
          'note',                    b.note,
          'meta',                    b.meta,
          'created_at',              b.created_at,
          'updated_at',              b.updated_at,
          'lines', CASE WHEN v_include_lines THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'id', bl.id, 'line_no', bl.line_no, 'item_kind', bl.item_kind,
              'product_id', bl.product_id, 'description', bl.description,
              'quantity', bl.quantity, 'unit_price', bl.unit_price,
              'line_total', bl.line_total, 'meta', bl.meta
            ) ORDER BY bl.line_no)
            FROM public.bill_lines bl WHERE bl.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'settlements', CASE WHEN v_include_settlements THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'settlement_id', bs.id,
              'pays_id', bs.pays_id,
              'allocated_amount', bs.allocated_amount,
              'payment_date', p.payment_date,
              'payment_status', p.status
            ) ORDER BY bs.created_at DESC)
            FROM public.bill_settlements bs
            LEFT JOIN public.pays p ON p.id = bs.pays_id
            WHERE bs.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'events', CASE WHEN v_include_events THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'event_id', be.id, 'event_type', be.event_type,
              'payload', be.payload, 'created_at', be.created_at
            ) ORDER BY be.created_at DESC)
            FROM public.bill_events be WHERE be.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END
        ) ORDER BY
          CASE v_order_mode WHEN 'invoice_date' THEN b.invoice_date END DESC NULLS LAST,
          CASE v_order_mode WHEN 'created_at'   THEN b.created_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'updated_at'   THEN b.updated_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_date'     THEN b.due_date     END DESC NULLS LAST,
          CASE v_order_mode WHEN 'total_amount' THEN b.total_amount END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_amount'   THEN b.due_amount   END DESC NULLS LAST,
          b.id DESC
        )
        FROM page_rows b
      ), '[]'::jsonb),
      (
        SELECT CASE v_order_mode
          WHEN 'invoice_date'  THEN jsonb_build_object('k', b.invoice_date::text,  'id', b.id)
          WHEN 'created_at'    THEN jsonb_build_object('k', b.created_at::text,    'id', b.id)
          WHEN 'updated_at'    THEN jsonb_build_object('k', b.updated_at::text,    'id', b.id)
          WHEN 'due_date'      THEN jsonb_build_object('k', b.due_date::text,      'id', b.id)
          WHEN 'total_amount'  THEN jsonb_build_object('k', b.total_amount::text,  'id', b.id)
          WHEN 'due_amount'    THEN jsonb_build_object('k', b.due_amount::text,    'id', b.id)
        END
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
    INTO v_has_more, v_rows, v_next;

    IF NOT v_has_more THEN v_next := NULL; END IF;

    v_result := jsonb_build_object(
      'rows',         v_rows,
      'limit',        p_limit,
      'has_more',     v_has_more,
      'next_cursor',  v_next
    );

  -- Group mode: full aggregation (no cursor / no totals envelope)
  ELSE
    WITH filtered AS (
      SELECT b.*
      FROM public.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
    ),
    grouped AS (
      SELECT
        CASE p_group_by
          WHEN 'kind'         THEN b.kind
          WHEN 'status'       THEN b.status
          WHEN 'counterparty' THEN COALESCE(b.counterparty_profile_id::text,
                                            b.counterparty_tenant_id::text,
                                            '(none)')
          WHEN 'month'        THEN to_char(b.invoice_date, 'YYYY-MM')
        END AS group_key,
        COUNT(*)                                      AS cnt,
        COALESCE(SUM(b.total_amount),       0)::numeric(18,4) AS sum_total,
        COALESCE(SUM(b.paid_amount),        0)::numeric(18,4) AS sum_paid,
        COALESCE(SUM(b.due_amount),         0)::numeric(18,4) AS sum_due,
        COALESCE(SUM(b.written_off_amount), 0)::numeric(18,4) AS sum_written_off
      FROM filtered b
      GROUP BY 1
    )
    SELECT COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'key',              g.group_key,
        'count',            g.cnt,
        'sum_total_amount', g.sum_total,
        'sum_paid_amount',  g.sum_paid,
        'sum_due_amount',   g.sum_due,
        'sum_written_off_amount', g.sum_written_off
      ) ORDER BY g.group_key ASC NULLS LAST)
      FROM grouped g
    ), '[]'::jsonb)
    INTO v_groups;

    v_result := jsonb_build_object(
      'groups',   v_groups,
      'group_by', p_group_by
    );
  END IF;

  v_filters := jsonb_build_object(
    'tenant_id',            p_tenant_id,
    'kinds',                p_kinds,
    'statuses',             p_statuses,
    'source_type',          p_source_type,
    'source_id',            p_source_id,
    'source_key',           p_source_key,
    'counterparty_profile_id', p_counterparty_profile_id,
    'counterparty_tenant_id',  p_counterparty_tenant_id,
    'parent_bill_id',       p_parent_bill_id,
    'invoice_no',           p_invoice_no,
    'from_date',            p_from_date,
    'to_date',              p_to_date,
    'due_before',           p_due_before,
    'has_due',              p_has_due,
    'changed_since',        p_changed_since,
    'include_voided',       p_include_voided,
    'include',              to_jsonb(p_include),
    'group_by',             p_group_by,
    'order_by',             p_order_by,
    'limit',                p_limit,
    'cursor',               p_cursor
  );

  RETURN v_result || jsonb_build_object('echoed_filters', v_filters);
END;
$$;
```

**Parameters**

| Param | Type | Default | Notes |
|---|---|---|---|
| `p_tenant_id` | bigint | — | Required scope |
| `p_kinds` | text[] | NULL | Filter by kind(s); NULL = all |
| `p_statuses` | text[] | NULL | Filter by status(es) |
| `p_source_type` | text | NULL | External source pointer |
| `p_source_id` | text | NULL | |
| `p_source_key` | text | NULL | |
| `p_counterparty_profile_id` | bigint | NULL | Statement use |
| `p_counterparty_tenant_id` | bigint | NULL | B2B use |
| `p_parent_bill_id` | bigint | NULL | Credit/debit note linkage |
| `p_invoice_no` | text | NULL | Exact or prefix (`ILIKE x%`) |
| `p_from_date` | date | NULL | `invoice_date >=` |
| `p_to_date` | date | NULL | `invoice_date <=` |
| `p_due_before` | date | NULL | `due_amount > 0 AND due_date <=` — for aging |
| `p_has_due` | boolean | NULL | `true` = due > 0; `false` = due = 0 |
| `p_changed_since` | timestamptz | NULL | For refresh workers |
| `p_include_voided` | boolean | false | Include voided bills |
| `p_include` | text[] | `{summary}` | `summary` \| `lines` \| `settlements` \| `events` |
| `p_group_by` | text | NULL | `NULL` (rows) \| `kind` \| `status` \| `counterparty` \| `month` |
| `p_order_by` | text | `invoice_date DESC, id DESC` | Whitelisted; cursor sorts are all DESC + id |
| `p_limit` | int | 50 | Max 500 (≤ 50 with heavy includes) |
| `p_cursor` | jsonb | NULL | `{"k","id"}` from prior `next_cursor` |

**Return shapes**

**Rows mode** (`p_group_by IS NULL`):

```json
{
  "rows": [ { bill fields, lines?, settlements?, events? } ],
  "limit": 50,
  "has_more": true,
  "next_cursor": { "k": "2026-03-01", "id": 9001 },
  "echoed_filters": { ... }
}
```

**Group mode** (`p_group_by IS NOT NULL`) — full agg, no cursor:

```json
{
  "groups": [
    { "key": "sales_invoice_wholesale", "count": 12, "sum_total_amount": 5000, ... }
  ],
  "group_by": "kind",
  "echoed_filters": { ... }
}
```

**Indexes used**

| Filter | Index |
|---|---|
| `tenant_id` + `status` + `kind` | `ix_bills_tenant_status_kind` |
| `source_type` + `source_id` | `ix_bills_source` |
| `counterparty_profile_id` | `ix_bills_counterparty` |
| `parent_bill_id` | `ix_bills_parent` |
| `updated_at` (changed_since) | PK scan (accepts cost for freshness check) |
| Order by invoice_date | PK scan + sort |
| Order by total/due | Sequential (rare) |

**Performance notes**

- `p_changed_since` filter uses `updated_at` — for high-volume refresh workers this should be capped (`p_to_date` + `p_from_date` around the refresh window) to avoid full scans.
- `p_include` with `lines` for `limit` 500 could return 5,000+ line rows — enforced cap `limit <= 50` with heavy includes.
- Prefer `next_cursor` loops over any client-side offset math.

**Use cases**

| Scenario | Parameters |
|---|---|
| Shipment profit report — AP bills for shipment | `source_type='shipment', source_id='1234', kinds=['shipment_cost_ap'], include=['summary']` |
| Shipment profit report — AR lines | `source_type='order', source_id IN (...)`, then use `v_bill_lines_unified` for COGS |
| Dropship profit report | `source_type='shop_order', source_id='8842'` |
| AR aging | `has_due=true, due_before=today, group_by='counterparty'` |
| AP aging | `kinds=['shipment_cost_ap','dropship_courier_ap'], has_due=true, group_by='counterparty'` |
| Customer statement — bill side | `counterparty_profile_id=42, order_by='invoice_date DESC'` |
| Bill list screen | filters + `limit` / `cursor` |
| Dashboard by kind | `group_by='kind'` |
| Dashboard by month | `group_by='month'` |
| Refresh worker | `changed_since=<last_timestamp>, include=[]` |
| Bill detail screen search | `invoice_no='INV-2026'` (prefix) |

**Errors**

| Error | Cause |
|---|---|
| `invalid_arguments: limit must be 1..500` | Bad limit |
| `invalid_arguments: cursor requires k and id` | Bad cursor |
| `invalid_arguments: group_by must be ...` | Unknown group |
| `invalid_arguments: tenant_id required` | Missing scope |

---

## 4. R3 — `rpc_get_pot_balance`

**Purpose:** Single pot balance lookup. O(1).

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_get_pot_balance(
  p_tenant_id    bigint,
  p_pot_id       bigint  DEFAULT NULL,
  p_entity_type  text    DEFAULT NULL,
  p_entity_id    bigint  DEFAULT NULL,
  p_currency     text    DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_pot     cashbook_point_pots;
  v_account cashbook_accounts;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  IF p_pot_id IS NOT NULL THEN
    -- Lookup by pot id
    SELECT pp.* INTO v_pot
      FROM public.cashbook_point_pots pp
      WHERE pp.id = p_pot_id AND pp.tenant_id = p_tenant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pot % in tenant %', p_pot_id, p_tenant_id;
    END IF;

    -- Resolve entity for the response
    SELECT a.* INTO v_account
      FROM public.cashbook_points pt
      JOIN public.cashbook_accounts a ON a.id = pt.cashbook_account_id
     WHERE pt.id = v_pot.cashbook_point_id;

  ELSIF p_entity_type IS NOT NULL AND p_entity_id IS NOT NULL THEN
    -- Lookup by entity + currency (uses default pot pointer first)
    SELECT pp.* INTO v_pot
      FROM public.cashbook_accounts a
      LEFT JOIN public.cashbook_point_pots pp_default
        ON pp_default.id = a.default_cashbook_point_pot_id
      JOIN public.cashbook_points pt ON pt.cashbook_account_id = a.id
      JOIN public.cashbook_point_pots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id
       AND a.entity_type = p_entity_type
       AND a.entity_id = p_entity_id
       AND pp.currency_code = p_currency
     ORDER BY (a.default_cashbook_point_pot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'not_found: no % pot for entity %/%', p_currency, p_entity_type, p_entity_id;
    END IF;

    SELECT * INTO v_account FROM public.cashbook_accounts
      WHERE tenant_id = p_tenant_id AND entity_type = p_entity_type
        AND entity_id = p_entity_id;

  ELSE
    RAISE EXCEPTION
      'invalid_arguments: must pass pot_id OR (entity_type AND entity_id)';
  END IF;

  RETURN jsonb_build_object(
    'pot_id',          v_pot.id,
    'tenant_id',       v_pot.tenant_id,
    'cashbook_point_id', v_pot.cashbook_point_id,
    'entity_type',     v_account.entity_type,
    'entity_id',       v_account.entity_id,
    'currency_code',   v_pot.currency_code,
    'amount',          v_pot.amount,
    'updated_at',      v_pot.updated_at,
    'echoed_filters',  jsonb_build_object(
      'pot_id',      p_pot_id,
      'entity_type', p_entity_type,
      'entity_id',   p_entity_id,
      'currency',    p_currency
    )
  );
END;
$$;
```

**Parameters**

| Param | Type | Notes |
|---|---|---|
| `p_tenant_id` | bigint | Required |
| `p_pot_id` | bigint | Option A: direct lookup |
| `p_entity_type` | text | Option B: with entity_id |
| `p_entity_id` | bigint | Option B |
| `p_currency` | text | Default `BDT` |

**Return**

```json
{
  "pot_id": 55,
  "tenant_id": 1,
  "cashbook_point_id": 12,
  "entity_type": "profile",
  "entity_id": 42,
  "currency_code": "BDT",
  "amount": 5500.0000,
  "updated_at": "2026-11-10T14:22:01Z",
  "echoed_filters": {...}
}
```

**Indexes used**

- `cashbook_point_pots` PK
- `cashbook_accounts` UQ `(tenant_id, entity_type, entity_id)`
- `cashbook_points` UQ `(cashbook_account_id, code)`

**Use cases**

| Consumer | Call |
|---|---|
| Cash tile on dashboard | `p_entity_type='profile', p_entity_id=X` |
| Tenant collection pot | `p_entity_type='tenant', p_entity_id=tenant_id` |
| Detail on specific pot | `p_pot_id=X` |

**Errors**

- `invalid_arguments: must pass pot_id OR (entity_type AND entity_id)`
- `not_found: pot / entity ...`

---

## 5. R4 — `rpc_get_pot_balances`

**Purpose:** Bulk pot lookup. For dashboards, cash-position overviews, bulk billing runs.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_get_pot_balances(
  p_tenant_id    bigint,
  p_entity_type  text    DEFAULT 'profile',
  p_entity_ids   bigint[] DEFAULT NULL,
  p_currencies   text[]  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'pot_id',        pp.id,
    'entity_type',   a.entity_type,
    'entity_id',     a.entity_id,
    'currency_code', pp.currency_code,
    'amount',        pp.amount,
    'updated_at',    pp.updated_at
  ) ORDER BY a.entity_id, pp.currency_code), '[]'::jsonb)
  INTO v_rows
  FROM public.cashbook_point_pots pp
  JOIN public.cashbook_points   pt ON pt.id = pp.cashbook_point_id
  JOIN public.cashbook_accounts a  ON a.id  = pt.cashbook_account_id
  WHERE pp.tenant_id = p_tenant_id
    AND a.entity_type = p_entity_type
    AND (p_entity_ids IS NULL OR a.entity_id = ANY(p_entity_ids))
    AND (p_currencies IS NULL OR pp.currency_code = ANY(p_currencies));

  RETURN jsonb_build_object(
    'rows',           v_rows,
    'count',          jsonb_array_length(v_rows),
    'echoed_filters', jsonb_build_object(
      'tenant_id',   p_tenant_id,
      'entity_type', p_entity_type,
      'entity_ids',  p_entity_ids,
      'currencies',  p_currencies
    )
  );
END;
$$;
```

**Parameters**

| Param | Type | Default | Notes |
|---|---|---|---|
| `p_tenant_id` | bigint | — | Required |
| `p_entity_type` | text | `profile` | |
| `p_entity_ids` | bigint[] | NULL | NULL = all entities of type |
| `p_currencies` | text[] | NULL | NULL = all currencies |

**Return**

```json
{
  "rows": [
    { "pot_id": 55, "entity_type": "profile", "entity_id": 42,
      "currency_code": "BDT", "amount": 5500, "updated_at": "..." }
  ],
  "count": 1,
  "echoed_filters": { ... }
}
```

**Performance note:** When `p_entity_ids` is large (> 1000), consider a separate RPC that accepts a single currency + returns paginated. Otherwise this is fine up to ~10k rows for dashboards.

**Use cases**

| Consumer | Call |
|---|---|
| Cash position dashboard | `entity_type='profile', currencies=['BDT']` |
| Cash to pay bill check | `entity_type='profile', entity_ids=[42, 55, 88]` |
| Tenant cash overview | `entity_type='tenant'` |

---

## 6. R5 — `rpc_profile_transactions`

**Purpose:** Profile statement — every `pays` leg that touched one of the profile's pots, with running balance and resolved counterparty.

**Signature**

```sql
CREATE OR REPLACE FUNCTION public.rpc_profile_transactions(
  p_tenant_id        bigint,
  p_profile_id       bigint,
  p_from_date        date    DEFAULT NULL,
  p_to_date          date    DEFAULT NULL,
  p_kind             text    DEFAULT NULL,
  p_currency_code    text    DEFAULT NULL,
  p_pot_id           bigint  DEFAULT NULL,
  p_bill_id          bigint  DEFAULT NULL,
  p_include_voided   boolean DEFAULT false,
  p_limit            int     DEFAULT 20,
  p_cursor           jsonb   DEFAULT NULL
    -- {"created_at":"...","pays_id":N,"direction":"in"|"out"}
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_result jsonb;
  v_c_at   timestamptz;
  v_c_pays bigint;
  v_c_dir  text;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and profile_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
    RAISE EXCEPTION 'invalid_arguments: from_date must be <= to_date';
  END IF;
  IF p_cursor IS NOT NULL THEN
    v_c_at   := (p_cursor->>'created_at')::timestamptz;
    v_c_pays := (p_cursor->>'pays_id')::bigint;
    v_c_dir  := p_cursor->>'direction';
    IF v_c_at IS NULL OR v_c_pays IS NULL OR v_c_dir IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires created_at, pays_id, direction';
    END IF;
  END IF;

  PERFORM 1 FROM public.profiles
    WHERE id = p_profile_id AND tenant_id = p_tenant_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_tenant_id;
  END IF;

  WITH my_pots AS (
    SELECT pp.id AS pot_id, pp.currency_code, pp.amount AS current_balance
      FROM public.cashbook_point_pots pp
      JOIN public.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN public.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE a.tenant_id = p_tenant_id
       AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id
       AND (p_pot_id IS NULL OR pp.id = p_pot_id)
       AND (p_currency_code IS NULL OR pp.currency_code = p_currency_code)
  ),
  legs AS (
    SELECT p.id AS pays_id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code AS pot_currency, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'out'::text AS direction,
           p.amount           AS leg_amount,
           -p.amount          AS signed_amount,
           CASE WHEN p.status = 'posted' THEN -p.amount ELSE 0 END AS signed_for_balance,
           p.to_pot_id        AS other_pot_id
      FROM public.pays p
      JOIN my_pots mp ON mp.pot_id = p.from_pot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.from_pot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM public.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))

    UNION ALL

    SELECT p.id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'in'::text,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.status = 'posted'
                THEN (CASE WHEN p.kind = 'transfer'
                           THEN p.amount * p.exchange_rate ELSE p.amount END)
                ELSE 0 END,
           p.from_pot_id
      FROM public.pays p
      JOIN my_pots mp ON mp.pot_id = p.to_pot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.to_pot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM public.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))
  ),
  with_balance AS MATERIALIZED (
    SELECT l.*,
           l.current_balance - COALESCE(
             SUM(l.signed_for_balance) OVER (
               PARTITION BY l.pot_id
               ORDER BY l.created_at DESC, l.pays_id DESC, l.direction DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
             ), 0
           ) AS balance_after
      FROM legs l
  ),
  filtered AS (
    SELECT *
      FROM with_balance wb
     WHERE p_cursor IS NULL
        OR (wb.created_at, wb.pays_id, wb.direction)
             < (v_c_at, v_c_pays, v_c_dir)
     ORDER BY created_at DESC, pays_id DESC, direction DESC
     LIMIT p_limit + 1
  ),
  page_rows AS (
    SELECT f.*, row_number() OVER () AS _rn
      FROM filtered f
     LIMIT p_limit
  )
  SELECT jsonb_build_object(
    'profile_id',  p_profile_id,
    'limit',       p_limit,
    'has_more',    (SELECT count(*) > p_limit FROM filtered),
    'next_cursor', CASE
      WHEN (SELECT count(*) > p_limit FROM filtered) THEN (
        SELECT jsonb_build_object(
          'created_at', b.created_at,
          'pays_id',    b.pays_id,
          'direction',  b.direction
        )
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
      ELSE NULL
    END,
    'balances', jsonb_build_object(
      'by_pot', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'pot_id', pot_id, 'currency', currency_code, 'balance', current_balance
        ) ORDER BY pot_id)
        FROM my_pots
      ), '[]'::jsonb),
      'by_currency', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'currency', currency_code, 'balance', SUM(current_balance)
        ) ORDER BY currency_code)
        FROM my_pots GROUP BY currency_code
      ), '[]'::jsonb)
    ),
    'transactions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'pays_id',       pd.pays_id,
        'kind',          pd.kind,
        'payment_date',  pd.payment_date,
        'created_at',    pd.created_at,
        'status',        pd.status,
        'direction',     pd.direction,
        'signed_amount', pd.signed_amount,
        'leg_amount',    pd.leg_amount,
        'pot_id',        pd.pot_id,
        'pot_currency',  pd.pot_currency,
        'balance_after', pd.balance_after,
        'books_amount',  pd.books_amount,
        'exchange_rate', pd.exchange_rate,
        'other_side', CASE
          WHEN pd.other_pot_id IS NULL
            THEN jsonb_build_object('kind', 'external')
          ELSE (
            SELECT jsonb_build_object(
              'pot_id',   pp.id,
              'currency', pp.currency_code,
              'kind',     a.entity_type,
              'id',       a.entity_id,
              'name',     COALESCE(pr.name, t.name, a.entity_type)
            )
            FROM public.cashbook_point_pots pp
            JOIN public.cashbook_points    pt ON pt.id = pp.cashbook_point_id
            JOIN public.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
            LEFT JOIN public.profiles      pr ON pr.id = a.entity_id AND a.entity_type = 'profile'
            LEFT JOIN public.tenants       t  ON t.id  = a.entity_id AND a.entity_type = 'tenant'
            WHERE pp.id = pd.other_pot_id
          )
        END,
        'refs', pd.refs,
        'meta', pd.meta
      ) ORDER BY pd.created_at DESC, pd.pays_id DESC, pd.direction DESC)
      FROM page_rows pd
    ), '[]'::jsonb),
    'echoed_filters', jsonb_build_object(
      'tenant_id',      p_tenant_id,
      'profile_id',     p_profile_id,
      'from_date',      p_from_date,
      'to_date',        p_to_date,
      'kind',           p_kind,
      'currency_code',  p_currency_code,
      'pot_id',         p_pot_id,
      'bill_id',        p_bill_id,
      'include_voided', p_include_voided,
      'limit',          p_limit,
      'cursor',         p_cursor
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;
```

**Parameters**

| Param | Type | Notes |
|---|---|---|
| `p_tenant_id` | bigint | Required |
| `p_profile_id` | bigint | Required |
| `p_from_date` | date | Filter on `payment_date` |
| `p_to_date` | date | |
| `p_kind` | text | pays kind filter |
| `p_currency_code` | text | Currency filter |
| `p_pot_id` | bigint | Restrict to one pot |
| `p_bill_id` | bigint | Only rows settling this bill |
| `p_include_voided` | boolean | Include voided |
| `p_limit` | int | Max 500 (default 20) |
| `p_cursor` | jsonb | Prior `next_cursor` |

**Return**

```json
{
  "profile_id": 42,
  "limit": 20,
  "has_more": true,
  "next_cursor": { "created_at": "...", "pays_id": 1005, "direction": "out" },
  "balances": {
    "by_pot": [{ "pot_id": 55, "currency": "BDT", "balance": 5500 }],
    "by_currency": [{ "currency": "BDT", "balance": 5500 }]
  },
  "transactions": [
    {
      "pays_id": 1005, "kind": "withdrawal", "direction": "out",
      "signed_amount": -500, "balance_after": 5500, "status": "posted",
      "other_side": {"kind": "external"},
      "refs": {}, "meta": {"method": "bank"}
    }
  ],
  "echoed_filters": {...}
}
```

**Balance computation:** For each transaction, `balance_after = pot.current_balance - sum(signed_amount of all NEWER transactions for that pot)`. Computed by window function over the ordered-by-created_at-desc set, running a cumulative sum from the top. Voided rows have `signed_for_balance = 0` so they don't affect running totals but still appear in the list (if `p_include_voided=true`).

**Indexes used**

- `ix_pays_from` / `ix_pays_to` (both indexed on `tenant_id, pot_id, payment_date`)
- `ix_settle_pays` (via `bill_id` EXISTS subquery)

**Use cases**

| Scenario | Call |
|---|---|
| Customer statement | `profile_id=X, from_date, to_date` |
| Vendor statement | Same |
| Money history | `profile_id=X` |
| Cash flow per pot | `profile_id=X, pot_id=Y` |
| Bill settlement detail | `profile_id=X, bill_id=9001` |

**Performance note:** The CTE `with_balance` is `MATERIALIZED` — prevents re-evaluation between `counted` and `paged`. For a profile with 10k+ transactions, `balance_after` calculation is O(N) — acceptable. For 100k+ transactions in a single profile, add `p_from_date` always.

---

## 7. R6 — `rpc_list_bill_kinds`

**Purpose:** Return the registry. UI uses it for dropdowns; clients use it to validate payloads before `rpc_create_bill`.

```sql
CREATE OR REPLACE FUNCTION public.rpc_list_bill_kinds()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  RETURN jsonb_build_object(
    'kinds', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'kind',             r.kind,
        'numbering_prefix', r.numbering_prefix,
        'default_status',   r.default_status,
        'can_be_issued',    r.can_be_issued,
        'can_be_paid',      r.can_be_paid,
        'required_meta',    to_jsonb(r.required_meta),
        'description',      r.description,
        'is_active',        r.is_active
      ) ORDER BY r.kind)
      FROM public.bill_kind_registry r
      WHERE r.is_active = true
    ), '[]'::jsonb),
    'count', (SELECT COUNT(*) FROM public.bill_kind_registry WHERE is_active = true)
  );
END;
$$;
```

**Return**

```json
{
  "kinds": [
    { "kind": "sales_invoice_wholesale", "numbering_prefix": "INV-WS",
      "can_be_issued": true, "can_be_paid": true,
      "required_meta": [], "is_active": true },
    { "kind": "shipment_cost_ap", "numbering_prefix": "AP-SC",
      "required_meta": ["ap_kind","shipment_id"], ... }
  ],
  "count": 7
}
```

**Performance:** One `SELECT` on a table with ≤100 rows. Trivial.

---

---

## Views

**4 views.** These are the **stable data contract** for any consumer that prefers SQL to RPCs. A view is a published promise: column names, types, and semantics never break. Adding columns is allowed; renaming or removing is not.

Consumers who need **simple filtered reads** use these views. Consumers who need **complex, paginated, or aggregated** reads use the read RPCs (read RPCs above). Both paths read from the same underlying tables with the same RLS.

### Inventory

| # | View | Grain | Primary consumer |
|---|---|---|---|
| V1 | `v_bills_unified` | 1 row per bill | Any bill list/detail read |
| V2 | `v_bill_lines_unified` | 1 row per bill line | Report COGS / shipment-item attribution |
| V3 | `v_bill_events` | 1 row per event | Lifecycle stream, refresh workers, audit |
| V4 | `v_pot_balances` | 1 row per pot | Cash position dashboards, billing runs |

### Contract rules

| Rule | Why |
|---|---|
| **Column set is append-only** | Consumers depend on column names; renaming breaks them silently |
| **Views never write** | Read-only by definition; nothing else to enforce |
| **`security_invoker = true`** (PG15+) or `security definer` ownership trick | Underlying RLS applies to caller, not to view owner |
| **No business logic in views** | Any derivation (e.g. `days_overdue`) lives in the reporting layer, not here |
| **Voided bills appear in `v_bills_unified`** | Consumers filter `WHERE status <> 'voided'` explicitly. No hidden filtering — reports that need voided data (audit) can query it |
| **`meta` jsonb passed through raw** | Views don't attempt to flatten or validate kind-specific meta |

---

## 2. V1 — `v_bills_unified`

**Purpose:** The universal bill table. One row per bill, all kinds, all tenants (RLS-scoped). **Every consumer that reads bills reads this view or `rpc_query_bills` — never `bills` directly.**

### Definition

```sql
CREATE OR REPLACE VIEW public.v_bills_unified
  WITH (security_invoker = true)
AS
SELECT
  b.id                                       AS bill_id,
  b.tenant_id,
  b.issued_by_tenant_id,
  b.kind,
  b.status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code,
  b.total_amount,
  b.paid_amount,
  b.due_amount,
  b.written_off_amount,
  b.parent_bill_id,
  b.source_type,
  b.source_id,
  b.source_key,
  b.meta,
  b.note,
  b.created_by,
  b.created_at,
  b.updated_at,

  -- Derived helpers (stable semantics — additions allowed, changes not)
  CASE WHEN b.due_amount > 0 THEN true ELSE false END       AS has_due,
  CASE WHEN b.status = 'voided' THEN true ELSE false END    AS is_voided
FROM public.bills b;
```

### Column reference

| # | Column | Type | Null | Source | Notes |
|---|---|---|---|---|---|
| 1 | `bill_id` | bigint | no | `bills.id` | Renamed for consumer clarity |
| 2 | `tenant_id` | bigint | no | `bills.tenant_id` | |
| 3 | `issued_by_tenant_id` | bigint | no | `bills.issued_by_tenant_id` | May differ from `tenant_id` cross-tenant |
| 4 | `kind` | text | no | `bills.kind` | FK to `bill_kind_registry` |
| 5 | `status` | text | no | `bills.status` | `draft` / `issued` / `partial` / `paid` / `voided` / `written_off` |
| 6 | `invoice_no` | text | no | `bills.invoice_no` | |
| 7 | `invoice_date` | date | no | `bills.invoice_date` | |
| 8 | `due_date` | date | yes | `bills.due_date` | |
| 9 | `counterparty_profile_id` | bigint | yes | `bills.counterparty_profile_id` | |
| 10 | `counterparty_tenant_id` | bigint | yes | `bills.counterparty_tenant_id` | |
| 11 | `currency_code` | text | no | `bills.currency_code` | |
| 12 | `total_amount` | numeric(18,4) | no | `bills.total_amount` | |
| 13 | `paid_amount` | numeric(18,4) | no | `bills.paid_amount` | Trigger-maintained |
| 14 | `due_amount` | numeric(18,4) | no | `bills.due_amount` | Trigger-maintained |
| 15 | `written_off_amount` | numeric(18,4) | no | `bills.written_off_amount` | |
| 16 | `parent_bill_id` | bigint | yes | `bills.parent_bill_id` | For credit/debit notes |
| 17 | `source_type` | text | yes | `bills.source_type` | |
| 18 | `source_id` | text | yes | `bills.source_id` | |
| 19 | `source_key` | text | yes | `bills.source_key` | |
| 20 | `meta` | jsonb | no | `bills.meta` | Raw — kind-specific fields |
| 21 | `note` | text | yes | `bills.note` | |
| 22 | `created_by` | uuid | yes | `bills.created_by` | |
| 23 | `created_at` | timestamptz | no | `bills.created_at` | |
| 24 | `updated_at` | timestamptz | no | `bills.updated_at` | |
| 25 | `has_due` | boolean | no | derived | `due_amount > 0` |
| 26 | `is_voided` | boolean | no | derived | `status = 'voided'` |

**Deliberately excluded from the view:**
- `idempotency_key` — internal, not for consumers
- Any `meta` sub-key flattened — consumer accesses `meta->>'shipment_id'` directly

### Indexes on the underlying table (needed for view query performance)

The view is a plain `SELECT`, so Postgres uses the indexes on `bills`:

| Query pattern | Index used |
|---|---|
| `WHERE tenant_id = X` | `ix_bills_tenant_status_kind` (leading `tenant_id`) |
| `WHERE tenant_id = X AND status = 'issued'` | `ix_bills_tenant_status_kind` |
| `WHERE tenant_id = X AND kind = 'sales_invoice_wholesale'` | `ix_bills_tenant_status_kind` |
| `WHERE source_type = 'shipment' AND source_id = '123'` | `ix_bills_source` |
| `WHERE counterparty_profile_id = 42` | `ix_bills_counterparty` |
| `WHERE parent_bill_id = 9001` | `ix_bills_parent` |
| `WHERE meta @> '{"shipment_id":123}'` | `ix_bills_meta_gin` |

### Usage examples

**All open bills for a tenant:**

```sql
SELECT bill_id, kind, invoice_no, total_amount, due_amount, due_date
FROM public.v_bills_unified
WHERE tenant_id = 1
  AND status <> 'voided'
  AND has_due = true
ORDER BY due_date ASC;
```

**All AP bills for a shipment:**

```sql
SELECT bill_id, kind, invoice_no, status, total_amount, paid_amount, due_amount
FROM public.v_bills_unified
WHERE tenant_id = 1
  AND source_type = 'shipment'
  AND source_id = '1234'
  AND status <> 'voided';
```

**All AR bills for a customer:**

```sql
SELECT bill_id, kind, invoice_no, invoice_date, total_amount, due_amount
FROM public.v_bills_unified
WHERE tenant_id = 1
  AND counterparty_profile_id = 42
  AND status <> 'voided'
ORDER BY invoice_date DESC;
```

### What the view does NOT do

- **Does not filter voided bills** — consumer must add `WHERE status <> 'voided'` if they want to exclude
- **Does not join lines, settlements, or events** — use `v_bill_lines_unified` for lines, `rpc_get_bill` for the full aggregate
- **Does not aggregate** — use `rpc_query_bills` with `group_by` for sums

### Stability promise

The 26 columns above are permanent. Future additions must be appended at the end (or anywhere — Postgres allows reorder, but consumers using `SELECT *` might break; convention is append). No existing column is ever renamed or removed.

---

## 3. V2 — `v_bill_lines_unified`

**Purpose:** Every bill line, joined to its bill's context. This is the view the shipment profit report uses to attribute revenue and COGS by `shipment_item_id`.

### Definition

```sql
CREATE OR REPLACE VIEW public.v_bill_lines_unified
  WITH (security_invoker = true)
AS
SELECT
  bl.id                         AS line_id,
  bl.bill_id,
  b.tenant_id,
  b.issued_by_tenant_id,
  b.kind                        AS bill_kind,
  b.status                      AS bill_status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code               AS bill_currency_code,
  b.source_type,
  b.source_id,
  b.source_key,

  bl.line_no,
  bl.item_kind,
  bl.product_id,
  bl.description,
  bl.quantity,
  bl.unit_price,
  bl.line_total,
  bl.meta                       AS line_meta,
  bl.created_at                 AS line_created_at,

  -- Convenience extraction of well-known meta keys (kind-specific, nullable)
  CASE WHEN (bl.meta ? 'shipment_item_id')
       THEN (bl.meta->>'shipment_item_id')::bigint
       ELSE NULL END            AS shipment_item_id,
  CASE WHEN (bl.meta ? 'assigned_child_tenant_id')
       THEN (bl.meta->>'assigned_child_tenant_id')::bigint
       ELSE NULL END            AS assigned_child_tenant_id,
  CASE WHEN (bl.meta ? 'barcode')
       THEN bl.meta->>'barcode'
       ELSE NULL END            AS barcode,

  b.meta                        AS bill_meta
FROM public.bill_lines bl
JOIN public.bills b ON b.id = bl.bill_id;
```

### Column reference

| # | Column | Type | Null | Source | Notes |
|---|---|---|---|---|---|
| 1 | `line_id` | bigint | no | `bill_lines.id` | |
| 2 | `bill_id` | bigint | no | `bill_lines.bill_id` | |
| 3 | `tenant_id` | bigint | no | `bills.tenant_id` | |
| 4 | `issued_by_tenant_id` | bigint | no | `bills.issued_by_tenant_id` | |
| 5 | `bill_kind` | text | no | `bills.kind` | |
| 6 | `bill_status` | text | no | `bills.status` | |
| 7 | `invoice_no` | text | no | `bills.invoice_no` | |
| 8 | `invoice_date` | date | no | `bills.invoice_date` | |
| 9 | `due_date` | date | yes | `bills.due_date` | |
| 10 | `counterparty_profile_id` | bigint | yes | `bills.counterparty_profile_id` | |
| 11 | `counterparty_tenant_id` | bigint | yes | `bills.counterparty_tenant_id` | |
| 12 | `bill_currency_code` | text | no | `bills.currency_code` | Line currency = bill currency |
| 13 | `source_type` | text | yes | `bills.source_type` | |
| 14 | `source_id` | text | yes | `bills.source_id` | |
| 15 | `source_key` | text | yes | `bills.source_key` | |
| 16 | `line_no` | int | no | `bill_lines.line_no` | |
| 17 | `item_kind` | text | no | `bill_lines.item_kind` | |
| 18 | `product_id` | bigint | yes | `bill_lines.product_id` | |
| 19 | `description` | text | no | `bill_lines.description` | |
| 20 | `quantity` | numeric(18,4) | no | `bill_lines.quantity` | |
| 21 | `unit_price` | numeric(18,4) | no | `bill_lines.unit_price` | |
| 22 | `line_total` | numeric(18,4) | no | `bill_lines.line_total` | |
| 23 | `line_meta` | jsonb | no | `bill_lines.meta` | |
| 24 | `line_created_at` | timestamptz | no | `bill_lines.created_at` | |
| 25 | `shipment_item_id` | bigint | yes | `line_meta->>'shipment_item_id'` | Extracted for join convenience |
| 26 | `assigned_child_tenant_id` | bigint | yes | `line_meta->>'assigned_child_tenant_id'` | Extracted |
| 27 | `barcode` | text | yes | `line_meta->>'barcode'` | Extracted |
| 28 | `bill_meta` | jsonb | no | `bills.meta` | Raw bill meta |

### Indexes

The view is a join. Postgres pushes filters down. Effective indexes:

| Query pattern | Index used |
|---|---|
| `WHERE bill_id = X` | `ix_bill_lines_bill` (on `bill_lines.bill_id`) |
| `WHERE tenant_id = X AND bill_kind = 'sales_invoice_wholesale'` | `ix_bills_tenant_status_kind` (join side) |
| `WHERE shipment_item_id = 555` | **None** — jsonb extraction. See "Performance" below |
| `WHERE product_id = Y` | `ix_bill_lines_product` |

### Performance — the `shipment_item_id` problem

Filters on `shipment_item_id` are the hot path for the shipment report. Without an index, every filter scans all `bill_lines` for the tenant. Two options:

**Option A (recommended): expression index on the underlying table**

```sql
CREATE INDEX ix_bill_lines_shipment_item
  ON public.bill_lines ((meta->>'shipment_item_id'))
  WHERE meta ? 'shipment_item_id';
```

Now `WHERE shipment_item_id = 555` in the view is index-served.

**Option B: stored generated column** — requires changing the underlying table. Rejected for v1 (scope creep).

### Usage examples

**Revenue lines tied to a shipment:**

```sql
SELECT line_id, bill_id, invoice_no, product_id, quantity, line_total
FROM public.v_bill_lines_unified
WHERE tenant_id = 1
  AND shipment_item_id IN (SELECT id FROM global_shipment_items WHERE shipment_id = 1234)
  AND bill_kind LIKE 'sales_invoice_%'
  AND bill_status IN ('issued','partial','paid');
```

**COGS join for shipment profit:**

```sql
SELECT
  vbl.shipment_item_id,
  SUM(vbl.line_total)                                       AS revenue_bdt,
  SUM(vbl.quantity * gsi.landed_cost_bdt)                   AS cogs_bdt,
  SUM(vbl.line_total) - SUM(vbl.quantity * gsi.landed_cost_bdt) AS profit_bdt
FROM public.v_bill_lines_unified vbl
JOIN public.global_shipment_items gsi ON gsi.id = vbl.shipment_item_id
WHERE vbl.tenant_id = 1
  AND vbl.bill_kind LIKE 'sales_invoice_%'
  AND vbl.bill_status IN ('issued','partial','paid')
  AND gsi.shipment_id = 1234
GROUP BY vbl.shipment_item_id;
```

**Product sales history:**

```sql
SELECT product_id, COUNT(*) AS line_count, SUM(quantity) AS units_sold, SUM(line_total) AS revenue
FROM public.v_bill_lines_unified
WHERE tenant_id = 1
  AND product_id = 101
  AND bill_kind = 'sales_invoice_wholesale'
  AND bill_status IN ('issued','partial','paid')
  AND invoice_date >= '2026-01-01'
GROUP BY product_id;
```

### Stability promise

The 28 columns above are permanent. Adding new `line_meta` extractions (e.g. `batch_no`, `expiry_date`) is allowed — append only. Removing or renaming an extraction is not.

---

## 4. V3 — `v_bill_events`

**Purpose:** The complete lifecycle stream, joined to bill context. Single source for refresh workers, audit UIs, and any event-driven report.

### Definition

```sql
CREATE OR REPLACE VIEW public.v_bill_events
  WITH (security_invoker = true)
AS
SELECT
  e.id           AS event_id,
  e.tenant_id,
  e.bill_id,
  b.kind         AS bill_kind,
  b.invoice_no,
  b.status       AS bill_status_current,
  e.event_type,
  e.payload,
  e.actor_id,
  e.created_at
FROM public.bill_events e
JOIN public.bills b ON b.id = e.bill_id;
```

### Column reference

| # | Column | Type | Null | Source | Notes |
|---|---|---|---|---|---|
| 1 | `event_id` | bigint | no | `bill_events.id` | Monotonic — safe for polling |
| 2 | `tenant_id` | bigint | no | `bill_events.tenant_id` | |
| 3 | `bill_id` | bigint | no | `bill_events.bill_id` | |
| 4 | `bill_kind` | text | no | `bills.kind` | Current bill kind (immutable) |
| 5 | `invoice_no` | text | no | `bills.invoice_no` | Current invoice number (immutable) |
| 6 | `bill_status_current` | text | no | `bills.status` | **Current** status of bill, not the status at event time |
| 7 | `event_type` | text | no | `bill_events.event_type` | See enum below |
| 8 | `payload` | jsonb | no | `bill_events.payload` | Event-specific data |
| 9 | `actor_id` | uuid | yes | `bill_events.actor_id` | |
| 10 | `created_at` | timestamptz | no | `bill_events.created_at` | |

**Note on `bill_status_current`:** This is the bill's **current** status, not the status at the moment the event fired. For historical status at event time, parse the `payload`:

- For `created` events: `payload->>'status'`
- For `issued`: `payload->>'to_status'`
- For `payment_applied`: `payload->>'status_after'`
- For `voided`: `payload->>'to_status'`

This is intentional — the current status column is for **filtering** ("show me events for currently-paid bills"), not for reconstructing history. History is in `payload`.

### Event types

| `event_type` | Fired when | Payload keys |
|---|---|---|
| `created` | Bill INSERT | `kind`, `invoice_no`, `status`, `total_amount`, `currency_code`, `source_type`, `source_id`, `source_key`, `parent_bill_id`, `counterparty_profile_id` |
| `issued` | Status → issued | `from_status`, `to_status` |
| `voided` | Status → voided | `from_status`, `to_status` |
| `payment_applied` | `paid_amount` increased | `delta`, `paid_before`, `paid_after`, `due_after`, `status_after` |
| `payment_reversed` | `paid_amount` decreased (via void) | Same |
| `written_off` | `written_off_amount` changed | `delta`, `written_off_total`, `due_after`, `status_after` |
| `updated` | Any other status change | `from_status`, `to_status` |

Priority rule: when multiple deltas happen in one `bills` UPDATE, **only the highest-priority event is emitted** (money delta > write-off > status). See 01-schema T6 for the exact rule.

### Indexes

| Query pattern | Index used |
|---|---|
| `WHERE bill_id = X` | `ix_bill_events_bill` |
| `WHERE tenant_id = X AND event_type = 'issued'` | `ix_bill_events_tenant` |
| `WHERE event_id > last_seen` (polling) | Primary key (monotonic) |
| `WHERE created_at > now() - interval '1 hour'` | `ix_bill_events_tenant` (if tenant filter present) |

### Usage examples

**Refresh worker — get changed bills since last poll:**

```sql
-- Get max event id we've already processed
SELECT last_seen_id FROM refresh_worker_state WHERE tenant_id = 1;

-- Get all new events since then
SELECT DISTINCT bill_id
FROM public.v_bill_events
WHERE tenant_id = 1
  AND event_id > 12456
ORDER BY bill_id;

-- Update watermark
UPDATE refresh_worker_state SET last_seen_id = (SELECT MAX(event_id) FROM public.v_bill_events WHERE tenant_id = 1) WHERE tenant_id = 1;
```

**Audit trail for one bill:**

```sql
SELECT event_id, event_type, payload, actor_id, created_at
FROM public.v_bill_events
WHERE bill_id = 9001
ORDER BY created_at DESC, event_id DESC;
```

**All payment events for the last day:**

```sql
SELECT bill_id, invoice_no, event_type, (payload->>'delta')::numeric AS delta, created_at
FROM public.v_bill_events
WHERE tenant_id = 1
  AND event_type IN ('payment_applied','payment_reversed')
  AND created_at >= now() - interval '1 day'
ORDER BY created_at DESC;
```

**Lifecycle timeline with running paid total** (see also `rpc_profile_transactions` for the money side):

```sql
SELECT
  event_id, event_type, payload, created_at,
  SUM(CASE
    WHEN event_type = 'payment_applied'  THEN (payload->>'delta')::numeric
    WHEN event_type = 'payment_reversed' THEN (payload->>'delta')::numeric
    ELSE 0
  END) OVER (PARTITION BY bill_id ORDER BY event_id) AS running_paid
FROM public.v_bill_events
WHERE bill_id = 9001
ORDER BY event_id;
```

### Change feed semantics

The view serves two roles:

1. **Event stream** for audit and reporting
2. **Change feed** for downstream consumers (shipment report, dashboards)

**Change feed:** poll `money_kernel.money_outbox` by `(tenant_id, xid)` — see [00-overview.md](00-overview.md). `event_id > last_seen` on `bill_events` is **not** gapless (ids assign at insert, visible at commit). Use this view for audit/display only, not consumer watermarks.

### Stability promise

The 10 columns above are permanent. New `event_type` values may appear (each will be documented); consumers should treat unknown types as pass-through. New `payload` keys may be added; consumers should not assume any key is absent.

---

## 5. V4 — `v_pot_balances`

**Purpose:** Every pot with entity details resolved. For dashboards, cash-position overviews, and bulk lookups where joining `cashbook_accounts` + `cashbook_points` + `cashbook_point_pots` would be repetitive.

### Definition

```sql
CREATE OR REPLACE VIEW public.v_pot_balances
  WITH (security_invoker = true)
AS
SELECT
  pp.id                AS pot_id,
  pp.tenant_id,
  a.id                 AS cashbook_account_id,
  a.entity_type,
  a.entity_id,
  pt.id                AS cashbook_point_id,
  pt.code              AS point_code,
  pt.name              AS point_name,
  pp.currency_code,
  pp.amount,
  pp.created_at,
  pp.updated_at,
  (a.default_cashbook_point_pot_id = pp.id) AS is_default_pot,

  -- Entity display resolution
  COALESCE(pr.name, t.name, a.entity_type) AS entity_name,
  pr.profile_type,
  pr.phone,
  pr.email,

  -- Container totals
  (
    SELECT COUNT(*)
    FROM public.cashbook_point_pots pp2
    JOIN public.cashbook_points    pt2 ON pt2.id = pp2.cashbook_point_id
    WHERE pt2.cashbook_account_id = a.id
  )                    AS pots_in_account
FROM public.cashbook_point_pots pp
JOIN public.cashbook_points pt    ON pt.id = pp.cashbook_point_id
JOIN public.cashbook_accounts a   ON a.id  = pt.cashbook_account_id
LEFT JOIN public.profiles pr      ON pr.id = a.entity_id AND a.entity_type = 'profile'
LEFT JOIN public.tenants  t       ON t.id  = a.entity_id AND a.entity_type = 'tenant';
```

### Column reference

| # | Column | Type | Null | Source | Notes |
|---|---|---|---|---|---|
| 1 | `pot_id` | bigint | no | `cashbook_point_pots.id` | |
| 2 | `tenant_id` | bigint | no | `cashbook_point_pots.tenant_id` | |
| 3 | `cashbook_account_id` | bigint | no | `cashbook_accounts.id` | |
| 4 | `entity_type` | text | no | `cashbook_accounts.entity_type` | |
| 5 | `entity_id` | bigint | no | `cashbook_accounts.entity_id` | |
| 6 | `cashbook_point_id` | bigint | no | `cashbook_points.id` | |
| 7 | `point_code` | text | no | `cashbook_points.code` | |
| 8 | `point_name` | text | no | `cashbook_points.name` | |
| 9 | `currency_code` | text | no | `cashbook_point_pots.currency_code` | |
| 10 | `amount` | numeric(18,4) | no | `cashbook_point_pots.amount` | Live balance |
| 11 | `created_at` | timestamptz | no | `cashbook_point_pots.created_at` | |
| 12 | `updated_at` | timestamptz | no | `cashbook_point_pots.updated_at` | |
| 13 | `is_default_pot` | boolean | no | derived | `default_cashbook_point_pot_id = pot_id` |
| 14 | `entity_name` | text | no | resolved | Profile name, tenant name, or entity_type fallback |
| 15 | `profile_type` | text | yes | `profiles.profile_type` | Only for entity_type='profile' |
| 16 | `phone` | text | yes | `profiles.phone` | |
| 17 | `email` | text | yes | `profiles.email` | |
| 18 | `pots_in_account` | bigint | no | derived | Count of pots in the same account |

### Indexes

| Query pattern | Index used |
|---|---|
| `WHERE tenant_id = X` | `cashbook_point_pots` — needs an index. See "Performance" below |
| `WHERE entity_type = 'profile' AND entity_id = Y` | `cashbook_accounts` UQ |
| `WHERE pot_id = Z` | `cashbook_point_pots` PK |
| `WHERE is_default_pot = true` | None — derived column |
| `WHERE currency_code = 'USD'` | `cashbook_point_pots` UQ `(cashbook_point_id, currency_code)` — leading col mismatch |

### Performance

Two concerns:

**1. `tenant_id` filter on `cashbook_point_pots`**

There is no direct index on `cashbook_point_pots.tenant_id`. Either:

**Option A (recommended): add the index**

```sql
CREATE INDEX ix_pots_tenant
  ON public.cashbook_point_pots (tenant_id);
```

**Option B: the view joins to `cashbook_accounts` first** — Postgres can plan this as `accounts → points → pots`, using `cashbook_accounts` UQ. But cross-tenant scans of `cashbook_accounts` are only feasible if that table also has a `tenant_id` index.

**2. `pots_in_account` correlated subquery**

The subquery runs per row. For a tenant with 10k pots, this is 10k correlated subqueries. Better: pre-aggregate.

**Fix:** rewrite as a join to a derived table:

```sql
-- Replace the correlated subquery with a pre-aggregation
LEFT JOIN (
  SELECT pt2.cashbook_account_id, COUNT(*) AS pots_in_account
  FROM public.cashbook_points pt2
  JOIN public.cashbook_point_pots pp2 ON pp2.cashbook_point_id = pt2.id
  GROUP BY pt2.cashbook_account_id
) cnt ON cnt.cashbook_account_id = a.id
```

Then use `COALESCE(cnt.pots_in_account, 0)`. This computes the count once per account, not once per pot.

**Updated definition:**

```sql
CREATE OR REPLACE VIEW public.v_pot_balances
  WITH (security_invoker = true)
AS
SELECT
  pp.id                AS pot_id,
  pp.tenant_id,
  a.id                 AS cashbook_account_id,
  a.entity_type,
  a.entity_id,
  pt.id                AS cashbook_point_id,
  pt.code              AS point_code,
  pt.name              AS point_name,
  pp.currency_code,
  pp.amount,
  pp.created_at,
  pp.updated_at,
  (a.default_cashbook_point_pot_id = pp.id) AS is_default_pot,
  COALESCE(pr.name, t.name, a.entity_type) AS entity_name,
  pr.profile_type,
  pr.phone,
  pr.email,
  COALESCE(cnt.pots_in_account, 0) AS pots_in_account
FROM public.cashbook_point_pots pp
JOIN public.cashbook_points pt    ON pt.id = pp.cashbook_point_id
JOIN public.cashbook_accounts a   ON a.id  = pt.cashbook_account_id
LEFT JOIN public.profiles pr      ON pr.id = a.entity_id AND a.entity_type = 'profile'
LEFT JOIN public.tenants  t       ON t.id  = a.entity_id AND a.entity_type = 'tenant'
LEFT JOIN (
  SELECT pt2.cashbook_account_id, COUNT(*) AS pots_in_account
  FROM public.cashbook_points pt2
  JOIN public.cashbook_point_pots pp2 ON pp2.cashbook_point_id = pt2.id
  GROUP BY pt2.cashbook_account_id
) cnt ON cnt.cashbook_account_id = a.id;
```

### Usage examples

**All profile pots in a tenant, BDT only:**

```sql
SELECT entity_id AS profile_id, entity_name, amount AS bdt_balance
FROM public.v_pot_balances
WHERE tenant_id = 1
  AND entity_type = 'profile'
  AND currency_code = 'BDT'
ORDER BY amount DESC;
```

**Tenant's own collection pots:**

```sql
SELECT point_code, point_name, currency_code, amount
FROM public.v_pot_balances
WHERE tenant_id = 1
  AND entity_type = 'tenant'
ORDER BY currency_code;
```

**Cash-on-hand dashboard by currency:**

```sql
SELECT currency_code, SUM(amount) AS total_balance, COUNT(*) AS pot_count
FROM public.v_pot_balances
WHERE tenant_id = 1
GROUP BY currency_code
ORDER BY currency_code;
```

**Find a profile's default BDT pot:**

```sql
SELECT pot_id, amount
FROM public.v_pot_balances
WHERE tenant_id = 1
  AND entity_type = 'profile'
  AND entity_id = 42
  AND currency_code = 'BDT'
  AND is_default_pot = true;
```

### Stability promise

The 18 columns above are permanent. Additions (e.g. `customer_group`, `branch_code`) can be appended.

---

## 6. RLS and Security

**Ship-complete SQL:** [05-security.md](05-security.md) — assert, privilege matrix, full `CREATE POLICY`, `auth_tenant_id()`, multi-tenant membership, issuer-tenant read path for `bill_lines` / `bill_events`.

### Postgres 15+ — `security_invoker = true`

All 4 views: `WITH (security_invoker = true)`. Require PG15+.

**Change feed:** consumers poll `money_kernel.money_outbox` by `xid` — not gapless `bill_events.id` through `v_bill_events`.

### Grants

```sql
GRANT SELECT ON public.v_bills_unified         TO authenticated;
GRANT SELECT ON public.v_bill_lines_unified    TO authenticated;
GRANT SELECT ON public.v_bill_events           TO authenticated;
GRANT SELECT ON public.v_pot_balances          TO authenticated;

-- Underlying tables: SELECT only (no INSERT/UPDATE/DELETE for authenticated)
GRANT SELECT ON public.bills            TO authenticated;
GRANT SELECT ON public.bill_lines       TO authenticated;
GRANT SELECT ON public.bill_events      TO authenticated;
GRANT SELECT ON public.cashbook_point_pots TO authenticated;
GRANT SELECT ON public.cashbook_accounts   TO authenticated;
GRANT SELECT ON public.cashbook_points     TO authenticated;

-- Explicitly revoke writes (in case any wildcard grant exists)
REVOKE INSERT, UPDATE, DELETE ON public.bills              FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.bill_lines         FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.bill_events        FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.cashbook_point_pots FROM authenticated;
```

---

