-- Backfill vendor catalog access: sell-price grant should also allow catalog list price.
-- Align list/search/dashboard permission helpers with resolve_shop_can_see_buy_price.

begin;

update public.shop_customer_group_access sca
set can_see_buy_price = true,
    updated_at = now()
from public.shops s
where sca.shop_id = s.id
  and s.shop_type = 'vendor_catalog'
  and sca.status = true
  and coalesce(sca.can_browse, false) = true
  and coalesce(sca.can_see_buy_price, false) = false
  and coalesce(sca.can_see_sell_price, false) = true;

commit;
