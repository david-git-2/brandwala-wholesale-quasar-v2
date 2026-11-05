CREATE TABLE public.cashbook_entries (
  id                    uuid                     DEFAULT gen_random_uuid() NOT NULL,
  tenant_id             bigint                   NOT NULL,
  entity_type           text                     NOT NULL,
  entity_id             bigint                   NOT NULL,
  type                  text                     NOT NULL,
  amount                numeric(15,4)            NOT NULL,
  currency_code         text                     DEFAULT 'BDT'::text NOT NULL,
  exchange_rate         numeric(15,6)            DEFAULT 1.000000 NOT NULL,
  base_amount           numeric(15,4)            NOT NULL,
  balance_after         numeric(15,4)            NOT NULL,
  source_type           text                     NOT NULL,
  source_id             text,
  metadata              jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  parent_tenant_id      bigint                   NOT NULL,
  operating_tenant_id   bigint                   NOT NULL,
  cashbook_point_id     bigint,
  cashbook_point_pot_id bigint,
  quote_currency_code   text                     DEFAULT 'BDT'::text NOT NULL,
  rate_date             date
);

CREATE INDEX idx_uwl_parent_operating_created ON public.cashbook_entries (parent_tenant_id, operating_tenant_id, created_at DESC);

CREATE INDEX idx_uwl_parent_book_lookup ON public.cashbook_entries (parent_tenant_id, entity_type, entity_id, created_at DESC, id DESC);

CREATE INDEX idx_uwl_operating_source ON public.cashbook_entries (operating_tenant_id, source_type, source_id);

CREATE INDEX idx_universal_wallet_ledger_source ON public.cashbook_entries (source_type, source_id);

CREATE INDEX idx_universal_wallet_ledger_lookup ON public.cashbook_entries (tenant_id, entity_type, entity_id, created_at DESC, id DESC);

CREATE INDEX cashbook_entries_pot_lookup_idx ON public.cashbook_entries (cashbook_point_pot_id, created_at DESC)
  WHERE cashbook_point_pot_id IS NOT NULL;

CREATE INDEX cashbook_entries_point_lookup_idx ON public.cashbook_entries (cashbook_point_id, created_at DESC)
  WHERE cashbook_point_id IS NOT NULL;

CREATE TRIGGER trg_cashbook_entries_immutable
  BEFORE DELETE OR UPDATE ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_deny_cashbook_entry_mutation();

CREATE TRIGGER trg_cashbook_entry_sync_pot
  AFTER INSERT ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_sync_pot_on_cashbook_entry();

CREATE POLICY universal_wallet_ledger_select ON public.cashbook_entries
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = cashbook_entries.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER TABLE public.cashbook_entries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_amount_check CHECK (amount >= 0::numeric);

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_base_amount_check CHECK (base_amount >= 0::numeric);

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_exchange_rate_check CHECK (exchange_rate > 0::numeric);

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_pkey PRIMARY KEY (id);

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_type_check CHECK (type = ANY (ARRAY['credit'::text, 'debit'::text]));

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT cashbook_entries_cashbook_point_pot_id_fkey FOREIGN KEY (cashbook_point_pot_id) REFERENCES public.cashbook_point_pots(id) ON DELETE SET NULL;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT cashbook_entries_cashbook_point_id_fkey FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE SET NULL;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_operating_tenant_id_fkey FOREIGN KEY (operating_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT universal_wallet_ledger_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.cashbook_entries TO anon;

GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.cashbook_entries TO authenticated;

GRANT ALL ON public.cashbook_entries TO service_role;