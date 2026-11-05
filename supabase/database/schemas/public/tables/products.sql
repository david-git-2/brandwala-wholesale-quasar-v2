CREATE TABLE public.products (
  id                          bigint                   DEFAULT nextval('public.products_id_seq'::regclass) NOT NULL,
  product_code                text,
  barcode                     text,
  name                        text,
  country_of_origin           text,
  brand                       text,
  category                    text,
  available_units             integer,
  languages                   text,
  batch_code_manufacture_date text,
  image_url                   text,
  expire_date                 text,
  minimum_order_quantity      integer,
  product_weight              numeric(12,3),
  package_weight              numeric(12,3),
  is_available                boolean,
  created_at                  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                  timestamp with time zone DEFAULT now() NOT NULL,
  vendor_code                 text,
  market_code                 text,
  vendor_id                   bigint,
  source                      text,
  hazardous                   boolean,
  parent_tenant_id            bigint,
  list_price_amount           numeric(12,4),
  list_price_currency_id      bigint,
  reference_cost_amount       numeric(12,4),
  reference_cost_currency_id  bigint,
  inserted_by_tenant_id       bigint
);

CREATE INDEX products_name_trgm_idx ON public.products USING gin (name public.gin_trgm_ops);

CREATE INDEX products_vendor_id_idx ON public.products (vendor_id);

CREATE UNIQUE INDEX uq_products_vendor_catalog_full_key ON public.products (parent_tenant_id, vendor_id, market_code, barcode, product_code)
  WHERE vendor_id IS NOT NULL AND parent_tenant_id IS NOT NULL AND market_code IS
    NOT NULL AND btrim(COALESCE(barcode, ''::text)) <> ''::text AND btrim(COALESCE(product_code, ''::text)) <> ''::text;

CREATE INDEX products_parent_tenant_id_idx ON public.products (parent_tenant_id);

CREATE INDEX products_name_idx ON public.products (name);

CREATE INDEX products_market_code_idx ON public.products (market_code);

CREATE INDEX products_list_price_currency_id_idx ON public.products (list_price_currency_id);

CREATE INDEX products_inserted_by_tenant_id_idx ON public.products (inserted_by_tenant_id);

CREATE INDEX products_category_idx ON public.products (category);

CREATE INDEX products_brand_trgm_idx ON public.products USING gin (brand public.gin_trgm_ops);

CREATE INDEX products_brand_idx ON public.products (brand);

CREATE INDEX products_barcode_idx ON public.products (barcode);

CREATE INDEX products_vendor_code_idx ON public.products (vendor_code);

CREATE INDEX products_reference_cost_currency_id_idx ON public.products (reference_cost_currency_id);

CREATE INDEX products_product_code_idx ON public.products (product_code);

CREATE INDEX products_parent_tenant_name_id_idx ON public.products (parent_tenant_id, name, id);

CREATE TRIGGER trg_products_set_parent_tenant_id
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.set_products_catalog_parent_tenant_id();

CREATE TRIGGER trg_products_set_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_products_sync_tenant_from_vendor
  BEFORE INSERT OR UPDATE OF vendor_id ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_product_tenant_from_vendor();

CREATE TRIGGER trg_products_sync_vendor_reference_fields
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_reference_fields();

CREATE POLICY products_delete ON public.products
  FOR DELETE
  TO authenticated
  USING (public.can_manage_products_for_parent(parent_tenant_id));

CREATE POLICY products_insert ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_products_for_parent(parent_tenant_id));

CREATE POLICY products_select ON public.products
  FOR SELECT
  TO authenticated
  USING (public.can_view_products_for_parent(parent_tenant_id));

CREATE POLICY products_update ON public.products
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_products_for_parent(parent_tenant_id))
  WITH CHECK (public.can_manage_products_for_parent(parent_tenant_id));

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;

ALTER TABLE public.products
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products
  ADD CONSTRAINT products_list_price_currency_check CHECK ((list_price_amount IS NULL) = (list_price_currency_id IS NULL));

ALTER TABLE public.products
  ADD CONSTRAINT products_list_price_currency_id_fkey FOREIGN KEY (list_price_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD CONSTRAINT products_market_code_fkey FOREIGN KEY (market_code) REFERENCES public.markets(code) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD CONSTRAINT products_pkey PRIMARY KEY (id);

ALTER TABLE public.products
  ADD CONSTRAINT products_reference_cost_currency_check CHECK ((reference_cost_amount IS NULL) = (reference_cost_currency_id IS NULL));

ALTER TABLE public.products
  ADD CONSTRAINT products_reference_cost_currency_id_fkey FOREIGN KEY (reference_cost_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD CONSTRAINT products_source_check CHECK (source = ANY (ARRAY['website'::text, 'excel'::text]));

ALTER TABLE public.products
  ADD CONSTRAINT products_inserted_by_tenant_id_fkey FOREIGN KEY (inserted_by_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD CONSTRAINT products_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD CONSTRAINT products_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT ALL ON public.products TO anon;

GRANT ALL ON public.products TO authenticated;

GRANT ALL ON public.products TO service_role;