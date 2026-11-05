CREATE TABLE public.app_release_versions (
  id                  smallint                 DEFAULT 1 NOT NULL,
  backend_version     text                     DEFAULT 'unknown'::text NOT NULL,
  frontend_version    text                     DEFAULT 'unknown'::text NOT NULL,
  backend_updated_at  timestamp with time zone DEFAULT now() NOT NULL,
  frontend_updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.app_release_versions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.app_release_versions
  ADD CONSTRAINT app_release_versions_pkey PRIMARY KEY (id);

ALTER TABLE public.app_release_versions
  ADD CONSTRAINT app_release_versions_singleton CHECK (id = 1);

GRANT ALL ON public.app_release_versions TO anon;

GRANT ALL ON public.app_release_versions TO authenticated;

GRANT ALL ON public.app_release_versions TO service_role;