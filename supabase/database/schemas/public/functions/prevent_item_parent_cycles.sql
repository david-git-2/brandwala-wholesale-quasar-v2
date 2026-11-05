CREATE FUNCTION public.prevent_item_parent_cycles()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_cycle_exists boolean;
begin
  if new.parent_id is null then
    return new;
  end if;

  if new.id is not null and new.parent_id = new.id then
    raise exception 'An item cannot be its own parent.'
      using errcode = '23514';
  end if;

  with recursive descendants as (
    select i.id, i.parent_id
    from public.items i
    where i.id = new.id
    union all
    select child.id, child.parent_id
    from public.items child
    join descendants d on child.parent_id = d.id
  )
  select exists (
    select 1
    from descendants
    where id = new.parent_id
  ) into v_cycle_exists;

  if v_cycle_exists then
    raise exception 'Invalid parent relationship: a parent cannot be assigned to one of its descendants.'
      using errcode = '23514';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.prevent_item_parent_cycles() TO anon;

GRANT ALL ON FUNCTION public.prevent_item_parent_cycles() TO authenticated;

GRANT ALL ON FUNCTION public.prevent_item_parent_cycles() TO service_role;