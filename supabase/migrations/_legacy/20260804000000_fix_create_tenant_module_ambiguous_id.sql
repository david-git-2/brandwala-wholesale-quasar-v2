-- Fix PL/pgSQL ambiguity: RETURNS TABLE columns shadow INSERT RETURNING refs

begin;

create or replace function public.create_tenant_module_for_superadmin(
  p_tenant_id bigint,
  p_module_key text,
  p_is_active boolean default true
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(trim(p_module_key));
  v_parent text;
begin
  if not public.is_superadmin() then
    return;
  end if;

  select mo.parent_module_key into v_parent
  from public.modules mo
  where mo.key = v_key;

  if v_parent is not null then
    raise exception 'Submodule keys cannot be assigned directly. Assign parent module % instead.', v_parent;
  end if;

  return query
  insert into public.tenant_modules as tm (tenant_id, module_key, is_active)
  values (p_tenant_id, v_key, coalesce(p_is_active, true))
  returning
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at;
end;
$$;

grant execute on function public.create_tenant_module_for_superadmin(bigint, text, boolean)
to authenticated;

commit;
