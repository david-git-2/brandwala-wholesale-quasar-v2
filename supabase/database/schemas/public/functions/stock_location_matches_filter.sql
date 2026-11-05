CREATE FUNCTION public.stock_location_matches_filter (
  p_location_id bigint,
  p_filter_id   bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  select
    p_filter_id is null
    or p_location_id is null
    or p_location_id = p_filter_id
    or exists (
      with recursive descendants as (
        select id
        from public.stock_locations
        where id = p_filter_id
        union all
        select sl.id
        from public.stock_locations sl
        inner join descendants d on sl.parent_location_id = d.id
      )
      select 1
      from descendants
      where id = p_location_id
    );
$function$;

GRANT ALL ON FUNCTION public.stock_location_matches_filter(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.stock_location_matches_filter(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.stock_location_matches_filter(bigint, bigint) TO service_role;