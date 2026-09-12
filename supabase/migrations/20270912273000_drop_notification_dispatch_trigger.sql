begin;

drop trigger if exists trg_notification_recipients_dispatch on public.notification_recipients;

commit;
