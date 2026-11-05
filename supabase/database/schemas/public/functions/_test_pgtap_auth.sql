CREATE FUNCTION public._test_pgtap_auth()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
  AS $function$
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    '{"email":"pgtap+money@kernel.test","sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
  );
END;
$function$;

GRANT ALL ON FUNCTION public._test_pgtap_auth() TO anon;

GRANT ALL ON FUNCTION public._test_pgtap_auth() TO authenticated;

GRANT ALL ON FUNCTION public._test_pgtap_auth() TO service_role;