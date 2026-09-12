-- Notifications domain — tables

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  operating_tenant_id bigint REFERENCES public.tenants(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  title text NOT NULL,
  body text,
  link_path text,
  entity_type text,
  entity_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notifications_title_not_blank CHECK (length(trim(title)) > 0)
);

ALTER TABLE public.notifications OWNER TO postgres;

CREATE INDEX IF NOT EXISTS notifications_parent_tenant_created_idx
  ON public.notifications (parent_tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_parent_operating_created_idx
  ON public.notifications (parent_tenant_id, operating_tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_event_type_created_idx
  ON public.notifications (event_type, created_at DESC);

CREATE TABLE IF NOT EXISTS public.notification_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_recipients_unique_user UNIQUE (notification_id, user_id)
);

ALTER TABLE public.notification_recipients OWNER TO postgres;

CREATE INDEX IF NOT EXISTS notification_recipients_user_read_created_idx
  ON public.notification_recipients (user_id, read_at, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_recipients_notification_id_idx
  ON public.notification_recipients (notification_id);

ALTER TABLE public.notification_recipients REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_recipients;

CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_telegram boolean NOT NULL DEFAULT false,
  channel_push boolean NOT NULL DEFAULT false,
  channel_email boolean NOT NULL DEFAULT false,
  event_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_notification_preferences OWNER TO postgres;

CREATE TABLE IF NOT EXISTS public.user_push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'web',
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  CONSTRAINT user_push_subscriptions_unique_token UNIQUE (user_id, fcm_token),
  CONSTRAINT user_push_subscriptions_platform_check CHECK (platform IN ('web', 'android'))
);

ALTER TABLE public.user_push_subscriptions OWNER TO postgres;

CREATE INDEX IF NOT EXISTS user_push_subscriptions_user_id_idx
  ON public.user_push_subscriptions (user_id);

CREATE TABLE IF NOT EXISTS public.notification_delivery_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel text NOT NULL,
  status text NOT NULL,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_delivery_log_channel_check CHECK (channel IN ('telegram', 'push', 'email')),
  CONSTRAINT notification_delivery_log_status_check CHECK (status IN ('sent', 'failed'))
);

ALTER TABLE public.notification_delivery_log OWNER TO postgres;

CREATE INDEX IF NOT EXISTS notification_delivery_log_user_created_idx
  ON public.notification_delivery_log (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_delivery_log_notification_id_idx
  ON public.notification_delivery_log (notification_id);

CREATE TABLE IF NOT EXISTS public.notification_dispatch_settings (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  functions_url text NOT NULL DEFAULT 'http://kong:8000',
  service_role_key text
);

ALTER TABLE public.notification_dispatch_settings OWNER TO postgres;
