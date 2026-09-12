-- Dispatch settings table (local postgres cannot ALTER DATABASE app.settings.*).

CREATE TABLE IF NOT EXISTS public.notification_dispatch_settings (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  functions_url text NOT NULL DEFAULT 'http://kong:8000',
  service_role_key text
);

ALTER TABLE public.notification_dispatch_settings ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notification_dispatch_settings FROM PUBLIC;
REVOKE ALL ON public.notification_dispatch_settings FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_notification_dispatch_settings(
  p_functions_url text,
  p_service_role_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_dispatch_settings (id, functions_url, service_role_key)
  VALUES (
    1,
    coalesce(nullif(trim(p_functions_url), ''), 'http://kong:8000'),
    nullif(trim(p_service_role_key), '')
  )
  ON CONFLICT (id) DO UPDATE SET
    functions_url = EXCLUDED.functions_url,
    service_role_key = EXCLUDED.service_role_key;
END;
$$;

REVOKE ALL ON FUNCTION public.set_notification_dispatch_settings(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_notification_dispatch_settings(text, text) TO postgres;

CREATE OR REPLACE FUNCTION public.trg_notification_recipients_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_functions_url text;
  v_service_role_key text;
  v_url text;
BEGIN
  SELECT s.functions_url, s.service_role_key
  INTO v_functions_url, v_service_role_key
  FROM public.notification_dispatch_settings s
  WHERE s.id = 1;

  v_functions_url := coalesce(nullif(trim(v_functions_url), ''), 'http://kong:8000');
  v_service_role_key := nullif(trim(v_service_role_key), '');

  IF v_service_role_key IS NULL THEN
    RETURN NEW;
  END IF;

  v_url := rtrim(v_functions_url, '/') || '/functions/v1/dispatch-notification';

  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object(
        'notification_id', NEW.notification_id,
        'user_id', NEW.user_id
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE LOG 'dispatch-notification enqueue failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;
