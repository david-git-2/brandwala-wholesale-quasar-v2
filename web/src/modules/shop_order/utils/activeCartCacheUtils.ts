import type { ActiveCartShopMeta } from '../repositories/shopCartRepository';
import type { Shop, ShopCatalogPrice } from '../types';

export function activeCartShopMetaFromShop(
  shop: Pick<Shop, 'name' | 'slug' | 'sell_currency_id' | 'default_currency_id'>,
  priceHint?: ShopCatalogPrice | null,
): ActiveCartShopMeta {
  return {
    shop_name: shop.name,
    shop_slug: shop.slug,
    shop_logo_url: null,
    currency_id: priceHint?.currency_id ?? shop.sell_currency_id ?? shop.default_currency_id ?? null,
    currency_code: priceHint?.code ?? null,
    currency_symbol: priceHint?.symbol ?? null,
  };
}
