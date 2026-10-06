-- Deferred from stubbed 20260930280000_fulfill_invoice_sync.sql (build_preorder_demand_invoice_items).
-- Must run before 20271006120000_bills_pays_backend_pack (references build_preorder_demand_invoice_items).

CREATE OR REPLACE FUNCTION "public"."build_preorder_demand_invoice_items"("p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_items jsonb := '[]'::jsonb;
  v_pick_elem jsonb;
  v_pd record;
  v_sell_price numeric(12,2);
  v_global_stock_id bigint;
  v_qty integer;
begin
  if p_document_id is null then
    return '[]'::jsonb;
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select
        pd.stock_picks,
        coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  elsif v_doc_type = 'pbc_costing_file' then
    for v_pd in
      select
        pd.stock_picks,
        coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  end if;

  return coalesce(v_items, '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."build_preorder_demand_invoice_items"("p_document_type" "text", "p_document_id" bigint) OWNER TO "postgres";
