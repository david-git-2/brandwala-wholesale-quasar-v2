CREATE TABLE public.notifications (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  parent_tenant_id    bigint                   NOT NULL,
  operating_tenant_id bigint,
  event_type          text                     NOT NULL,
  title               text                     NOT NULL,
  body                text,
  link_path           text,
  entity_type         text,
  entity_id           text,
  created_at          timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX notifications_parent_tenant_created_idx ON public.notifications (parent_tenant_id, created_at DESC);

CREATE INDEX notifications_parent_operating_created_idx ON public.notifications (parent_tenant_id, operating_tenant_id, created_at DESC);

CREATE INDEX notifications_event_type_created_idx ON public.notifications (event_type, created_at DESC);

ALTER TABLE public.notifications
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_title_not_blank CHECK (length(TRIM(BOTH FROM title)) > 0);

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_operating_tenant_id_fkey FOREIGN KEY (operating_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.notifications TO anon;

GRANT ALL ON public.notifications TO authenticated;

GRANT ALL ON public.notifications TO service_role;