<template>
  <section v-if="items.length" class="manual-catalog-lines-table-wrap">
    <div class="row items-center justify-between q-mb-sm">
      <div class="text-subtitle2 text-weight-bold">
        {{ $t('shop_admin.manual_order_lines', 'Order lines') }}
      </div>
      <q-btn
        v-if="oldOrderMode"
        flat
        dense
        no-caps
        color="primary"
        icon="ph ph-arrows-counter-clockwise"
        :label="$t('shop_admin.manual_catalog_bulk_paste', 'Bulk paste')"
        :disable="disable"
        data-test="manual-catalog-bulk-update-open"
        @click="emit('bulk-update')"
      />
    </div>
    <div class="manual-catalog-lines-scroll">
      <table class="manual-catalog-lines-table">
        <thead>
          <tr>
            <th class="text-left col-product">{{ $t('shop_admin.manual_catalog_line_product', 'Product') }}</th>
            <th class="text-right col-qty">{{ $t('shop_admin.manual_catalog_line_qty', 'Qty') }}</th>
            <th v-if="oldOrderMode" class="text-right col-purchase">
              {{ $t('shop_admin.manual_catalog_line_price_gbp', 'Price (GBP) / unit') }}
            </th>
            <th v-if="oldOrderMode" class="text-right col-sell">
              {{ $t('shop_admin.manual_catalog_sell_price', 'Sell / unit') }}
            </th>
            <th class="col-actions" />
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in items" :key="item.localId">
            <td class="col-product">
              <div class="row items-center no-wrap q-gutter-x-xs">
                <q-avatar square size="32px" class="flex-shrink-0">
                  <q-img v-if="item.image_url" :src="item.image_url" fit="contain" />
                  <q-icon v-else name="ph ph-image-square" color="grey-5" size="18px" />
                </q-avatar>
                <span class="ellipsis text-weight-medium">{{ item.name }}</span>
              </div>
            </td>
            <td class="col-qty">
              <q-input
                :model-value="item.quantity"
                dense
                outlined
                type="number"
                min="1"
                class="manual-catalog-cell-input"
                :disable="disable"
                @update:model-value="(v) => emit('update-qty', item.localId, Number(v))"
              />
            </td>
            <td v-if="oldOrderMode" class="col-purchase">
              <q-input
                :model-value="item.cost_price_amount ?? ''"
                dense
                outlined
                type="number"
                min="0"
                step="0.01"
                class="manual-catalog-cell-input"
                :disable="disable"
                @update:model-value="(v) => emit('update-cost', item.localId, Number(v))"
              />
            </td>
            <td v-if="oldOrderMode" class="col-sell">
              <q-input
                :model-value="item.sell_price_amount ?? ''"
                dense
                outlined
                type="number"
                min="0"
                step="0.01"
                class="manual-catalog-cell-input"
                :disable="disable"
                @update:model-value="(v) => emit('update-sell', item.localId, Number(v))"
              />
            </td>
            <td class="col-actions text-right">
              <q-btn
                flat
                round
                dense
                icon="ph ph-trash"
                color="grey-7"
                :disable="disable"
                @click="emit('remove', item.localId)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { ManualCatalogLineItem } from '../../composables/useManualCatalogOrder';

defineProps<{
  items: ManualCatalogLineItem[];
  oldOrderMode?: boolean;
  disable?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update-qty', localId: string, qty: number): void;
  (e: 'update-cost', localId: string, amount: number): void;
  (e: 'update-sell', localId: string, amount: number): void;
  (e: 'remove', localId: string): void;
  (e: 'bulk-update'): void;
}>();
</script>

<style scoped>
.manual-catalog-lines-table-wrap {
  padding-top: 16px;
  border-top: 1px solid var(--tf-neutral-border);
}

.manual-catalog-lines-scroll {
  overflow-x: auto;
}

.manual-catalog-lines-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.manual-catalog-lines-table th {
  font-weight: 600;
  color: var(--tf-text-muted, #6b7280);
  padding: 4px 6px;
  border-bottom: 1px solid var(--tf-neutral-border);
  white-space: nowrap;
}

.manual-catalog-lines-table td {
  padding: 6px;
  vertical-align: middle;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.manual-catalog-lines-table tbody tr:last-child td {
  border-bottom: none;
}

.col-product {
  min-width: 160px;
  max-width: 280px;
}

.col-qty {
  width: 88px;
}

.col-purchase,
.col-sell {
  width: 112px;
}

.col-actions {
  width: 40px;
}

.manual-catalog-cell-input {
  max-width: 100%;
}
</style>
