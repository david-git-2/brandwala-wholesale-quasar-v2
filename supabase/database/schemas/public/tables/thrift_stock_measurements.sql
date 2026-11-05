CREATE TABLE public.thrift_stock_measurements (
  stock_id             bigint                   NOT NULL,
  tenant_id            bigint                   NOT NULL,
  bust_in              numeric(5,1),
  waist_in             numeric(5,1),
  hips_in              numeric(5,1),
  length_in            numeric(5,1),
  shoulder_width_in    numeric(5,1),
  sleeve_length_in     numeric(5,1),
  arm_circumference_in numeric(5,1),
  hem_width_in         numeric(5,1),
  neck_opening_in      numeric(5,1),
  sleeve_type          text,
  neckline             text,
  dress_style          text,
  fabric_stretch       text,
  lining               boolean,
  closure_type         text,
  measurement_notes    text,
  inserted_by          text                     DEFAULT 'system'::text NOT NULL,
  created_at           timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at           timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX idx_thrift_stock_measurements_waist ON public.thrift_stock_measurements (tenant_id, waist_in);

CREATE INDEX idx_thrift_stock_measurements_hips ON public.thrift_stock_measurements (tenant_id, hips_in);

CREATE INDEX idx_thrift_stock_measurements_bust ON public.thrift_stock_measurements (tenant_id, bust_in);

CREATE TRIGGER trg_thrift_stock_measurements_updated_at
  BEFORE UPDATE ON public.thrift_stock_measurements
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_stock_measurements ON public.thrift_stock_measurements
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_stock_measurements.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_stock_measurements ON public.thrift_stock_measurements
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_stock'::text, 'edit'::text));

ALTER TABLE public.thrift_stock_measurements
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_stock_measurements
  ADD CONSTRAINT thrift_stock_measurements_pkey PRIMARY KEY (stock_id);

ALTER TABLE public.thrift_stock_measurements
  ADD CONSTRAINT thrift_stock_measurements_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_stock_measurements TO anon;

GRANT ALL ON public.thrift_stock_measurements TO authenticated;

GRANT ALL ON public.thrift_stock_measurements TO service_role;