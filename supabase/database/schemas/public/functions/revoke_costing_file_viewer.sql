CREATE FUNCTION public.revoke_costing_file_viewer (
  p_costing_file_id bigint,
  p_membership_id   bigint
)
  RETURNS TABLE (
    costing_file_viewer_id bigint,
    costing_file_id        bigint,
    membership_id          bigint,
    created_at             timestamp with time zone,
    updated_at             timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  delete from public.costing_file_viewers cfv
  using public.costing_files cf
  where cf.id = p_costing_file_id
    and cf.id = cfv.costing_file_id
    and cfv.membership_id = p_membership_id
    and public.can_manage_costing_file_viewers(cf.tenant_id)
  returning
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    cfv.created_at,
    cfv.updated_at;
$function$;

GRANT ALL ON FUNCTION public.revoke_costing_file_viewer(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.revoke_costing_file_viewer(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.revoke_costing_file_viewer(bigint, bigint) TO service_role;