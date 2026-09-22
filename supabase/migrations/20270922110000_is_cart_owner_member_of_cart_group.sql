-- Cart ownership is membership of the cart's group on that shop tenant.
-- Do not require current_customer_group_id() (selected-group header).
-- Also read JWT email/sub from request.jwt.claims when auth.jwt()/auth.uid() are empty.

create or replace function public.current_user_email()
returns text
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
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
$$;

revoke all on function public.current_user_email() from public;
grant execute on function public.current_user_email() to authenticated;

create or replace function public.is_cart_owner(p_customer_group_id bigint, p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'auth'
as $$
  select exists (
    select 1
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_customer_group_id is not null
      and p_tenant_id is not null
      and cg.id = p_customer_group_id
      and cg.is_active = true
      and cg.deleted_at is null
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
      and (
        p_tenant_id = coalesce(cg.parent_tenant_id, cg.tenant_id)
        or exists (
          select 1
          from public.shop_customer_group_access scga
          inner join public.shops s on s.id = scga.shop_id
          where scga.customer_group_id = cg.id
            and scga.status = true
            and s.tenant_id = p_tenant_id
            and s.is_active = true
            and s.deleted_at is null
        )
      )
  );
$$;

revoke all on function public.is_cart_owner(bigint, bigint) from public;
grant execute on function public.is_cart_owner(bigint, bigint) to authenticated;
