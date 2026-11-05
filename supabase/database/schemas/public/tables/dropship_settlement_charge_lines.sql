CREATE TABLE public.dropship_settlement_charge_lines (
  id            bigint                                  GENERATED ALWAYS AS IDENTITY NOT NULL,
  settlement_id bigint                                  NOT NULL,
  charge_type   public.dropship_settlement_charge_type  NOT NULL,
  amount        numeric(15,2)                           DEFAULT 0 NOT NULL,
  payer         public.dropship_settlement_charge_payer NOT NULL,
  created_at    timestamp with time zone                DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone                DEFAULT now() NOT NULL
);

CREATE INDEX idx_dropship_settlement_charge_lines_settlement ON public.dropship_settlement_charge_lines (settlement_id);

CREATE TRIGGER trg_dropship_settlement_charge_lines_set_updated_at
  BEFORE UPDATE ON public.dropship_settlement_charge_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY dropship_settlement_charge_lines_staff_all ON public.dropship_settlement_charge_lines
  USING ((EXISTS ( SELECT 1
   FROM public.dropship_order_settlements s
  WHERE ((s.id = dropship_settlement_charge_lines.settlement_id) AND public.is_tenant_staff(s.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.dropship_order_settlements s
  WHERE ((s.id = dropship_settlement_charge_lines.settlement_id) AND public.is_tenant_staff(s.tenant_id)))));

ALTER TABLE public.dropship_settlement_charge_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dropship_settlement_charge_lines
  ADD CONSTRAINT dropship_settlement_charge_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.dropship_settlement_charge_lines
  ADD CONSTRAINT dropship_settlement_charge_lines_settlement_id_charge_type_key UNIQUE (settlement_id, charge_type);

ALTER TABLE public.dropship_settlement_charge_lines
  ADD CONSTRAINT dropship_settlement_charge_lines_settlement_id_fkey FOREIGN KEY (settlement_id) REFERENCES public.dropship_order_settlements(id) ON DELETE CASCADE;

GRANT ALL ON public.dropship_settlement_charge_lines TO anon;

GRANT ALL ON public.dropship_settlement_charge_lines TO authenticated;

GRANT ALL ON public.dropship_settlement_charge_lines TO service_role;