import type { ComposerTranslation } from 'vue-i18n';
import type { ShopOrderPlacementScope } from '../types';

export function orderPlacementCaption(
  t: ComposerTranslation,
  scope?: ShopOrderPlacementScope | string | null,
  createdByEmail?: string | null,
): string | null {
  if (scope === 'app') {
    const email = createdByEmail?.trim();
    if (email) {
      return t('shop_admin.order_placed_from_app_by', 'Placed from app · {email}', { email });
    }
    return t('shop_admin.order_placement_scope_app', 'Placed from app');
  }
  if (scope === 'shop') {
    return t('shop_admin.order_placement_scope_shop', 'Placed from shop');
  }
  return null;
}
