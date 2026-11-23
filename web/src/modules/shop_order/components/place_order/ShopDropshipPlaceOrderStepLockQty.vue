<template>
  <div class="column q-gutter-y-sm">
    <ShopDropshipCartItemCard
      v-for="item in items"
      :key="item.id"
      :name="item.name"
      :image-url="item.image_url"
      :quantity="getItemQty(item)"
      :price="getPurchaseUnitAmount(item)"
      :currency-symbol="currencySymbol"
      :min-qty="item.minimum_quantity"
      :disable-qty="isCartBusy"
      :show-save-qty="hasUnsavedQty(item)"
      :is-saving="isUpdatingQty"
      :disable-remove="isCartBusy"
      :is-removing="removingItemId === item.id"
      @update:quantity="(qty) => adjustItemQtyLocal(item.id, qty, item.quantity)"
      @save-quantity="() => saveItemQty(item.id)"
      @remove="() => removeItem(item)"
    />
  </div>
</template>

<script setup lang="ts">
import ShopDropshipCartItemCard from '../ShopDropshipCartItemCard.vue';
import type { DropshipCartItem } from '../../repositories/dropshipCartRepository';

defineProps<{
  items: DropshipCartItem[];
  currencySymbol: string;
  getItemQty: (item: DropshipCartItem) => number;
  hasUnsavedQty: (item: DropshipCartItem) => boolean;
  getPurchaseUnitAmount: (item: DropshipCartItem) => number;
  isCartBusy: boolean;
  isUpdatingQty: boolean;
  removingItemId: number | null;
  adjustItemQtyLocal: (itemId: number, quantity: number, savedQuantity: number) => void;
  saveItemQty: (itemId: number) => Promise<void>;
  removeItem: (item: DropshipCartItem) => Promise<void>;
}>();
</script>