-- Notifications domain — RLS

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_delivery_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notification_recipients_select_own ON public.notification_recipients;
DROP POLICY IF EXISTS notification_recipients_update_own ON public.notification_recipients;

CREATE POLICY notification_recipients_select_own
  ON public.notification_recipients
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY notification_recipients_update_own
  ON public.notification_recipients
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_notification_preferences_select_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_insert_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_update_own ON public.user_notification_preferences;
DROP POLICY IF EXISTS user_notification_preferences_delete_own ON public.user_notification_preferences;

CREATE POLICY user_notification_preferences_select_own
  ON public.user_notification_preferences
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY user_notification_preferences_insert_own
  ON public.user_notification_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_update_own
  ON public.user_notification_preferences
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_delete_own
  ON public.user_notification_preferences
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_push_subscriptions_select_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_insert_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_update_own ON public.user_push_subscriptions;
DROP POLICY IF EXISTS user_push_subscriptions_delete_own ON public.user_push_subscriptions;

CREATE POLICY user_push_subscriptions_select_own
  ON public.user_push_subscriptions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_insert_own
  ON public.user_push_subscriptions
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_update_own
  ON public.user_push_subscriptions
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY user_push_subscriptions_delete_own
  ON public.user_push_subscriptions
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS notification_delivery_log_select_own ON public.notification_delivery_log;

CREATE POLICY notification_delivery_log_select_own
  ON public.notification_delivery_log
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_subscriptions TO authenticated;
GRANT SELECT ON public.notification_delivery_log TO authenticated;

GRANT SELECT ON public.notifications TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_preferences TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_subscriptions TO service_role;
GRANT SELECT, INSERT ON public.notification_delivery_log TO service_role;

ALTER TABLE public.notification_dispatch_settings ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notification_dispatch_settings FROM PUBLIC;
REVOKE ALL ON public.notification_dispatch_settings FROM anon, authenticated;
