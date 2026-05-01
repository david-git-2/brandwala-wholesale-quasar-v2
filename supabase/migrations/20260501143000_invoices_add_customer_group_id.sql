alter table public.invoices
  add column if not exists customer_group_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'invoices_customer_group_id_fkey'
      and conrelid = 'public.invoices'::regclass
  ) then
    alter table public.invoices
      add constraint invoices_customer_group_id_fkey
      foreign key (customer_group_id)
      references public.customer_groups(id)
      on delete set null;
  end if;
end
$$;

create index if not exists invoices_customer_group_id_idx
  on public.invoices (customer_group_id);

update public.invoices i
set customer_group_id = o.customer_group_id
from public.orders o
where i.source_type = 'order'
  and i.source_id = o.id
  and i.customer_group_id is null;
