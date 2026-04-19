<template>
  <div>
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="visibleCompactColumns"
      row-key="id"
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      class="bg-white"
    >
      <template #header-cell-select="props">
        <q-th :props="props" class="text-center">
          <q-checkbox
            :model-value="allVisibleSelected"
            :indeterminate="someVisibleSelected"
            dense
            @update:model-value="toggleSelectAllVisible"
          />
        </q-th>
      </template>

      <template #body-cell-select="props">
        <q-td :props="props" class="text-center">
          <q-checkbox
            :model-value="isSelected(props.row.id)"
            dense
            @update:model-value="(value) => toggleSelection(props.row.id, value)"
          />
        </q-td>
      </template>

      <template #body-cell-ship="props">
        <q-td :props="props" class="text-center">
          <q-btn
            color="primary"
            no-caps
            dense
            size="sm"
            label="Ship"
            @click="onShipClick(props.row)"
          />
        </q-td>
      </template>

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
          <div class="whitespace-normal order-item-name-cell row items-center no-wrap q-gutter-xs">
            <span>{{ props.row.name }}</span>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="content_copy"
              @click="copyText(props.row.name, 'Name')"
            />
          </div>
          <div class="text-caption text-grey-7 row items-center no-wrap q-gutter-xs">
            <span>Barcode: {{ props.row.barcode ?? '-' }}</span>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="content_copy"
              @click="copyText(props.row.barcode, 'Barcode')"
            />
          </div>
          <div class="text-caption text-grey-7 row items-center no-wrap q-gutter-xs">
            <span>Product Code: {{ props.row.product_code ?? '-' }}</span>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="content_copy"
              @click="copyText(props.row.product_code, 'Product code')"
            />
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
import { computed, toRef } from 'vue'
import { copyToClipboard, type QTableColumn, useQuasar } from 'quasar'
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
  | 'processing'
  | 'ordered'
  | 'placed'

const props = withDefaults(
  defineProps<{
    items?: OrderItem[]
    status?: OrderStatus
    conversionRate?: number
    cargoRate?: number
    profitRate?: number
    selectedIds?: number[]
  }>(),
  {
    items: () => [],
    status: 'customer_submit',
    conversionRate: 0,
    cargoRate: 0,
    profitRate: 0,
    selectedIds: () => [],
  }
)
const emit = defineEmits<{
  (e: 'update:selectedIds', value: number[]): void
  (e: 'ship', value: number): void
}>()

const { tableRows } = useOrderItemTableRows({
  items: toRef(props, 'items'),
  conversionRate: toRef(props, 'conversionRate'),
  cargoRate: toRef(props, 'cargoRate'),
  profitRate: toRef(props, 'profitRate'),
})
const $q = useQuasar()

const formatPercent = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const compactColumns: QTableColumn[] = [
  {
    name: 'select',
    label: '',
    field: 'select',
    align: 'center',
    sortable: false,
    style: 'width: 52px; min-width: 52px; max-width: 52px;',
    headerStyle: 'width: 52px; min-width: 52px; max-width: 52px;',
  },
  {
    name: 'ship',
    label: '',
    field: 'ship',
    align: 'center',
    sortable: false,
    style: 'width: 52px; min-width: 52px; max-width: 52px;',
    headerStyle: 'width: 52px; min-width: 52px; max-width: 52px;',
  },
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
    style: 'background-color:#f2f4f7;font-weight:bold',
    headerStyle: 'background-color:#f2f4f7;',
    headerClasses: 'text-center'
  },
  {
    name: 'cost_summary',
    label: 'Cost / Line Total',
    field: 'cost_bdt',
    align: 'center',
    style: 'background-color:#f8f4d9;font-weight:bold',
    headerStyle: 'background-color:#f8f4d9;',
  },
  {
    name: 'first_offer_summary',
    label: 'First Offer / Line Total / Profit',
    field: 'seller_first_offer_bdt',
    align: 'center',
    style: 'background-color:#e0f2f6;font-weight:bold',
    headerStyle: 'background-color:#e0f2f6;',
  },
  {
    name: 'customer_offer_summary',
    label: 'Customer Offer / Line Total / Profit',
    field: 'customer_offer_bdt',
    align: 'center',
    style: 'background-color:#f8e8d5;font-weight:bold',
    headerStyle: 'background-color:#f8e8d5;',
  },
  {
    name: 'final_offer_summary',
    label: 'Final Offer / Line Total / Profit',
    field: 'final_offer_bdt',
    align: 'center',
    style: 'background-color:#e8e2f8;font-weight:bold',
    headerStyle: 'background-color:#e8e2f8;',
  },
]

const compactStatusColumnMap: Record<OrderStatus, string[]> = {
  customer_submit: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
  ],
  priced: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'cost_summary',
    'first_offer_summary',
  ],
  negotiate: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'cost_summary',
    'first_offer_summary',
    'customer_offer_summary',
  ],
  final_offered: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'cost_summary',
    'first_offer_summary',
    'customer_offer_summary',
    'final_offer_summary',
  ],
  processing: [
    'ship',
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'cost_summary',
    'first_offer_summary',
    'customer_offer_summary',
    'final_offer_summary',
  ],
  ordered: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'final_offer_summary',
  ],
  placed: [
    'sl',
    'image_url',
    'product_details',
    'ordered_quantity',
    'final_offer_summary',
  ],
}

const visibleCompactColumns = computed(() => {
  const currentStatus = props.status || 'customer_submit'
  const visibleColumnNames = compactStatusColumnMap[currentStatus] || []
  return compactColumns.filter(
    (column) => column.name === 'select' || visibleColumnNames.includes(column.name),
  )
})

const selectedIdSet = computed(() => new Set(props.selectedIds ?? []))
const isSelected = (id: number) => selectedIdSet.value.has(id)
const visibleIds = computed(() => tableRows.value.map((row) => row.id))
const allVisibleSelected = computed(
  () => visibleIds.value.length > 0 && visibleIds.value.every((id) => selectedIdSet.value.has(id)),
)
const someVisibleSelected = computed(
  () => !allVisibleSelected.value && visibleIds.value.some((id) => selectedIdSet.value.has(id)),
)

const toggleSelection = (id: number, checked: boolean | null) => {
  const next = new Set(props.selectedIds ?? [])
  if (checked) {
    next.add(id)
  } else {
    next.delete(id)
  }
  emit('update:selectedIds', Array.from(next))
}

const toggleSelectAllVisible = (checked: boolean | null) => {
  const next = new Set(props.selectedIds ?? [])
  if (checked) {
    visibleIds.value.forEach((id) => next.add(id))
  } else {
    visibleIds.value.forEach((id) => next.delete(id))
  }
  emit('update:selectedIds', Array.from(next))
}

const copyText = async (value: unknown, label: string) => {
  const text =
    typeof value === 'string'
      ? value.trim()
      : typeof value === 'number'
        ? String(value)
        : ''
  if (!text || text === '-') {
    return
  }

  await copyToClipboard(text)
  $q.notify({
    type: 'positive',
    message: `${label} copied`,
    position: 'top-right',
  })
}

const onShipClick = (row: OrderItem) => {
  emit('ship', row.id)
}
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

:deep(.q-table th:nth-child(4)),
:deep(.q-table td:nth-child(4)) {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  min-width: 120px !important;
  width: 120px !important;
  max-width: 120px !important;
  padding-right: 8px !important;
  padding-left: 8px !important;
}

:deep(.q-table th:nth-child(4)),
:deep(.q-table td:nth-child(4)) {
  padding-left: 18px !important;
}

.order-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.2;
  font-size: 12px;
}

.order-table-image-box {
  width: 96px;
  height: 96px;
  min-width: 96px;
  min-height: 96px;
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
