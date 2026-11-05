CREATE TABLE public.bills (
  id                   bigint                        DEFAULT nextval('public.global_invoices_id_seq'::regclass) NOT NULL,
  parent_tenant_id     bigint                        NOT NULL,
  invoice_no           text                          NOT NULL,
  invoice_type         public.global_invoice_type    DEFAULT 'wholesale'::public.global_invoice_type NOT NULL,
  invoice_date         date                          DEFAULT CURRENT_DATE NOT NULL,
  retail_billing_mode  public.retail_billing_mode,
  invoice_status       public.global_invoice_status  DEFAULT 'draft'::public.global_invoice_status NOT NULL,
  recipient_profile_id bigint,
  recipient_name       text,
  recipient_phone      text,
  recipient_address    text,
  collection_source    public.collection_source_type NOT NULL,
  due_date             date,
  payment_status       text                          DEFAULT 'due'::text NOT NULL,
  total_amount         numeric(12,2)                 DEFAULT 0 NOT NULL,
  due_amount           numeric(12,2)                 DEFAULT 0 NOT NULL,
  paid_amount          numeric(12,2)                 DEFAULT 0 NOT NULL,
  subtotal_amount      numeric(12,2)                 DEFAULT 0 NOT NULL,
  discount_amount      numeric(12,2)                 DEFAULT 0 NOT NULL,
  shipping_charge      numeric(12,2)                 DEFAULT 0 NOT NULL,
  wrapping_charge      numeric(12,2)                 DEFAULT 0 NOT NULL,
  print_charge         numeric(12,2)                 DEFAULT 0 NOT NULL,
  note                 text,
  created_by           uuid,
  created_at           timestamp with time zone      DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone      DEFAULT now() NOT NULL,
  issued_by_tenant_id  bigint                        NOT NULL,
  written_off_amount   numeric(12,2)                 DEFAULT 0.00 NOT NULL,
  shop_order_id        bigint,
  charges_amount       numeric(12,2)                 DEFAULT 0 NOT NULL,
  channel_meta         jsonb                         DEFAULT '{}'::jsonb NOT NULL,
  profile_id           bigint,
  ap_shipment_id       bigint,
  ap_kind              text,
  document_kind        public.bill_document_kind     DEFAULT 'standard'::public.bill_document_kind NOT NULL,
  parent_bill_id       bigint,
  from_profile_id      bigint,
  to_profile_id        bigint,
  settlement_kind      public.bill_settlement_kind,
  source_type          text,
  source_id            text,
  source_key           text,
  currency_code        text                          DEFAULT 'BDT'::text NOT NULL,
  txn_currency_code    text,
  txn_total_amount     numeric(12,2),
  books_exchange_rate  numeric(15,6)
);

CREATE UNIQUE INDEX uq_active_standard_bill ON public.bills (parent_tenant_id, source_type, source_id, COALESCE(source_key, ''::text))
  WHERE document_kind = 'standard'::public.bill_document_kind AND source_type IS NOT NULL AND source_id IS NOT NULL AND invoice_status <> 'voided'::public.global_invoice_status;

CREATE INDEX idx_sales_invoices_shop_order_id ON public.bills (shop_order_id);

CREATE INDEX idx_sales_invoices_scoping ON public.bills (parent_tenant_id, issued_by_tenant_id, invoice_status, invoice_date);

CREATE INDEX global_invoices_recipient_profile_id_idx ON public.bills (recipient_profile_id);

CREATE INDEX global_invoices_parent_tenant_id_idx ON public.bills (parent_tenant_id);

CREATE INDEX global_invoices_issued_by_tenant_id_idx ON public.bills (issued_by_tenant_id);

CREATE INDEX bills_to_profile_id_idx ON public.bills (to_profile_id);

CREATE INDEX bills_profile_id_idx ON public.bills (profile_id);

CREATE INDEX bills_parent_bill_id_idx ON public.bills (parent_bill_id)
  WHERE parent_bill_id IS NOT NULL;

CREATE INDEX bills_from_profile_id_idx ON public.bills (from_profile_id);

CREATE INDEX bills_ap_shipment_id_idx ON public.bills (ap_shipment_id)
  WHERE invoice_type = 'ap'::public.global_invoice_type;

CREATE TRIGGER trg_global_invoices_default_issued_by
  BEFORE INSERT ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.global_invoices_default_issued_by_tenant_id();

CREATE TRIGGER trg_global_invoices_set_updated_at
  BEFORE UPDATE ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_validate_global_invoice_profiles_insert_update
  BEFORE INSERT OR UPDATE ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_validate_global_invoice_profiles();

CREATE POLICY global_invoices_write ON public.bills
  TO authenticated
  USING ((public.membership_has_module_action(issued_by_tenant_id, 'global_invoice'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)))
  WITH CHECK ((public.membership_has_module_action(issued_by_tenant_id, 'global_invoice'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

CREATE POLICY global_invoices_select ON public.bills
  FOR SELECT
  TO authenticated
  USING
    ((public.has_active_tenant_membership(issued_by_tenant_id) OR public.user_can_manage_parent_tenant(parent_tenant_id) OR ((invoice_type = 'ap'::public.global_invoice_type) AND
    (public.membership_has_module_action(parent_tenant_id, 'global_invoice'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM (public.tenants ct
     JOIN public.memberships m ON ((m.tenant_id = ct.id)))
  WHERE
    ((ct.parent_id = bills.parent_tenant_id) AND public.membership_email_matches_current_user(m.email) AND (m.is_active = true) AND public.membership_has_module_action(ct.id,
    'global_invoice'::text, 'view'::text))))))));

COMMENT ON TABLE public.bills IS 'Bills (spec). parent_tenant_id = parent books/stock, issued_by_tenant_id = selling child. Channel extras (COD, fulfillment) live in channel_meta.';

ALTER SEQUENCE public.global_invoices_id_seq OWNED BY public.bills.id;

ALTER TABLE public.bills
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bills
  ADD CONSTRAINT bills_ap_kind_check
    CHECK
    (ap_kind IS NULL OR (ap_kind = ANY (ARRAY['vendor'::text, 'cargo'::text, 'local'::text, 'material'::text, 'freight'::text, 'customs'::text, 'handling'::text, 'finance'::text,
    'other'::text])));

ALTER TABLE public.bills
  ADD CONSTRAINT bills_document_parent_check
    CHECK (document_kind = 'standard'::public.bill_document_kind AND parent_bill_id IS NULL OR document_kind <> 'standard'::public.bill_document_kind AND parent_bill_id IS
    NOT NULL);

ALTER TABLE public.bills
  ADD CONSTRAINT bills_from_to_distinct CHECK (from_profile_id IS NULL OR to_profile_id IS NULL OR from_profile_id <> to_profile_id);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_charges_amount_check CHECK (charges_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_discount_amount_check CHECK (discount_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_due_amount_check CHECK (due_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_paid_amount_check CHECK (paid_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_payment_status_check CHECK (payment_status = ANY (ARRAY['due'::text, 'partially_paid'::text, 'paid'::text, 'settled_with_write_off'::text]));

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_pkey PRIMARY KEY (id);

ALTER TABLE public.bills
  ADD CONSTRAINT bills_parent_bill_id_fkey FOREIGN KEY (parent_bill_id) REFERENCES public.bills(id) ON DELETE RESTRICT;

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_print_charge_check CHECK (print_charge >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_shipping_charge_check CHECK (shipping_charge >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_subtotal_amount_check CHECK (subtotal_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_total_amount_check CHECK (total_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_wrapping_charge_check CHECK (wrapping_charge >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT sales_invoices_parent_tenant_id_invoice_no_key UNIQUE (parent_tenant_id, invoice_no);

ALTER TABLE public.bills
  ADD CONSTRAINT sales_invoices_written_off_amount_check CHECK (written_off_amount >= 0::numeric);

ALTER TABLE public.bills
  ADD CONSTRAINT bills_ap_shipment_id_fkey FOREIGN KEY (ap_shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.bills
  ADD CONSTRAINT bills_from_profile_id_fkey FOREIGN KEY (from_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;

ALTER TABLE public.bills
  ADD CONSTRAINT bills_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.bills
  ADD CONSTRAINT bills_to_profile_id_fkey FOREIGN KEY (to_profile_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_recipient_profile_id_fkey FOREIGN KEY (recipient_profile_id) REFERENCES public.recipient_profiles(id) ON DELETE RESTRICT;

ALTER TABLE public.bills
  ADD CONSTRAINT sales_invoices_shop_order_id_fkey FOREIGN KEY (shop_order_id) REFERENCES public.shop_orders(id) ON DELETE SET NULL;

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_issued_by_tenant_id_fkey FOREIGN KEY (issued_by_tenant_id) REFERENCES public.tenants(id);

ALTER TABLE public.bills
  ADD CONSTRAINT global_invoices_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.bills TO anon;

GRANT ALL ON public.bills TO authenticated;

GRANT ALL ON public.bills TO service_role;