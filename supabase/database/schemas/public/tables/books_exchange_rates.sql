CREATE TABLE public.books_exchange_rates (
  id                  bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  parent_tenant_id    bigint                   NOT NULL,
  base_currency_code  text                     DEFAULT 'BDT'::text NOT NULL,
  quote_currency_code text                     NOT NULL,
  rate                numeric(18,6)            NOT NULL,
  rate_date           timestamp with time zone DEFAULT now() NOT NULL,
  source              text                     DEFAULT 'manual'::text NOT NULL,
  created_at          timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX books_exchange_rates_lookup_idx ON public.books_exchange_rates (parent_tenant_id, quote_currency_code, rate_date DESC);

CREATE POLICY books_exchange_rates_authenticated_policy ON public.books_exchange_rates
  TO authenticated
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.books_exchange_rates IS 'Default FX pick: rate = base (BDT) per 1 quote (e.g. GBP). Posted pays copy the pair onto the ledger line.';

ALTER TABLE public.books_exchange_rates
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.books_exchange_rates
  ADD CONSTRAINT books_exchange_rates_codes_trimmed CHECK (btrim(base_currency_code) <> ''::text AND btrim(quote_currency_code) <> ''::text);

ALTER TABLE public.books_exchange_rates
  ADD CONSTRAINT books_exchange_rates_pair_distinct CHECK (upper(base_currency_code) <> upper(quote_currency_code));

ALTER TABLE public.books_exchange_rates
  ADD CONSTRAINT books_exchange_rates_pkey PRIMARY KEY (id);

ALTER TABLE public.books_exchange_rates
  ADD CONSTRAINT books_exchange_rates_rate_positive CHECK (rate > 0::numeric);

ALTER TABLE public.books_exchange_rates
  ADD CONSTRAINT books_exchange_rates_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.books_exchange_rates TO anon;

GRANT ALL ON public.books_exchange_rates TO authenticated;

GRANT ALL ON public.books_exchange_rates TO service_role;