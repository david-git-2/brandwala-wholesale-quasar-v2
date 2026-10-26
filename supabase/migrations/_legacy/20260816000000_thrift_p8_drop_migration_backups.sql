-- Thrift P8 Drop Migration Backups after production sign-off
begin;

drop table if exists public._bak_thrift_stock_images cascade;
drop table if exists public._bak_thrift_pricings cascade;
drop table if exists public._bak_thrift_stocks cascade;
drop table if exists public._bak_thrift_shipments cascade;
drop table if exists public._bak_thrift_settings cascade;

commit;
