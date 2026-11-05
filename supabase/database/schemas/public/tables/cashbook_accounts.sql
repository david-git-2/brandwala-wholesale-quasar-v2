CREATE TABLE public.cashbook_accounts (
  id                bigint                        GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id         bigint                        NOT NULL,
  entity_type       text                          NOT NULL,
  entity_id         bigint                        NOT NULL,
  currency_code     text                          DEFAULT 'BDT'::text NOT NULL,
  available_balance numeric(18,4)                 DEFAULT 0.0000 NOT NULL,
  pending_balance   numeric(18,4)                 DEFAULT 0.0000 NOT NULL,
  locked_balance    numeric(18,4)                 DEFAULT 0.0000 NOT NULL,
  created_at        timestamp with time zone      DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone      DEFAULT now() NOT NULL,
  parent_tenant_id  bigint                        NOT NULL,
  account_class     public.cashbook_account_class DEFAULT 'profile_custody'::public.cashbook_account_class NOT NULL
);

CREATE INDEX idx_wallet_accounts_tenant_entity ON public.cashbook_accounts (tenant_id, entity_type, entity_id);

CREATE UNIQUE INDEX uq_wallet_accounts_parent_book ON public.cashbook_accounts (parent_tenant_id, entity_type, entity_id, currency_code);

CREATE POLICY wallet_accounts_authenticated_policy ON public.cashbook_accounts
  TO authenticated
  USING (true)
  WITH CHECK (true);

ALTER TABLE public.cashbook_accounts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT cashbook_accounts_class_entity_check
    CHECK
    (account_class = 'tenant_asset'::public.cashbook_account_class AND entity_type = 'tenant'::text OR account_class = 'profile_custody'::public.cashbook_account_class AND
    entity_type <> 'tenant'::text);

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT wallet_accounts_available_non_negative CHECK (available_balance >= 0::numeric OR entity_type = 'tenant'::text);

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT wallet_accounts_entity_currency_key UNIQUE (tenant_id, entity_type, entity_id, currency_code);

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT wallet_accounts_pkey PRIMARY KEY (id);

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT wallet_accounts_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT wallet_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);

GRANT ALL ON public.cashbook_accounts TO anon;

GRANT ALL ON public.cashbook_accounts TO authenticated;

GRANT ALL ON public.cashbook_accounts TO service_role;