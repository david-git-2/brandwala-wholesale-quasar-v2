CREATE FUNCTION public.normalize_costing_file_item_fields()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  new.website_url := trim(coalesce(new.website_url, ''));

  if new.image_url is not null then
    new.image_url := nullif(trim(new.image_url), '');
  end if;

  if new.name is not null then
    new.name := nullif(trim(new.name), '');
  end if;

  if new.item_type is not null then
    new.item_type := nullif(trim(new.item_type), '');
  end if;

  if new.size is not null then
    new.size := nullif(trim(new.size), '');
  end if;

  if new.color is not null then
    new.color := nullif(trim(new.color), '');
  end if;

  if new.extra_information_1 is not null then
    new.extra_information_1 := nullif(trim(new.extra_information_1), '');
  end if;

  if new.extra_information_2 is not null then
    new.extra_information_2 := nullif(trim(new.extra_information_2), '');
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_costing_file_item_fields() TO anon;

GRANT ALL ON FUNCTION public.normalize_costing_file_item_fields() TO authenticated;

GRANT ALL ON FUNCTION public.normalize_costing_file_item_fields() TO service_role;