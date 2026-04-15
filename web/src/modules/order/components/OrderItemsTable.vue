<template>
  <q-table
    flat
    bordered
    :rows="tableRows"
    :columns="customer_offer_columns"
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
        <SmartImage
          :src="props.row.image_url"
          alt="product"
          imgClass="w-12 h-12 object-cover rounded"
          fallbackClass="w-12 h-12 flex items-center justify-center bg-gray-200 text-xs"
        />
      </q-td>
    </template>

    <template #body-cell-name="props">
      <q-td :props="props">
        <div class="whitespace-normal" style="min-width: 260px">
          {{ props.row.name }}
        </div>
      </q-td>
    </template>

    <template #body-cell-id="props">
      <q-td :props="props">
        {{ props.row.id }}
      </q-td>
    </template>

    <template #body-cell-order_id="props">
      <q-td :props="props">
        {{ props.row.order_id }}
      </q-td>
    </template>

    <template #body-cell-product_id="props">
      <q-td :props="props">
        {{ props.row.product_id ?? '-' }}
      </q-td>
    </template>

    <template #no-data>
      <div class="full-width row flex-center q-pa-md text-grey-6">
        No items found
      </div>
    </template>
  </q-table>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import {
  useOrderItemTableRows,
  type OrderItem,
} from '../composables/useOrderItemTableRows'

type OrderStatus = 'customer_submit' | 'priced' | 'negotiate' | 'ordered' | 'placed'

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
  }
)

const { tableRows } = useOrderItemTableRows({
  items: toRef(props, 'items'),
  conversionRate: toRef(props, 'conversionRate'),
  cargoRate: toRef(props, 'cargoRate'),
  profitRate: toRef(props, 'profitRate'),
})

const customer_offer_columns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'left',
    sortable: false,
  },

  {
    name: 'image_url',
    label: 'Image',
    field: 'image_url',
    align: 'left',
    sortable: false,
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'ordered_quantity',
    label: 'Ordered Qty',
    field: 'ordered_quantity',
    align: 'left',
    sortable: true,
  },
  {
    name: 'product_weight',
    label: 'Product Weight',
    field: 'product_weight',
    align: 'left',
    sortable: true,
  },
  {
    name: 'package_weight',
    label: 'Package Weight',
    field: 'package_weight',
    align: 'left',
    sortable: true,
  },
  {
    name: 'total_weight',
    label: 'Total Weight',
    field: 'total_weight',
    align: 'left',
    sortable: true,
  },
  {
    name: 'price_gbp',
    label: 'Price (GBP)',
    field: 'price_gbp',
    align: 'left',
    sortable: true,
  },
  {
    name: 'line_total_purchese_cost_gbp',
    label: 'Line Total Purchase Cost (GBP)',
    field: 'line_total_purchese_cost_gbp',
    align: 'left',
    sortable: true,
  },
  {
    name: 'cargo_rate',
    label: 'Cargo Rate / KG',
    field: 'cargo_rate',
    align: 'left',
    sortable: true,
  },
  {
    name: 'unit_line_cost_gbp',
    label: 'Unit Line Cost (GBP/Pc)',
    field: 'unit_line_cost_gbp',
    align: 'left',
    sortable: true,
  },
  {
    name: 'cost_bdt',
    label: 'Cost (BDT/PC)',
    field: 'cost_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'line_total_cost_bdt',
    label: 'Line Total Cost (BDT)',
    field: 'line_total_cost_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'seller_first_offer_bdt',
    label: 'First Offer (BDT)',
    field: 'seller_first_offer_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'seller_first_offer_bdt_total',
    label: 'First Offer Total (BDT)',
    field: 'seller_first_offer_bdt_total',
    align: 'left',
    sortable: true,
  },
  {
    name: 'seller_first_offer_profit_pc',
    label: 'First Offer Profit /Pc',
    field: 'seller_first_offer_profit_pc',
    align: 'left',
    sortable: true,
  },
  {
    name: 'seler_first_offer_profit_pc_perc',
    label: 'First Offer Profit %',
    field: 'seler_first_offer_profit_pc_perc',
    align: 'left',
    sortable: true,
  },
  {
    name: 'seller_first_offer_profit_total',
    label: 'First Offer Profit Total',
    field: 'seller_first_offer_profit_total',
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer_offer_bdt',
    label: 'Customer Offer (BDT)',
    field: 'customer_offer_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer_offer_bdt_total',
    label: 'Customer Offer Total (BDT)',
    field: 'customer_offer_bdt_total',
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer_offer_profit_pc',
    label: 'Customer Offer Profit /Pc',
    field: 'customer_offer_profit_pc',
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer_offer_profit_total',
    label: 'Customer Offer Profit Total',
    field: 'customer_offer_profit_total',
    align: 'left',
    sortable: true,
  },
  {
    name: 'customer_offer_profit_pc_perc',
    label: 'Customer Offer Profit %',
    field: 'customer_offer_profit_pc_perc',
    align: 'left',
    sortable: true,
  },
  {
    name: 'final_offer_bdt',
    label: 'Final Offer (BDT)',
    field: 'final_offer_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'final_offer_profit_pc',
    label: 'Final Offer Profit /Pc',
    field: 'final_offer_profit_pc',
    align: 'left',
    sortable: true,
  },
  {
    name: 'final_offer_profit_total',
    label: 'Final Offer Profit Total',
    field: 'final_offer_profit_total',
    align: 'left',
    sortable: true,
  },
  {
    name: 'final_offer_profit_pc_perc',
    label: 'Final Offer Profit %',
    field: 'final_offer_profit_pc_perc',
    align: 'left',
    sortable: true,
  },
]
</script>
