CREATE TABLE public.notification_dispatch_settings (
  id               smallint DEFAULT 1 NOT NULL,
  functions_url    text     DEFAULT 'http://kong:8000'::text NOT NULL,
  service_role_key text
);

ALTER TABLE public.notification_dispatch_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notification_dispatch_settings
  ADD CONSTRAINT notification_dispatch_settings_id_check CHECK (id = 1);

ALTER TABLE public.notification_dispatch_settings
  ADD CONSTRAINT notification_dispatch_settings_pkey PRIMARY KEY (id);

GRANT ALL ON public.notification_dispatch_settings TO anon;

GRANT ALL ON public.notification_dispatch_settings TO authenticated;

GRANT ALL ON public.notification_dispatch_settings TO service_role;