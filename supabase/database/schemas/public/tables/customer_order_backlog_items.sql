CREATE TABLE public.customer_order_backlog_items (
  id                 bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id          bigint                   NOT NULL,
  profile_id         bigint                   NOT NULL,
  product_id         bigint                   NOT NULL,
  order_id           bigint,
  order_item_id      bigint,
  requested_quantity integer                  NOT NULL,
  fulfilled_quantity integer                  DEFAULT 0 NOT NULL,
  backlog_status     text                     DEFAULT 'open'::text NOT NULL,
  created_at         timestamp with time zone DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY customer_order_backlog_items_tenant_isolation ON public.customer_order_backlog_items
  USING ((tenant_id = (current_setting('app.current_tenant_id'::text, true))::bigint));

ALTER TABLE public.customer_order_backlog_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_backlog_status_check
    CHECK (backlog_status = ANY (ARRAY['open'::text, 'partially_fulfilled'::text, 'fulfilled'::text, 'cancelled'::text]));

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_fulfilled_quantity_check CHECK (fulfilled_quantity >= 0);

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_requested_quantity_check CHECK (requested_quantity > 0);

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT uq_customer_backlog_item UNIQUE (tenant_id, profile_id, product_id);

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.shop_order_items(id) ON DELETE SET NULL;

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE SET NULL;

ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.customer_order_backlog_items TO anon;

GRANT ALL ON public.customer_order_backlog_items TO authenticated;

GRANT ALL ON public.customer_order_backlog_items TO service_role;