-- delivered_quantity = sum of initial warehouse pick qty (not close-split allocation qty).

CREATE OR REPLACE FUNCTION public.sum_preorder_stock_picks(p_stock_picks jsonb) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  select coalesce(
    sum(
      greatest(
        coalesce(
          nullif(elem->>'initial_quantity', '')::integer,
          nullif(elem->>'quantity', '')::integer,
          0
        ),
        0
      )
    ),
    0
  )::integer
  from jsonb_array_elements(coalesce(p_stock_picks, '[]'::jsonb)) elem
  where nullif(elem->>'global_stock_id', '') is not null
    and coalesce((elem->>'close_split')::boolean, false) = false;
$$;
