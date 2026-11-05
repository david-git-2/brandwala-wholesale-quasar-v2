CREATE TABLE public.koba_products (
  id                    uuid                     DEFAULT gen_random_uuid() NOT NULL,
  tenant_id             bigint                   NOT NULL,
  source_type           text                     NOT NULL,
  source_id             text                     NOT NULL,
  name                  text                     NOT NULL,
  sku                   text,
  barcode               text,
  slug                  text,
  permalink             text,
  description           text,
  stock_quantity        integer                  DEFAULT 0 NOT NULL,
  in_stock              boolean                  DEFAULT true NOT NULL,
  price                 numeric(12,2)            DEFAULT 0.00 NOT NULL,
  regular_price         numeric(12,2),
  sale_price            numeric(12,2),
  currency              text                     DEFAULT 'GBP'::text,
  commission_percentage numeric(5,2),
  commission            numeric(12,2),
  brand_id              bigint,
  category_id           bigint,
  image_url             text,
  raw_data              jsonb                    NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX koba_products_barcode_idx ON public.koba_products (barcode);

CREATE INDEX koba_products_sku_idx ON public.koba_products (sku);

CREATE INDEX koba_products_source_type_idx ON public.koba_products (source_type);

CREATE INDEX koba_products_tenant_id_idx ON public.koba_products (tenant_id);

CREATE TRIGGER trg_koba_products_updated_at
  BEFORE UPDATE ON public.koba_products
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_products_admin_all ON public.koba_products
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)))
  WITH CHECK ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)));

CREATE POLICY koba_products_tenant_member_read ON public.koba_products
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id) OR (tenant_id = public.current_tenant_id())));

ALTER TABLE public.koba_products
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_products
  ADD CONSTRAINT koba_products_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.koba_brands(id) ON DELETE SET NULL;

ALTER TABLE public.koba_products
  ADD CONSTRAINT koba_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.koba_categories(id) ON DELETE SET NULL;

ALTER TABLE public.koba_products
  ADD CONSTRAINT koba_products_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_products
  ADD CONSTRAINT koba_products_source_type_check CHECK (source_type = ANY (ARRAY['retail'::text, 'wholesale'::text]));

ALTER TABLE public.koba_products
  ADD CONSTRAINT uq_koba_products_source UNIQUE (tenant_id, source_type, source_id);

ALTER TABLE public.koba_products
  ADD CONSTRAINT koba_products_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_products TO anon;

GRANT ALL ON public.koba_products TO authenticated;

GRANT ALL ON public.koba_products TO service_role;