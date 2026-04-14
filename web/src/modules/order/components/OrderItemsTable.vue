<template>
  <q-table
    flat
    bordered
    :rows="tableRows"
    :columns="columns"
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

    <template #body-cell-price_gbp="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.price_gbp, '£') }}
      </q-td>
    </template>

    <template #body-cell-cost_gbp="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.cost_gbp, '£') }}
      </q-td>
    </template>

    <template #body-cell-cost_bdt="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.cost_bdt, '৳') }}
      </q-td>
    </template>

    <template #body-cell-first_offer_bdt="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.first_offer_bdt, '৳') }}
      </q-td>
    </template>

    <template #body-cell-customer_offer_bdt="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.customer_offer_bdt, '৳') }}
      </q-td>
    </template>

    <template #body-cell-final_offer_bdt="props">
      <q-td :props="props">
        {{ formatCurrency(props.row.final_offer_bdt, '৳') }}
      </q-td>
    </template>

    <template #body-cell-minimum_quantity="props">
      <q-td :props="props">
        {{ props.row.minimum_quantity }}
      </q-td>
    </template>

    <template #body-cell-ordered_quantity="props">
      <q-td :props="props">
        {{ props.row.ordered_quantity }}
      </q-td>
    </template>

    <template #body-cell-delivered_quantity="props">
      <q-td :props="props">
        {{ props.row.delivered_quantity }}
      </q-td>
    </template>

    <template #body-cell-returned_quantity="props">
      <q-td :props="props">
        {{ props.row.returned_quantity }}
      </q-td>
    </template>

    <template #body-cell-product_weight="props">
      <q-td :props="props">
        {{ formatWeight(props.row.product_weight) }}
      </q-td>
    </template>

    <template #body-cell-package_weight="props">
      <q-td :props="props">
        {{ formatWeight(props.row.package_weight) }}
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

    <template #body-cell-created_at="props">
      <q-td :props="props">
        {{ formatDate(props.row.created_at) }}
      </q-td>
    </template>

    <template #body-cell-updated_at="props">
      <q-td :props="props">
        {{ formatDate(props.row.updated_at) }}
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
import { computed } from 'vue'
import type { QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'

type OrderItem = {
  id: number
  name: string
  cost_bdt: number | null
  cost_gbp: number | null
  order_id: number
  image_url: string | null
  price_gbp: number | null
  created_at: string
  product_id: number | null
  updated_at: string
  package_weight: number | null
  product_weight: number | null
  final_offer_bdt: number | null
  first_offer_bdt: number | null
  minimum_quantity: number
  ordered_quantity: number
  returned_quantity: number
  customer_offer_bdt: number | null
  delivered_quantity: number
}
type OrderStatus = 'customer_submit' | 'priced' | 'negotiate' | 'ordered' | 'placed'

const props = withDefaults(
  defineProps<{
    items?: OrderItem[]
    status?: OrderStatus
  }>(),
  {
    items: () => [],
  }
)

const tableRows = computed(() =>
  props.items.map((item, index) => ({
    ...item,
    sl: index + 1,
  }))
)

const formatCurrency = (value: number | null, symbol = '') => {
  if (value == null) return '-'
  return `${symbol}${value}`
}

const formatWeight = (value: number | null) => {
  if (value == null) return '-'
  return `${value}g`
}

const formatDate = (value: string | null) => {
  if (!value) return '-'
  return new Date(value).toLocaleString()
}

const columns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'left',
    sortable: false,
  },
  {
    name: 'id',
    label: 'ID',
    field: 'id',
    align: 'left',
    sortable: true,
  },
  {
    name: 'order_id',
    label: 'Order ID',
    field: 'order_id',
    align: 'left',
    sortable: true,
  },
  {
    name: 'product_id',
    label: 'Product ID',
    field: 'product_id',
    align: 'left',
    sortable: true,
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
    name: 'price_gbp',
    label: 'Price (GBP)',
    field: 'price_gbp',
    align: 'left',
    sortable: true,
  },
  {
    name: 'cost_gbp',
    label: 'Cost (GBP)',
    field: 'cost_gbp',
    align: 'left',
    sortable: true,
  },
  {
    name: 'cost_bdt',
    label: 'Cost (BDT)',
    field: 'cost_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'first_offer_bdt',
    label: 'First Offer (BDT)',
    field: 'first_offer_bdt',
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
    name: 'final_offer_bdt',
    label: 'Final Offer (BDT)',
    field: 'final_offer_bdt',
    align: 'left',
    sortable: true,
  },
  {
    name: 'minimum_quantity',
    label: 'Minimum Qty',
    field: 'minimum_quantity',
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
    name: 'delivered_quantity',
    label: 'Delivered Qty',
    field: 'delivered_quantity',
    align: 'left',
    sortable: true,
  },
  {
    name: 'returned_quantity',
    label: 'Returned Qty',
    field: 'returned_quantity',
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
    name: 'created_at',
    label: 'Created At',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'updated_at',
    label: 'Updated At',
    field: 'updated_at',
    align: 'left',
    sortable: true,
  },
]
</script>
