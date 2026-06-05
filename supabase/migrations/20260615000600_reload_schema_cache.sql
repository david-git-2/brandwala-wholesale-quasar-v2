-- Reload PostgREST schema cache to make sure the newly added/updated functions are recognized
do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;
