CREATE TABLE public.global_shipment_cost_entries (
  id               bigint                                GENERATED ALWAYS AS IDENTITY NOT NULL,
  parent_tenant_id bigint                                NOT NULL,
  shipment_id      bigint                                NOT NULL,
  amount           numeric                               NOT NULL,
  currency_id      bigint,
  metadata         jsonb                                 DEFAULT '{}'::jsonb NOT NULL,
  created_at       timestamp with time zone              DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone              DEFAULT now() NOT NULL,
  section_id       bigint,
  cost_bucket      public.global_shipment_cost_bucket    NOT NULL,
  cost_component   public.global_shipment_cost_component NOT NULL,
  is_capitalizable boolean                               DEFAULT true NOT NULL,
  description      text
);

CREATE INDEX global_shipment_cost_entries_shipment_idx ON public.global_shipment_cost_entries (shipment_id);

CREATE INDEX global_shipment_cost_entries_bucket_idx ON public.global_shipment_cost_entries (shipment_id, cost_bucket);

CREATE INDEX global_shipment_cost_entries_parent_tenant_idx ON public.global_shipment_cost_entries (parent_tenant_id);

CREATE INDEX global_shipment_cost_entries_section_idx ON public.global_shipment_cost_entries (section_id);

CREATE TRIGGER trg_global_shipment_cost_entries_updated_at
  BEFORE UPDATE ON public.global_shipment_cost_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_global_shipment_cost_entry_axes
  BEFORE INSERT OR UPDATE ON public.global_shipment_cost_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_global_shipment_cost_entry_axes();

CREATE POLICY global_shipment_cost_entries_all ON public.global_shipment_cost_entries
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

CREATE POLICY global_shipment_cost_entries_select ON public.global_shipment_cost_entries
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(parent_tenant_id) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = global_shipment_cost_entries.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

COMMENT ON COLUMN public.global_shipment_cost_entries.cost_bucket IS 'Operational category: material, freight, customs, handling, finance, other.';

COMMENT ON COLUMN public.global_shipment_cost_entries.cost_component IS 'Voucher line axis: subtotal, carriage, vat_tax, misc.';

COMMENT ON COLUMN public.global_shipment_cost_entries.is_capitalizable IS 'When true, amount flows into landed unit cost (BDT stamp). When false, P&L / local opex only.';

ALTER TABLE public.global_shipment_cost_entries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_amount_check CHECK (amount >= 0::numeric);

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_pkey PRIMARY KEY (id);

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.global_shipment_sections(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_cost_entries
  ADD CONSTRAINT global_shipment_cost_entries_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.global_shipment_cost_entries TO anon;

GRANT ALL ON public.global_shipment_cost_entries TO authenticated;

GRANT ALL ON public.global_shipment_cost_entries TO service_role;