CREATE TABLE public.bill_settlements (
  id                      bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  parent_tenant_id        bigint                   NOT NULL,
  bill_id                 bigint                   NOT NULL,
  allocator_kind          text                     NOT NULL,
  allocator_id            bigint                   NOT NULL,
  allocated_txn_amount    numeric(12,2)            DEFAULT 0 NOT NULL,
  allocated_books_amount  numeric(12,2)            NOT NULL,
  books_rate_at_alloc     numeric(15,6),
  fx_realized_books_delta numeric(12,2),
  created_at              timestamp with time zone DEFAULT now() NOT NULL,
  pay_allocation_id       bigint
);

CREATE UNIQUE INDEX bill_settlements_pay_allocation_uidx ON public.bill_settlements (pay_allocation_id)
  WHERE pay_allocation_id IS NOT NULL;

CREATE INDEX bill_settlements_allocator_idx ON public.bill_settlements (allocator_kind, allocator_id);

CREATE INDEX bill_settlements_bill_id_idx ON public.bill_settlements (bill_id);

ALTER TABLE public.bill_settlements
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bill_settlements
  ADD CONSTRAINT bill_settlements_allocator_kind_check CHECK (allocator_kind = ANY (ARRAY['pay'::text, 'credit_note'::text, 'custody_entry'::text]));

ALTER TABLE public.bill_settlements
  ADD CONSTRAINT bill_settlements_pkey PRIMARY KEY (id);

ALTER TABLE public.bill_settlements
  ADD CONSTRAINT bill_settlements_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bills(id) ON DELETE RESTRICT;

ALTER TABLE public.bill_settlements
  ADD CONSTRAINT bill_settlements_pay_allocation_id_fkey FOREIGN KEY (pay_allocation_id) REFERENCES public.pay_allocations(id);

ALTER TABLE public.bill_settlements
  ADD CONSTRAINT bill_settlements_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id);

GRANT ALL ON public.bill_settlements TO anon;

GRANT ALL ON public.bill_settlements TO authenticated;

GRANT ALL ON public.bill_settlements TO service_role;