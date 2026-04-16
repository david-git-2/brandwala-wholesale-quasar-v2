<template>
  <div>
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="compactColumns"
      row-key="id"
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      class="bg-white"
    >
      <template #body-cell-sl="props">
        <q-td :props="props">
          {{ props.row.sl }}
        </q-td>
      </template>

      <template #body-cell-image_url="props">
        <q-td :props="props">
          <div class="order-table-image-box">
            <SmartImage
              :src="props.row.image_url"
              alt="product"
              imgClass="order-table-image"
              fallbackClass="order-table-image-fallback"
            />
          </div>
        </q-td>
      </template>

      <template #body-cell-product_details="props">
        <q-td :props="props" class="col-name">
          <div class="whitespace-normal order-item-name-cell">
            {{ props.row.name }}
          </div>
          <div class="text-caption text-grey-7">
            Barcode: {{ props.row.barcode ?? '-' }}
          </div>
          <div class="text-caption text-grey-7">
            Product Code: {{ props.row.product_code ?? '-' }}
          </div>
        </q-td>
      </template>

      <template #body-cell-ordered_quantity="props">
        <q-td :props="props">
          {{ props.row.ordered_quantity ?? '-' }}
        </q-td>
      </template>

      <template #body-cell-cost_summary="props">
        <q-td :props="props">
          <div>Cost: {{ props.row.cost_bdt ?? '-' }}</div>
          <div>Line Total: {{ props.row.line_total_cost_bdt ?? '-' }}</div>
        </q-td>
      </template>

      <template #body-cell-first_offer_summary="props">
        <q-td :props="props">
          <div>Offer: {{ props.row.first_offer_bdt ?? props.row.seller_first_offer_bdt ?? '-' }}</div>
          <div>Line Total: {{ props.row.seller_first_offer_bdt_total ?? '-' }}</div>
          <div>Profit %: {{ formatPercent(props.row.seler_first_offer_profit_pc_perc) }}</div>
        </q-td>
      </template>

      <template #body-cell-customer_offer_summary="props">
        <q-td :props="props">
          <div>Offer: {{ props.row.customer_offer_bdt ?? '-' }}</div>
          <div>Line Total: {{ props.row.customer_offer_bdt_total ?? '-' }}</div>
          <div>Profit %: {{ formatPercent(props.row.customer_offer_profit_pc_perc) }}</div>
        </q-td>
      </template>

      <template #body-cell-final_offer_summary="props">
        <q-td :props="props">
          <div>Offer: {{ props.row.final_offer_bdt ?? '-' }}</div>
          <div>Line Total: {{ props.row.final_offer_bdt_total ?? '-' }}</div>
          <div>Profit %: {{ formatPercent(props.row.final_offer_profit_pc_perc) }}</div>
        </q-td>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-6">
          No items found
        </div>
      </template>
    </q-table>
  </div>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import {
  useOrderItemTableRows,
  type OrderItem,
} from '../composables/useOrderItemTableRows'

type OrderStatus =
  | 'customer_submit'
  | 'priced'
  | 'negotiate'
  | 'final_offered'
  | 'ordered'
  | 'placed'

const props = withDefaults(
  defineProps<{
    items?: OrderItem[]
    status?: OrderStatus
    conversionRate?: number
    cargoRate?: number
    profitRate?: number
  }>(),
  {
    items: () => [],
    status: 'customer_submit',
    conversionRate: 0,
    cargoRate: 0,
    profitRate: 0,
  }
)

const { tableRows } = useOrderItemTableRows({
  items: toRef(props, 'items'),
  conversionRate: toRef(props, 'conversionRate'),
  cargoRate: toRef(props, 'cargoRate'),
  profitRate: toRef(props, 'profitRate'),
})

const formatPercent = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const compactColumns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center',
    sortable: false,
    headerStyle: 'width: 50px; max-width: 50px;',
  },
  {
    name: 'image_url',
    label: 'Image',
    field: 'image_url',
    align: 'center',
    sortable: false,
  },
  {
    name: 'product_details',
    label: 'Product Details',
    field: 'name',
    align: 'center',
    style: 'min-width: 320px; width: 320px; max-width: 320px; text-align: left;',
    headerStyle: 'min-width: 320px; width: 320px; max-width: 320px;',
    classes: 'col-name',
    headerClasses: 'col-name-wrap',
  },
  {
    name: 'ordered_quantity',
    label: 'Quantity',
    field: 'ordered_quantity',
    align: 'center',
    style: 'background-color:#E7E7E7;font-weight:bold',
    headerStyle: 'background-color:#E7E7E7;',
    headerClasses: 'text-center'
  },
  {
    name: 'cost_summary',
    label: 'Cost / Line Total',
    field: 'cost_bdt',
    align: 'center',
    style: 'background-color:#fdffb6;font-weight:bold',
    headerStyle: 'background-color:#fdffb6;',
  },
  {
    name: 'first_offer_summary',
    label: 'First Offer / Line Total / Profit',
    field: 'seller_first_offer_bdt',
    align: 'center',
    style: 'background-color:#9bf6ff;font-weight:bold',
    headerStyle: 'background-color:#9bf6ff;',
  },
  {
    name: 'customer_offer_summary',
    label: 'Customer Offer / Line Total / Profit',
    field: 'customer_offer_bdt',
    align: 'center',
    style: 'background-color:#ffd6a5;font-weight:bold',
    headerStyle: 'background-color:#ffd6a5;',
  },
  {
    name: 'final_offer_summary',
    label: 'Final Offer / Line Total / Profit',
    field: 'final_offer_bdt',
    align: 'center',
    style: 'background-color:#bdb2ff;font-weight:bold',
    headerStyle: 'background-color:#bdb2ff;',
  },
]
</script>

<style scoped>
:deep(.q-table) {
  min-width: 1600px;
  table-layout: fixed;
}

:deep(.q-table thead th) {
  text-align: center !important;
  vertical-align: middle;
  height: auto;
  padding-top: 4px;
  padding-bottom: 4px;
  font-size: 12px;
  white-space: normal !important;
  overflow: hidden;
}

:deep(.q-table thead th .q-table__th-content) {
  display: flex !important;
  flex-wrap: wrap;
  justify-content: center;
  align-items: center;
  column-gap: 4px;
  width: 100%;
  white-space: normal !important;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.25;
  text-align: center;
  overflow: hidden;
}

:deep(.q-table th),
:deep(.q-table td) {
  vertical-align: middle;
  padding: 4px 6px;
  font-size: 12px;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

:deep(.q-table th:nth-child(2)),
:deep(.q-table td:nth-child(2)) {
  min-width: 1in !important;
  width: 1in !important;
  max-width: 1in !important;
  padding-right: 18px !important;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  padding-left: 18px !important;
}

.order-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.2;
  font-size: 12px;
}

.order-table-image-box {
  width: 48px;
  height: 48px;
  min-width: 48px;
  min-height: 48px;
  border-radius: 6px;
  overflow: hidden;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}

.order-table-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.order-table-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  font-size: 12px;
}

.col-name {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

.col-name-wrap {
  white-space: normal !important;
  word-break: break-word;
  line-height: 1.2;
}
</style>
