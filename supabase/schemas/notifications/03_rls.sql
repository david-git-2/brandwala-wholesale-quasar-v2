-- Notifications domain — RLS

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notification_recipients_select_own ON public.notification_recipients;
DROP POLICY IF EXISTS notification_recipients_update_own ON public.notification_recipients;

CREATE POLICY notification_recipients_select_own
  ON public.notification_recipients
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY notification_recipients_update_own
  ON public.notification_recipients
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
