-- service_role access for dispatch-notification Edge Function + default local functions URL.

GRANT SELECT ON public.notifications TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_preferences TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_subscriptions TO service_role;
GRANT SELECT, INSERT ON public.notification_delivery_log TO service_role;

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
  v_functions_url := coalesce(
    nullif(trim(coalesce(current_setting('app.settings.supabase_functions_url', true), '')), ''),
    'http://kong:8000'
  );
  v_service_role_key := nullif(trim(coalesce(current_setting('app.settings.service_role_key', true), '')), '');

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
