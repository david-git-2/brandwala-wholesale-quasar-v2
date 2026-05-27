begin;

grant select, insert, update, delete on public.koba_retail_settings to authenticated, service_role;
grant usage on sequence public.koba_retail_settings_id_seq to authenticated, service_role;

create policy "Users can update retail settings for their tenant"
  on public.koba_retail_settings
  for update
  to authenticated
  using (
    tenant_id = (select tenant_id from auth.users where id = auth.uid() limit 1)
  )
  with check (
    tenant_id = (select tenant_id from auth.users where id = auth.uid() limit 1)
  );

commit;
