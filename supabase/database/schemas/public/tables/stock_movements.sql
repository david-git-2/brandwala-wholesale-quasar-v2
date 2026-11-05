CREATE TABLE public.stock_movements (
  id               bigint                     DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
  tenant_id        bigint                     NOT NULL,
  movement_no      text                       NOT NULL,
  movement_type    public.stock_movement_type NOT NULL,
  reference_type   text,
  reference_id     text,
  notes            text,
  is_posted        boolean                    DEFAULT false NOT NULL,
  posted_at        timestamp with time zone,
  created_by_email text,
  created_at       timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone   DEFAULT now() NOT NULL
);

CREATE POLICY stock_movements_all ON public.stock_movements
  TO authenticated
  USING (public.has_active_tenant_membership(tenant_id));

ALTER SEQUENCE public.stock_movements_id_seq OWNED BY public.stock_movements.id;

ALTER TABLE public.stock_movements
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.stock_movements TO anon;

GRANT ALL ON public.stock_movements TO authenticated;

GRANT ALL ON public.stock_movements TO service_role;