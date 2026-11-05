CREATE FUNCTION public.current_user_email()
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
  AS $function$
declare
  v_email text;
  v_uid uuid;
  v_claims jsonb;
begin
  begin
    v_email := nullif(trim(coalesce(auth.jwt() ->> 'email', '')), '');
  exception when others then
    v_email := null;
  end;

  if v_email is null then
    begin
      v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
      v_email := nullif(trim(coalesce(v_claims ->> 'email', '')), '');
    exception when others then
      v_claims := null;
    end;
  end if;

  if v_email is null then
    begin
      v_uid := auth.uid();
    exception when others then
      v_uid := null;
    end;
    if v_uid is null then
      begin
        v_uid := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      exception when others then
        v_uid := null;
      end;
    end if;
    if v_uid is null then
      begin
        if v_claims is null then
          v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
        end if;
        v_uid := nullif(v_claims ->> 'sub', '')::uuid;
      exception when others then
        v_uid := null;
      end;
    end if;
    if v_uid is not null then
      select u.email into v_email from auth.users u where u.id = v_uid;
    end if;
  end if;

  return lower(trim(v_email));
end;
$function$;

GRANT ALL ON FUNCTION public.current_user_email() TO anon;

GRANT ALL ON FUNCTION public.current_user_email() TO authenticated;

GRANT ALL ON FUNCTION public.current_user_email() TO service_role;