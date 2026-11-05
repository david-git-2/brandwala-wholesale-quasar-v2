CREATE TABLE public.global_shipments (
  id                            bigint                      DEFAULT nextval('public.global_shipments_id_seq'::regclass) NOT NULL,
  parent_tenant_id              bigint                      NOT NULL,
  name                          text                        NOT NULL,
  tenant_shipment_id            integer,
  type                          public.global_shipment_type DEFAULT 'international'::public.global_shipment_type NOT NULL,
  status                        text                        DEFAULT 'draft'::text NOT NULL,
  shipment_purchase_currency_id bigint,
  shipment_cost_currency_id     bigint,
  received_weight               numeric,
  stock_ready                   boolean                     DEFAULT false NOT NULL,
  created_at                    timestamp with time zone    DEFAULT now() NOT NULL,
  updated_at                    timestamp with time zone    DEFAULT now() NOT NULL,
  received_date                 date,
  cargo_invoice_total           numeric,
  purchase_invoice_total        numeric,
  assigned_child_tenant_id      bigint,
  vendor_id                     bigint,
  cargo_company_id              bigint,
  total_weight_kg               numeric,
  inventory_added               boolean                     DEFAULT false NOT NULL,
  progress_tag_id               bigint,
  public_tracking_token         text,
  progress_flow_id              bigint,
  is_archived                   boolean                     DEFAULT false NOT NULL,
  archived_at                   timestamp with time zone,
  costs_locked                  boolean                     DEFAULT false NOT NULL,
  costs_locked_at               timestamp with time zone,
  costs_locked_by               uuid,
  is_closed                     boolean                     DEFAULT false NOT NULL
);

CREATE INDEX global_shipments_cargo_company_idx ON public.global_shipments (cargo_company_id);

CREATE INDEX global_shipments_assigned_child_idx ON public.global_shipments (assigned_child_tenant_id)
  WHERE assigned_child_tenant_id IS NOT NULL;

CREATE INDEX global_shipments_progress_tag_id_idx ON public.global_shipments (progress_tag_id);

CREATE INDEX global_shipments_vendor_idx ON public.global_shipments (vendor_id);

CREATE INDEX global_shipments_parent_tenant_is_archived_idx ON public.global_shipments (parent_tenant_id, is_archived);

CREATE INDEX global_shipments_parent_tenant_idx ON public.global_shipments (parent_tenant_id);

CREATE INDEX global_shipments_progress_flow_idx ON public.global_shipments (progress_flow_id);

CREATE UNIQUE INDEX global_shipments_public_tracking_token_key ON public.global_shipments (public_tracking_token)
  WHERE public_tracking_token IS NOT NULL;

CREATE TRIGGER trg_global_shipments_guard_costs_locked
  BEFORE UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public._guard_global_shipment_costs_locked();

CREATE TRIGGER trg_global_shipments_restamp_weight
  AFTER UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public._restamp_global_shipment_on_weight_change();

CREATE TRIGGER trg_global_shipments_updated_at
  BEFORE UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_sync_global_shipment_header_aliases
  BEFORE INSERT OR UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_global_shipment_header_aliases();

CREATE POLICY global_shipments_all ON public.global_shipments
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

CREATE POLICY global_shipments_select ON public.global_shipments
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(parent_tenant_id) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = global_shipments.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

COMMENT ON COLUMN public.global_shipments.total_weight_kg IS 'Cargo invoice weight (kg). Plan name for live received_weight — dual-written.';

COMMENT ON COLUMN public.global_shipments.inventory_added IS 'True after finalize posts stock. Plan name for live stock_ready — dual-written.';

COMMENT ON COLUMN public.global_shipments.progress_tag_id IS 'Denormalized current shipment_progress tag for list speed. SSOT remains entity_tags.';

COMMENT ON COLUMN public.global_shipments.public_tracking_token IS 'Random token for unauthenticated public tracking page. NULL = no link generated yet.';

COMMENT ON COLUMN public.global_shipments.is_archived IS 'Archival flag to move shipment out of active operational table view.';

COMMENT ON COLUMN public.global_shipments.archived_at IS 'Timestamp when the shipment was archived.';

COMMENT ON COLUMN public.global_shipments.costs_locked IS 'When true, cost entries and cost-affecting line edits are frozen.';

COMMENT ON COLUMN public.global_shipments.costs_locked_at IS 'Timestamp when shipment costs were locked for books.';

COMMENT ON COLUMN public.global_shipments.costs_locked_by IS 'User who locked shipment costs.';

COMMENT ON COLUMN public.global_shipments.is_closed IS 'When true, shipment is read-only (close action). Distinct from costs_locked and is_archived.';

ALTER SEQUENCE public.global_shipments_id_seq OWNED BY public.global_shipments.id;

ALTER TABLE public.global_shipments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_cargo_company_id_fkey FOREIGN KEY (cargo_company_id) REFERENCES public.cargo_companies(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_costs_locked_by_fkey FOREIGN KEY (costs_locked_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_pkey PRIMARY KEY (id);

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_shipment_cost_currency_id_fkey FOREIGN KEY (shipment_cost_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_shipment_purchase_currency_id_fkey FOREIGN KEY (shipment_purchase_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_status_check CHECK (status = ANY (ARRAY['draft'::text, 'in_transit'::text, 'received'::text, 'cancelled'::text]));

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_progress_flow_id_fkey FOREIGN KEY (progress_flow_id) REFERENCES public.shipment_progress_flows(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_progress_tag_id_fkey FOREIGN KEY (progress_tag_id) REFERENCES public.tags(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_assigned_child_tenant_id_fkey FOREIGN KEY (assigned_child_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipments
  ADD CONSTRAINT global_shipments_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE RESTRICT;

GRANT ALL ON public.global_shipments TO anon;

GRANT ALL ON public.global_shipments TO authenticated;

GRANT ALL ON public.global_shipments TO service_role;