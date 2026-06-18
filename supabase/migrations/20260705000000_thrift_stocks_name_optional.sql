-- Product name is optional for thrift stock items (mobile app registers without a name).
begin;

alter table public.thrift_stocks
  alter column name drop not null;

comment on column public.thrift_stocks.name is 'Optional display name for the stock item.';

commit;
