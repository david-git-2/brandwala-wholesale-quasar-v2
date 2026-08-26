<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="520"
    class="shop-storefront-calc-price-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div class="text-subtitle1 text-weight-bold row items-center min-width-0">
          <q-icon name="ph ph-calculator" class="q-mr-xs text-primary" size="20px" />
          <span class="ellipsis">{{ $t('shop_admin.storefront_calculate_sell_price') }}</span>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <div v-if="product" class="col scroll q-pa-md column q-gutter-y-md">
        <div class="row items-start q-col-gutter-md product-hero">
          <div class="col-auto">
            <q-avatar square size="72px" class="bg-grey-2 rounded-borders">
              <img
                v-if="product.product_image_url"
                :src="product.product_image_url"
                :alt="product.product_name"
              />
              <q-icon v-else name="ph ph-package" color="grey-6" size="28px" />
            </q-avatar>
          </div>
          <div class="col min-width-0">
            <div class="row items-start no-wrap q-gutter-x-sm">
              <div class="col min-width-0">
                <div class="text-subtitle2 text-weight-bold">{{ product.product_name }}</div>
                <div v-if="product.product_code" class="text-caption text-grey-7 q-mt-xs">
                  {{ $t('shop_admin.storefront_product_code') }}: {{ product.product_code }}
                </div>
              </div>
              <q-chip
                v-if="gradeChipLabel"
                dense
                size="sm"
                class="grade-chip text-weight-bold"
                text-color="white"
                :style="gradeChipStyle"
              >
                {{ gradeChipLabel }}
              </q-chip>
            </div>
          </div>
        </div>

        <div>
          <div class="text-subtitle2 text-weight-bold q-mb-sm">
            {{ $t('shop_admin.storefront_calc_shipment_costs') }}
          </div>
          <q-markup-table flat bordered dense class="rounded-borders">
            <thead>
              <tr>
                <th class="text-left">{{ $t('shop_admin.storefront_calc_shipment_no') }}</th>
                <th class="text-left">{{ $t('shop_admin.storefront_calc_shipment_name') }}</th>
                <th class="text-right">{{ $t('shop_admin.storefront_calc_quantity') }}</th>
                <th class="text-right">{{ $t('shop_admin.storefront_calc_unit_cost') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in shipmentRows" :key="row.shipment_no">
                <td class="text-weight-medium">{{ row.shipment_no }}</td>
                <td>{{ row.shipment_name }}</td>
                <td class="text-right">{{ row.quantity }}</td>
                <td class="text-right text-weight-medium">{{ formatMoney(row.unit_cost_amount) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="bg-grey-2">
                <td colspan="2" class="text-weight-bold">{{ $t('shop_admin.storefront_calc_total_quantity') }}</td>
                <td class="text-right text-weight-bold">{{ totalQuantity }}</td>
                <td />
              </tr>
            </tfoot>
          </q-markup-table>
        </div>

        <q-input
          v-model.number="displayQuantity"
          type="number"
          min="0"
          step="1"
          outlined
          dense
          :label="$t('shop_admin.col_display_qty')"
          :hint="$t('shop_admin.storefront_calc_display_qty_hint')"
        >
          <template #prepend>
            <q-icon name="ph ph-stack" />
          </template>
        </q-input>

        <q-banner dense rounded class="bg-blue-1 text-blue-10">
          <div class="row items-center justify-between">
            <span class="text-weight-medium">{{ $t('shop_admin.storefront_avg_cost') }}</span>
            <span class="text-subtitle2 text-weight-bold">{{ formatMoney(averageCost) }}</span>
          </div>
        </q-banner>

        <div class="column q-gutter-y-md">
          <q-input
            v-model.number="sellPrice"
            type="number"
            step="0.01"
            outlined
            dense
            :label="$t('shop_admin.storefront_calc_sell_price')"
          >
            <template #prepend>
              <q-icon name="ph ph-tag" />
            </template>
          </q-input>

          <q-input
            v-if="showMinResellPrice"
            v-model.number="minResellPrice"
            type="number"
            step="0.01"
            outlined
            dense
            :label="$t('shop_admin.col_min_sell_price')"
          >
            <template #prepend>
              <q-icon name="ph ph-currency-circle-dollar" />
            </template>
          </q-input>
        </div>
      </div>

      <q-separator />

      <div class="q-pa-md bg-grey-1 row items-center justify-end q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="grey-8"
          :label="$t('shop_admin.cancel')"
          @click="isOpen = false"
        />
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="$t('shop_admin.save')"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShopCatalogItem, ShopType } from '../types';

export interface ShopStorefrontShipmentCostRow {
  shipment_no: string;
  shipment_name: string;
  quantity: number;
  unit_cost_amount: number;
}

const props = defineProps<{
  modelValue: boolean;
  product: ShopCatalogItem | null;
  shopType?: ShopType | null;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
}>();

const sellPrice = ref<number | null>(null);
const minResellPrice = ref<number | null>(null);
const displayQuantity = ref<number | null>(null);

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const showMinResellPrice = computed(() => props.shopType === 'dropship');

const gradeChipLabel = computed(() => props.product?.stock_grade?.label ?? null);

const gradeChipStyle = computed(() => {
  const color = props.product?.stock_grade?.color?.trim();
  if (!color) return undefined;
  return { backgroundColor: color };
});

const shipmentRows = computed<ShopStorefrontShipmentCostRow[]>(() => {
  if (!props.product) return [];

  const base = props.product.avg_cost?.amount ?? props.product.unit_price?.amount ?? 400;
  return [
    {
      shipment_no: 'SHP-2026-0142',
      shipment_name: 'March Electronics Batch',
      quantity: 50,
      unit_cost_amount: Number((base * 0.96).toFixed(2)),
    },
    {
      shipment_no: 'SHP-2026-0188',
      shipment_name: 'April Restock',
      quantity: 40,
      unit_cost_amount: Number((base * 1.04).toFixed(2)),
    },
    {
      shipment_no: 'SHP-2026-0210',
      shipment_name: 'Express Air Cargo',
      quantity: 30,
      unit_cost_amount: Number(base.toFixed(2)),
    },
  ];
});

const totalQuantity = computed(() =>
  shipmentRows.value.reduce((sum, row) => sum + row.quantity, 0),
);

const averageCost = computed(() => {
  if (shipmentRows.value.length === 0) return 0;
  const total = shipmentRows.value.reduce((sum, row) => sum + row.unit_cost_amount, 0);
  return Number((total / shipmentRows.value.length).toFixed(2));
});

const formatMoney = (amount: number | null | undefined) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  const symbol = props.product?.sell_price?.symbol ?? props.product?.avg_cost?.symbol ?? '৳';
  return `${symbol} ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};

const resetForm = () => {
  sellPrice.value = props.product?.sell_price?.amount ?? null;
  minResellPrice.value = props.product?.resell_minimum_price?.amount ?? null;
  displayQuantity.value =
    props.product?.display_quantity_override ??
    props.product?.real_available_units ??
    props.product?.available_units ??
    null;
};

watch(
  () => [props.modelValue, props.product?.global_stock_id] as const,
  ([open]) => {
    if (open) {
      resetForm();
    }
  },
);

watch(isOpen, (open) => {
  if (!open) {
    sellPrice.value = null;
    minResellPrice.value = null;
    displayQuantity.value = null;
  }
});
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.product-hero {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 12px;
  background: rgba(248, 250, 252, 0.8);
}

.grade-chip {
  flex-shrink: 0;
  font-size: 11px;
  min-height: 22px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.18);
}
</style>
