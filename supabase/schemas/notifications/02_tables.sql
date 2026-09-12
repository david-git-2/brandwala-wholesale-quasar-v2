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
