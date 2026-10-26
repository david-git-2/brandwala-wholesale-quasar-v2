begin;

alter table public.thrift_stocks
  alter column name drop not null,
  alter column color drop not null,
  alter column size drop not null;

commit;
