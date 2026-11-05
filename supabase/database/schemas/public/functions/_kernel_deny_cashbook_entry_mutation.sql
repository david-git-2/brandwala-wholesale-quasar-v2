CREATE FUNCTION public._kernel_deny_cashbook_entry_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if coalesce(current_setting('role', true), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    if TG_OP = 'DELETE' then
      return OLD;
    end if;
    return NEW;
  end if;
  raise exception 'cashbook_entries are append-only; post a reversing entry instead';
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_deny_cashbook_entry_mutation() TO anon;

GRANT ALL ON FUNCTION public._kernel_deny_cashbook_entry_mutation() TO authenticated;

GRANT ALL ON FUNCTION public._kernel_deny_cashbook_entry_mutation() TO service_role;