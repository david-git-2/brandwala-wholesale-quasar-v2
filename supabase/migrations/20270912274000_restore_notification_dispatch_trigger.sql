begin;

drop trigger if exists trg_notification_recipients_dispatch on public.notification_recipients;

create trigger trg_notification_recipients_dispatch
  after insert on public.notification_recipients
  for each row
  execute function public.trg_notification_recipients_dispatch();

commit;
