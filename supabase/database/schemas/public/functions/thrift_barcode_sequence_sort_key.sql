CREATE FUNCTION public.thrift_barcode_sequence_sort_key (
  p_barcode_id text
)
  RETURNS TABLE (
    sort_prefix text,
    sort_year   text,
    sort_seq    integer
  )
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 1)
      else coalesce(p_barcode_id, '')
    end as sort_prefix,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      else ''
    end as sort_year,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 4)::integer
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)::integer
      else 0
    end as sort_seq;
$function$;

GRANT ALL ON FUNCTION public.thrift_barcode_sequence_sort_key(text) TO anon;

GRANT ALL ON FUNCTION public.thrift_barcode_sequence_sort_key(text) TO authenticated;

GRANT ALL ON FUNCTION public.thrift_barcode_sequence_sort_key(text) TO service_role;