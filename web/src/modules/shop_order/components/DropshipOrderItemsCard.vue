<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrderItem } from '../types';

const props = defineProps<{
  orderItems: ShopOrderItem[];
  formatBdt: (amount: number) => string;
}>();

type ItemPricing = {
  cost: number;
  sell: number;
  resell: number;
};

const resolveItemPricing = (item: ShopOrderItem): ItemPricing => ({
  cost: item.cost_price_amount ?? item.unit_list_price_amount ?? 0,
  sell: item.unit_sell_price_amount ?? 0,
  resell: item.customer_sell_price_amount ?? item.final_price_amount ?? 0,
});

const totals = computed(() =>
  props.orderItems.reduce(
    (acc, item) => {
      const pricing = resolveItemPricing(item);
      acc.qty += item.quantity;
      acc.cost += pricing.cost * item.quantity;
      acc.sell += pricing.sell * item.quantity;
      acc.resell += pricing.resell * item.quantity;
      return acc;
    },
    { qty: 0, cost: 0, sell: 0, resell: 0 },
  ),
);

const displayCode = (item: ShopOrderItem) => item.sku?.trim() || '—';
const displayBarcode = (item: ShopOrderItem) => item.barcode?.trim() || '—';
const displayStockId = (item: ShopOrderItem) =>
  item.global_stock_id != null ? String(item.global_stock_id) : '—';

const priceBlocksFor = (item: ShopOrderItem) => {
  const pricing = resolveItemPricing(item);
  return [
    { key: 'cost', label: 'Cost', unit: pricing.cost, line: pricing.cost * item.quantity, accent: false },
    { key: 'sell', label: 'Sell', unit: pricing.sell, line: pricing.sell * item.quantity, accent: false },
    { key: 'resell', label: 'Resell', unit: pricing.resell, line: pricing.resell * item.quantity, accent: true },
  ];
};
</script>

<template>
  <q-card flat bordered class="form-card">
    <q-card-section class="border-bottom row items-center justify-between q-py-sm q-px-md">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-shopping-bag" size="16px" class="q-mr-xs text-primary" />
        Ordered Items
      </div>
      <q-chip dense color="grey-2" text-color="grey-9" size="sm" class="q-ma-none">
        {{ orderItems.length }} {{ orderItems.length === 1 ? 'item' : 'items' }}
      </q-chip>
    </q-card-section>

    <q-card-section class="q-pa-sm">
      <div v-if="orderItems.length === 0" class="text-center text-grey-6 q-pa-sm text-caption">
        No items in this order.
      </div>

      <div v-else class="column q-gutter-y-xs">
        <q-card
          v-for="item in orderItems"
          :key="item.id"
          flat
          bordered
          class="dropship-order-item"
        >
          <q-card-section class="q-pa-sm">
            <div class="row no-wrap q-col-gutter-sm">
              <div class="col-auto">
                <div class="dropship-order-item__image bg-grey-2">
                  <q-img
                    v-if="item.image_url"
                    :src="item.image_url"
                    :alt="item.name"
                    fit="contain"
                    class="dropship-order-item__image-img"
                  />
                  <q-icon v-else name="ph ph-package" size="16px" color="grey-5" />
                </div>
              </div>

              <div class="col min-width-0">
                <div class="row items-start justify-between no-wrap q-col-gutter-xs">
                  <div class="col min-width-0">
                    <div class="text-caption text-weight-bold text-grey-9 dropship-order-item__name">
                      {{ item.name }}
                    </div>
                    <div class="dropship-order-item__meta text-caption text-grey-7 q-mt-xs">
                      <span class="dropship-order-item__meta-item">
                        <span class="text-grey-6">Code</span>
                        <span class="font-mono text-grey-9">{{ displayCode(item) }}</span>
                      </span>
                      <span class="dropship-order-item__sep">·</span>
                      <span class="dropship-order-item__meta-item">
                        <span class="text-grey-6">Barcode</span>
                        <span class="font-mono text-grey-9">{{ displayBarcode(item) }}</span>
                      </span>
                      <span class="dropship-order-item__sep">·</span>
                      <span class="dropship-order-item__meta-item">
                        <span class="text-grey-6">Stock</span>
                        <span class="font-mono text-grey-9">{{ displayStockId(item) }}</span>
                      </span>
                    </div>
                  </div>

                  <q-chip
                    dense
                    square
                    color="grey-2"
                    text-color="grey-9"
                    class="q-ma-none text-caption text-weight-bold"
                  >
                    ×{{ item.quantity }}
                  </q-chip>
                </div>

                <div class="row q-col-gutter-xs q-mt-xs">
                  <div
                    v-for="priceBlock in priceBlocksFor(item)"
                    :key="priceBlock.key"
                    class="col-4"
                  >
                    <div
                      class="dropship-order-item__price-card"
                      :class="{ 'dropship-order-item__price-card--accent': priceBlock.accent }"
                    >
                      <div class="dropship-order-item__price-label">{{ priceBlock.label }}</div>
                      <div
                        class="dropship-order-item__price-value"
                        :class="{ 'text-primary': priceBlock.accent }"
                      >
                        {{ formatBdt(priceBlock.unit) }}
                      </div>
                      <div class="dropship-order-item__price-sub">
                        {{ formatBdt(priceBlock.line) }}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <div class="dropship-order-item__totals row items-center q-gutter-x-md q-px-xs q-py-xs">
          <div class="text-caption text-grey-6 text-weight-medium">Totals</div>
          <div class="text-caption">
            <span class="text-grey-6">Qty</span>
            <span class="text-weight-bold text-grey-9 q-ml-xs">{{ totals.qty }}</span>
          </div>
          <div class="text-caption">
            <span class="text-grey-6">Cost</span>
            <span class="text-weight-bold text-grey-9 q-ml-xs">{{ formatBdt(totals.cost) }}</span>
          </div>
          <div class="text-caption">
            <span class="text-grey-6">Sell</span>
            <span class="text-weight-bold text-grey-9 q-ml-xs">{{ formatBdt(totals.sell) }}</span>
          </div>
          <div class="text-caption">
            <span class="text-grey-6">Resell</span>
            <span class="text-weight-bold text-primary q-ml-xs">{{ formatBdt(totals.resell) }}</span>
          </div>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<style scoped>
.dropship-order-item {
  border-radius: 8px;
  background: var(--bw-theme-surface, #ffffff);
  border-color: rgba(34, 56, 101, 0.1);
}

.dropship-order-item__image {
  width: 44px;
  height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 6px;
  overflow: hidden;
}

.dropship-order-item__image-img {
  width: 100%;
  height: 100%;
}

.dropship-order-item__name {
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.25;
}

.dropship-order-item__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.15rem 0.35rem;
  line-height: 1.2;
}

.dropship-order-item__meta-item {
  display: inline-flex;
  align-items: baseline;
  gap: 0.2rem;
  overflow-wrap: anywhere;
}

.dropship-order-item__sep {
  color: rgba(34, 56, 101, 0.25);
}

.dropship-order-item__price-card {
  padding: 0.35rem 0.45rem;
  border-radius: 6px;
  background: rgba(34, 56, 101, 0.04);
  border: 1px solid rgba(34, 56, 101, 0.07);
  min-height: 100%;
}

.dropship-order-item__price-card--accent {
  background: rgba(25, 118, 210, 0.06);
  border-color: rgba(25, 118, 210, 0.12);
}

.dropship-order-item__price-label {
  font-size: 0.62rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #736a61);
  line-height: 1.1;
}

.dropship-order-item__price-value {
  margin-top: 0.05rem;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1.2;
  color: var(--bw-theme-ink, #171412);
}

.dropship-order-item__price-sub {
  margin-top: 0.05rem;
  font-size: 0.65rem;
  line-height: 1.1;
  color: var(--bw-theme-muted, #736a61);
}

.dropship-order-item__totals {
  flex-wrap: wrap;
  border-top: 1px solid rgba(34, 56, 101, 0.08);
}

.min-width-0 {
  min-width: 0;
}
</style>
