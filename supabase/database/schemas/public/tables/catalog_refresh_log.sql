CREATE TABLE public.catalog_refresh_log (
  id               bigint                   DEFAULT nextval('public.catalog_refresh_log_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  source           text                     NOT NULL,
  event_kind       text                     NOT NULL,
  source_url       text,
  file_name        text,
  ran_at           timestamp with time zone DEFAULT now() NOT NULL,
  products_updated integer,
  duration_seconds integer
);

CREATE INDEX catalog_refresh_log_list_idx ON public.catalog_refresh_log (parent_tenant_id, source, event_kind, ran_at DESC);

ALTER SEQUENCE public.catalog_refresh_log_id_seq OWNED BY public.catalog_refresh_log.id;

ALTER TABLE public.catalog_refresh_log
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalog_refresh_log
  ADD CONSTRAINT catalog_refresh_log_event_kind_check CHECK (event_kind = ANY (ARRAY['scrape'::text, 'upload'::text]));

ALTER TABLE public.catalog_refresh_log
  ADD CONSTRAINT catalog_refresh_log_payload_check CHECK (event_kind = 'scrape'::text AND source_url IS
    NOT NULL AND file_name IS NULL OR event_kind = 'upload'::text AND file_name IS NOT NULL);

ALTER TABLE public.catalog_refresh_log
  ADD CONSTRAINT catalog_refresh_log_pkey PRIMARY KEY (id);

GRANT ALL ON public.catalog_refresh_log TO anon;

GRANT ALL ON public.catalog_refresh_log TO authenticated;

GRANT ALL ON public.catalog_refresh_log TO service_role;