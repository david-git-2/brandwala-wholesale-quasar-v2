<template>
  <q-card flat bordered class="floating-surface">
    <q-card-section class="q-px-md q-py-sm row items-center justify-between">
      <div class="text-subtitle2 text-weight-bold">
        {{ $t('shop.items') }} ({{ itemCount }})
      </div>
      <div v-if="currentShopCartInfo" class="bw-type-meta bw-text-muted">
        Store:
        <span class="text-weight-bold text-primary">{{ currentShopCartInfo.shop_name }}</span>
      </div>
    </q-card-section>

    <q-separator />

    <q-list separator>
      <q-item v-for="item in items" :key="item.id" class="q-py-md items-row">
        <q-item-section avatar class="item-img-section">
          <q-avatar size="64px" rounded color="grey-3" text-color="grey-9" class="shop-product-thumb">
            <q-img v-if="item.image_url" :src="item.image_url" fit="contain" />
            <q-icon v-else name="ph ph-image" class="bw-text-muted" size="32px" />
          </q-avatar>
        </q-item-section>

        <q-item-section class="item-details-section">
          <div class="text-subtitle2 text-weight-bold item-name">
            {{ item.name }}
          </div>
          <div v-if="cart?.shop_type === 'dropship'" class="q-mt-sm cart-price-input">
            <div class="column q-gutter-y-xs">
              <q-input
                :model-value="getItemPrice(item)"
                type="number"
                :label="$t('shop.your_selling_price')"
                outlined
                dense
                :prefix="sellPriceSymbol(item)"
                :min="getCartItemMinSellAmount(item) || 0"
                :disable="!permissions?.can_set_dropship_price"
                @update:model-value="(val: string | number | null) => $emit('update-price-local', item, val)"
              />
              <div
                v-if="item.resell_minimum_price?.amount != null"
                class="bw-type-meta row items-center q-gutter-x-xs"
                :class="isItemPriceBelowFloor(item) ? 'text-negative' : 'bw-text-muted'"
              >
                <q-icon
                  :name="isItemPriceBelowFloor(item) ? 'ph ph-warning' : 'ph ph-info'"
                  size="14px"
                  :color="isItemPriceBelowFloor(item) ? 'negative' : undefined"
                  :class="isItemPriceBelowFloor(item) ? undefined : 'bw-text-muted'"
                />
                <span>{{ $t('customer_dashboard.min_sell', { price: formatMinSellPrice(item) }) }}</span>
              </div>
              <q-btn
                v-if="editedPrices[item.id] !== undefined && editedPrices[item.id] !== getItemSellAmount(item)"
                color="primary"
                size="xs"
                unelevated
                no-caps
                class="square-btn q-px-sm self-start q-mt-xs"
                :label="$t('shop.save_price')"
                :loading="isSaving"
                :disable="isItemPriceBelowFloor(item)"
                @click="$emit('save-item-price', item)"
              >
                <q-tooltip v-if="isItemPriceBelowFloor(item)">
                  {{ $t('shop.cart_price_below_floor') }}
                </q-tooltip>
              </q-btn>
            </div>
          </div>
        </q-item-section>

        <q-item-section class="col-auto item-qty-section">
          <div class="column items-center q-gutter-y-xs">
            <div class="row items-center no-wrap quantity-controls">
              <q-btn
                flat
                round
                dense
                size="sm"
                icon="ph ph-minus"
                :disabled="isSaving || getItemQty(item) <= getItemMinQty(item)"
                @click="$emit('adjust-qty-local', item, -getItemMinQty(item))"
              />
              <div class="quantity-value text-weight-bold text-center bw-tabular">
                {{ getItemQty(item) }}
              </div>
              <q-btn
                flat
                round
                dense
                size="sm"
                icon="ph ph-plus"
                :disabled="isSaving"
                @click="$emit('adjust-qty-local', item, getItemMinQty(item))"
              />
            </div>
            <q-btn
              v-if="editedQuantities[item.id] !== undefined && editedQuantities[item.id] !== item.quantity"
              color="primary"
              size="xs"
              unelevated
              no-caps
              class="square-btn q-px-sm"
              :label="$t('shop.save_qty')"
              :loading="isSaving"
              @click="$emit('save-item-qty', item)"
            />
          </div>
        </q-item-section>

        <q-item-section
          v-if="cart?.shop_type === 'dropship' ? (canSeeBuyPrice || canSeeSellPrice) : canSeeLinePrices"
          side
          class="text-right subtotal-section item-price-section"
        >
          <template v-if="cart?.shop_type === 'dropship'">
            <div v-if="canSeeBuyPrice" class="q-mb-xs">
              <span class="bw-type-meta bw-text-muted block q-mb-xs">{{ $t('shop.your_cost') }}</span>
              <div class="text-subtitle2 text-weight-bold bw-tabular">
                {{ formatBuyerItemTotal(item) }}
              </div>
              <div class="bw-type-meta bw-text-muted">
                {{ formatBuyerUnitPrice(item) }} {{ $t('shop.each') }}
              </div>
            </div>
            <div v-if="canSeeSellPrice && item.resell_minimum_price?.amount != null" class="q-mb-xs">
              <span class="bw-type-meta bw-text-muted block q-mb-xs">Min Sell Price</span>
              <div class="bw-type-meta text-weight-medium">
                {{ formatMinSellPrice(item) }} {{ $t('shop.each') }}
              </div>
            </div>
            <div v-if="canSeeSellPrice" class="q-mt-xs">
              <span class="bw-type-meta bw-text-muted block q-mb-xs">{{ $t('shop.recipient_pay') }}</span>
              <div class="text-subtitle2 text-weight-bold text-primary bw-tabular">
                {{ formatItemTotal(item) }}
              </div>
              <div class="bw-type-meta bw-text-muted">
                {{ formatUnitPrice(item) }} {{ $t('shop.each') }}
              </div>
            </div>
          </template>
          <template v-else-if="canSeeLinePrices">
            <div class="text-subtitle2 text-weight-bold bw-tabular">
              {{ formatItemTotal(item) }}
            </div>
            <div class="bw-type-meta bw-text-muted">
              {{ formatUnitPrice(item) }} {{ $t('shop.each') }}
            </div>
          </template>
        </q-item-section>

        <q-item-section side class="item-delete-section">
          <q-btn
            flat
            round
            dense
            icon="ph ph-trash"
            color="negative"
            :disabled="isSaving"
            @click="$emit('remove-item', item)"
          >
            <q-tooltip>{{ $t('shop.remove_item') }}</q-tooltip>
          </q-btn>
        </q-item-section>
      </q-item>
    </q-list>
  </q-card>
</template>

<script setup lang="ts">
import type { ActiveCartItem, ShopCartItem } from '../repositories/shopCartRepository';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';
import {
  cartPriceSymbol,
  formatCartPriceAmount,
  getCartItemMinSellAmount,
  getCartItemSellAmount,
} from '../utils/cartPriceUtils';

const props = defineProps<{
  items: ShopCartItem[];
  itemCount: number;
  currentShopCartInfo: ActiveCartItem | null;
  cart: any;
  canSeeBuyPrice: boolean;
  canSeeSellPrice: boolean;
  canSeeLinePrices: boolean;
  currencySymbol: string;
  permissions: any;
  editedQuantities: Record<number, number>;
  editedPrices: Record<number, number>;
  isSaving: boolean;
  getItemQty: (item: ShopCartItem) => number;
  getItemPrice: (item: ShopCartItem) => number;
  formatUnitPrice: (item: ShopCartItem) => string;
  formatItemTotal: (item: ShopCartItem) => string;
  formatBuyerUnitPrice: (item: ShopCartItem) => string;
  formatBuyerItemTotal: (item: ShopCartItem) => string;
  isItemPriceBelowFloor: (item: ShopCartItem) => boolean;
}>();

defineEmits<{
  (e: 'update-price-local', item: ShopCartItem, val: string | number | null): void;
  (e: 'save-item-price', item: ShopCartItem): void;
  (e: 'adjust-qty-local', item: ShopCartItem, delta: number): void;
  (e: 'save-item-qty', item: ShopCartItem): void;
  (e: 'remove-item', item: ShopCartItem): void;
}>();

const sellPriceSymbol = (item: ShopCartItem) =>
  cartPriceSymbol(item.sell_price ?? item.unit_price);

const getItemSellAmount = (item: ShopCartItem) => getCartItemSellAmount(item);

const formatMinSellPrice = (item: ShopCartItem) =>
  formatCartPriceAmount(getCartItemMinSellAmount(item), item.resell_minimum_price);

const getItemMinQty = (item: any) =>
  resolveShopCartItemMoq(item, props.cart?.shop_type);
</script>

<style scoped>
.cart-price-input {
  max-width: 210px;
}

.items-row {
  transition: background-color 0.2s ease;
}

.items-row:hover {
  background: color-mix(in srgb, var(--bw-theme-surface) 92%, var(--bw-theme-primary-soft) 8%);
}

.item-name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.quantity-controls {
  border: 1px solid var(--bw-theme-border);
  border-radius: var(--bw-radius-sm);
  padding: 2px 6px;
  background: var(--bw-theme-surface);
}

.quantity-value {
  min-width: 32px;
  font-size: 14px;
}

.subtotal-section {
  min-width: 110px;
}

@media (max-width: 599px) {
  .items-row {
    display: grid !important;
    grid-template-columns: 64px 1fr;
    grid-template-areas:
      'img details'
      'qty price';
    gap: 12px;
    padding: 12px 8px !important;
    position: relative;
  }

  .item-img-section {
    grid-area: img;
  }

  .item-details-section {
    grid-area: details;
    padding-right: 36px;
  }

  .item-qty-section {
    grid-area: qty;
    justify-self: start;
    min-width: unset;
  }

  .item-price-section {
    grid-area: price;
    justify-self: end;
    min-width: unset;
    text-align: right;
  }

  .item-delete-section {
    position: absolute;
    top: 8px;
    right: 4px;
    margin: 0;
  }
}
</style>
