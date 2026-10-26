create or replace function public.normalize_vendor_fields()
returns trigger
language plpgsql
as $$
declare
  v_suffix text;
begin
  new.name = trim(new.name);
  new.code = upper(trim(new.code));
  new.market_code = upper(trim(new.market_code));

  if new.tenant_id is not null and new.code is not null then
    v_suffix := '-' || new.tenant_id::text;

    if tg_op = 'INSERT' then
      if right(new.code, length(v_suffix)) <> v_suffix then
        new.code := new.code || v_suffix;
      end if;
    elsif tg_op = 'UPDATE' then
      if old.code is distinct from new.code or old.tenant_id is distinct from new.tenant_id then
        if right(new.code, length(v_suffix)) <> v_suffix then
          new.code := new.code || v_suffix;
        end if;
      end if;
    end if;
  end if;

  if new.email is not null then
    new.email = nullif(lower(trim(new.email)), '');
  end if;

  if new.phone is not null then
    new.phone = nullif(trim(new.phone), '');
  end if;

  if new.address is not null then
    new.address = nullif(trim(new.address), '');
  end if;

  if new.website is not null then
    new.website = nullif(trim(new.website), '');
  end if;

  return new;
end;
$$;
