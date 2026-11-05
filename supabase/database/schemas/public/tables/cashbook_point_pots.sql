CREATE TABLE public.cashbook_point_pots (
  id                bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  parent_tenant_id  bigint                   NOT NULL,
  cashbook_point_id bigint                   NOT NULL,
  currency_code     text                     DEFAULT 'BDT'::text NOT NULL,
  amount            numeric(18,4)            DEFAULT 0.0000 NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX cashbook_point_pots_parent_tenant_id_idx ON public.cashbook_point_pots (parent_tenant_id);

CREATE POLICY cashbook_point_pots_authenticated_policy ON public.cashbook_point_pots
  TO authenticated
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.cashbook_point_pots IS 'On-hand cash at a point in one currency. FX rate is frozen on cashbook_entries, not on this row.';

ALTER TABLE public.cashbook_point_pots
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_amount_non_negative CHECK (amount >= 0::numeric);

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_currency_code_trimmed CHECK (btrim(currency_code) <> ''::text);

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_pkey PRIMARY KEY (id);

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_point_currency_key UNIQUE (cashbook_point_id, currency_code);

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_cashbook_point_id_fkey FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE CASCADE;

ALTER TABLE public.cashbook_point_pots
  ADD CONSTRAINT cashbook_point_pots_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.cashbook_point_pots TO anon;

GRANT ALL ON public.cashbook_point_pots TO authenticated;

GRANT ALL ON public.cashbook_point_pots TO service_role;