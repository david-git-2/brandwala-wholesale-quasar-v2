<template>
  <div>
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="customerOfferColumns"
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

      <template #body-cell-price_gbp="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ priceDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="priceDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onPricePopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #body-cell-ordered_quantity="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ quantityDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="quantityDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onQuantityPopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #body-cell-product_weight="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ productWeightDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="productWeightDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onProductWeightPopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #body-cell-package_weight="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ packageWeightDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="packageWeightDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onPackageWeightPopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #body-cell-seller_first_offer_bdt="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ firstOfferDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="firstOfferDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onFirstOfferPopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #body-cell-final_offer_bdt="props">
        <q-td :props="props">
          <span class="cursor-pointer">
            {{ finalOfferDraftById[props.row.id] ?? '-' }}
          </span>
          <q-popup-edit
            :model-value="finalOfferDraftById[props.row.id]"
            buttons
            persistent
            label-set="Save"
            label-cancel="Cancel"
            v-slot="scope"
            @save="(value) => onFinalOfferPopupSave(props.row.id, value)"
          >
            <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
          </q-popup-edit>
        </q-td>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-6">
          No items found
        </div>
      </template>
    </q-table>

    <div class="row justify-end q-mt-md">
      <q-btn
        color="primary"
        no-caps
        label="Save Item Changes"
        :loading="orderStore.saving"
        @click="onSaveButtonClick"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue'
import type { QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useOrderStore } from '../stores/orderStore'
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
const orderStore = useOrderStore()
const productStore = useProductStore()

const quantityDraftById = ref<Record<number, number | null>>({})
const quantityInitialById = ref<Record<number, number | null>>({})
const productWeightDraftById = ref<Record<number, number | null>>({})
const productWeightInitialById = ref<Record<number, number | null>>({})
const packageWeightDraftById = ref<Record<number, number | null>>({})
const packageWeightInitialById = ref<Record<number, number | null>>({})
const priceDraftById = ref<Record<number, number | null>>({})
const priceInitialById = ref<Record<number, number | null>>({})
const firstOfferDraftById = ref<Record<number, number | null>>({})
const firstOfferInitialById = ref<Record<number, number | null>>({})
const finalOfferDraftById = ref<Record<number, number | null>>({})
const finalOfferInitialById = ref<Record<number, number | null>>({})

watch(
  tableRows,
  (rows) => {
    const quantityDraft: Record<number, number | null> = {}
    const quantityInitial: Record<number, number | null> = {}
    const productWeightDraft: Record<number, number | null> = {}
    const productWeightInitial: Record<number, number | null> = {}
    const packageWeightDraft: Record<number, number | null> = {}
    const packageWeightInitial: Record<number, number | null> = {}
    const priceDraft: Record<number, number | null> = {}
    const priceInitial: Record<number, number | null> = {}
    const firstOfferDraft: Record<number, number | null> = {}
    const firstOfferInitial: Record<number, number | null> = {}
    const finalOfferDraft: Record<number, number | null> = {}
    const finalOfferInitial: Record<number, number | null> = {}

    rows.forEach((row) => {
      quantityDraft[row.id] = row.ordered_quantity ?? null
      quantityInitial[row.id] = row.ordered_quantity ?? null
      productWeightDraft[row.id] = row.product_weight ?? null
      productWeightInitial[row.id] = row.product_weight ?? null
      packageWeightDraft[row.id] = row.package_weight ?? null
      packageWeightInitial[row.id] = row.package_weight ?? null
      priceDraft[row.id] = row.price_gbp ?? null
      priceInitial[row.id] = row.price_gbp ?? null
      firstOfferDraft[row.id] = row.first_offer_bdt ?? row.seller_first_offer_bdt ?? null
      firstOfferInitial[row.id] = row.first_offer_bdt ?? row.seller_first_offer_bdt ?? null
      finalOfferDraft[row.id] = row.final_offer_bdt ?? row.customer_offer_bdt ?? null
      finalOfferInitial[row.id] = row.final_offer_bdt ?? row.customer_offer_bdt ?? null
    })

    quantityDraftById.value = quantityDraft
    quantityInitialById.value = quantityInitial
    productWeightDraftById.value = productWeightDraft
    productWeightInitialById.value = productWeightInitial
    packageWeightDraftById.value = packageWeightDraft
    packageWeightInitialById.value = packageWeightInitial
    priceDraftById.value = priceDraft
    priceInitialById.value = priceInitial
    firstOfferDraftById.value = firstOfferDraft
    firstOfferInitialById.value = firstOfferInitial
    finalOfferDraftById.value = finalOfferDraft
    finalOfferInitialById.value = finalOfferInitial
  },
  { immediate: true },
)

const allColumns: QTableColumn[] = [
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

const statusColumnMap: Record<OrderStatus, string[]> = {
  customer_submit: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'product_weight',
    'package_weight',
    'total_weight',
    'price_gbp',
    'line_total_purchese_cost_gbp',
    'cargo_rate',
    'unit_line_cost_gbp',
    'cost_bdt',
    'line_total_cost_bdt',
    'seller_first_offer_bdt',
    'final_offer_bdt',
    'seller_first_offer_bdt_total',
    'seller_first_offer_profit_pc',
    'seler_first_offer_profit_pc_perc',
    'seller_first_offer_profit_total',
  ],
  priced: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'product_weight',
    'package_weight',
    'total_weight',
    'price_gbp',
    'line_total_purchese_cost_gbp',
    'cargo_rate',
    'unit_line_cost_gbp',
    'cost_bdt',
    'line_total_cost_bdt',
    'seller_first_offer_bdt',
    'seller_first_offer_bdt_total',
    'seller_first_offer_profit_pc',
    'seler_first_offer_profit_pc_perc',
    'seller_first_offer_profit_total',
  ],
  negotiate: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'product_weight',
    'package_weight',
    'total_weight',
    'price_gbp',
    'line_total_purchese_cost_gbp',
    'cargo_rate',
    'unit_line_cost_gbp',
    'cost_bdt',
    'line_total_cost_bdt',
    'seller_first_offer_bdt',
    'final_offer_bdt',
    'final_offer_profit_pc',
    'final_offer_profit_total',
    'final_offer_profit_pc_perc',
    'seller_first_offer_bdt_total',
    'seller_first_offer_profit_pc',
    'seler_first_offer_profit_pc_perc',
    'seller_first_offer_profit_total',
    'customer_offer_bdt',
    'customer_offer_bdt_total',
    'customer_offer_profit_pc',
    'customer_offer_profit_total',
    'customer_offer_profit_pc_perc',
  ],
  final_offered: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'seller_first_offer_bdt',
    'final_offer_bdt',
    'final_offer_profit_pc',
    'final_offer_profit_total',
    'final_offer_profit_pc_perc',
  ],
  ordered: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'seller_first_offer_bdt',
    'final_offer_bdt',
    'final_offer_profit_pc',
    'final_offer_profit_total',
    'final_offer_profit_pc_perc',
  ],
  placed: [
    'sl',
    'image_url',
    'name',
    'ordered_quantity',
    'seller_first_offer_bdt',
    'final_offer_bdt',
    'final_offer_profit_pc',
    'final_offer_profit_total',
    'final_offer_profit_pc_perc',
  ],
}

const customerOfferColumns = computed(() => {
  const currentStatus = props.status || 'customer_submit'
  const visibleColumnNames = statusColumnMap[currentStatus] || []

  return allColumns.filter((column) => visibleColumnNames.includes(column.name))
})

const parseNullableNumber = (value: string | number | null) => {
  if (value == null || value === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const onQuantityDraftChange = (id: number, value: string | number | null) => {
  const parsed = parseNullableNumber(value)
  quantityDraftById.value[id] = parsed != null && parsed > 0 ? Math.floor(parsed) : null
}

const onProductWeightDraftChange = (id: number, value: string | number | null) => {
  productWeightDraftById.value[id] = parseNullableNumber(value)
}

const onPackageWeightDraftChange = (id: number, value: string | number | null) => {
  packageWeightDraftById.value[id] = parseNullableNumber(value)
}

const onPriceDraftChange = (id: number, value: string | number | null) => {
  priceDraftById.value[id] = parseNullableNumber(value)
}

const onFirstOfferDraftChange = (id: number, value: string | number | null) => {
  firstOfferDraftById.value[id] = parseNullableNumber(value)
}

const onFinalOfferDraftChange = (id: number, value: string | number | null) => {
  finalOfferDraftById.value[id] = parseNullableNumber(value)
}

const onSaveButtonClick =async  () => {
  void onSaveItemChanges()
  await orderStore.updateOrder({
    id: orderStore.selected?.id ||0,
    patch: {
      status:'final_offered',
    },
  })
}

const onSaveItemChanges = async () => {

  const payload = tableRows.value.map((row) => ({
    id: row.id,
    ordered_quantity: quantityDraftById.value[row.id] ?? row.ordered_quantity,
    price_gbp: priceDraftById.value[row.id] ?? row.price_gbp ?? null,
    product_weight: productWeightDraftById.value[row.id] ?? row.product_weight ?? null,
    package_weight: packageWeightDraftById.value[row.id] ?? row.package_weight ?? null,
    first_offer_bdt:
      firstOfferDraftById.value[row.id] ?? row.first_offer_bdt ?? row.seller_first_offer_bdt,
  }))
  const productWeightUpdatesByProductId = getProductWeightUpdatesByProductId()

  if (!payload.length) {
    return
  }

  const result = await orderStore.bulkUpdateOrderItems(payload)
  if (!result.success) {
    return
  }

  payload.forEach((entry) => {
    quantityInitialById.value[entry.id] = entry.ordered_quantity ?? null
    priceInitialById.value[entry.id] = entry.price_gbp
    productWeightInitialById.value[entry.id] = entry.product_weight
    packageWeightInitialById.value[entry.id] = entry.package_weight
    firstOfferInitialById.value[entry.id] = entry.first_offer_bdt
  })

  await syncProductWeightsFromOrderRows(productWeightUpdatesByProductId)
}

const onQuantityPopupSave = (id: number, value: string | number | null) => {
  onQuantityDraftChange(id, value)
  void updateSingleItemFromDraft(id, ['ordered_quantity'])
}

const onProductWeightPopupSave = (id: number, value: string | number | null) => {
  onProductWeightDraftChange(id, value)
  void updateSingleItemFromDraft(id, ['product_weight', 'package_weight'])
}

const onPackageWeightPopupSave = (id: number, value: string | number | null) => {
  onPackageWeightDraftChange(id, value)
  void updateSingleItemFromDraft(id, ['product_weight', 'package_weight'])
}

const onPricePopupSave = (id: number, value: string | number | null) => {
  onPriceDraftChange(id, value)
  void updateSingleItemFromDraft(id, ['price_gbp'])
}

const onFirstOfferPopupSave = (id: number, value: string | number | null) => {
  onFirstOfferDraftChange(id, value)
  void updateSingleItemFromDraft(id, ['first_offer_bdt'])
}

const onFinalOfferPopupSave = async (id: number, value: string | number | null) => {
  onFinalOfferDraftChange(id, value)
  const finalOfferValue = finalOfferDraftById.value[id] ?? null

  const result = await orderStore.updateOrderItem({
    id,
    patch: {
      final_offer_bdt: finalOfferValue,
    },
  })

  if (!result.success) {
    return
  }

  finalOfferInitialById.value[id] = finalOfferValue
}

const getProductWeightUpdatesByProductId = () => {
  const updatesByProductId = new Map<
    number,
    { product_weight: number | null; package_weight: number | null }
  >()

  tableRows.value.forEach((row) => {
    const productId = row.product_id
    if (!productId) {
      return
    }

    const nextProductWeight = productWeightDraftById.value[row.id] ?? row.product_weight ?? null
    const nextPackageWeight = packageWeightDraftById.value[row.id] ?? row.package_weight ?? null

    const productWeightChanged =
      nextProductWeight !== (productWeightInitialById.value[row.id] ?? null)
    const packageWeightChanged =
      nextPackageWeight !== (packageWeightInitialById.value[row.id] ?? null)

    if (!productWeightChanged && !packageWeightChanged) {
      return
    }

    updatesByProductId.set(productId, {
      product_weight: nextProductWeight,
      package_weight: nextPackageWeight,
    })
  })

  return updatesByProductId
}

const syncProductWeightsFromOrderRows = async (
  updatesByProductId: Map<number, { product_weight: number | null; package_weight: number | null }>,
) => {
  if (!updatesByProductId.size) {
    return
  }

  for (const [productId, patch] of updatesByProductId.entries()) {
    await productStore.updateProduct({
      id: productId,
      product_weight: patch.product_weight,
      package_weight: patch.package_weight,
    })
  }
}

const updateSingleItemFromDraft = async (
  id: number,
  fields: Array<'ordered_quantity' | 'price_gbp' | 'product_weight' | 'package_weight' | 'first_offer_bdt'>,
) => {
  const row = tableRows.value.find((item) => item.id === id)
  if (!row) {
    return
  }

  const patch: Record<string, number | null> = {}

  if (fields.includes('ordered_quantity')) {
    patch.ordered_quantity = quantityDraftById.value[id] ?? row.ordered_quantity ?? null
  }

  if (fields.includes('price_gbp')) {
    patch.price_gbp = priceDraftById.value[id] ?? row.price_gbp ?? null
  }

  if (fields.includes('product_weight')) {
    patch.product_weight = productWeightDraftById.value[id] ?? row.product_weight ?? null
  }

  if (fields.includes('package_weight')) {
    patch.package_weight = packageWeightDraftById.value[id] ?? row.package_weight ?? null
  }

  if (fields.includes('first_offer_bdt')) {
    patch.first_offer_bdt =
      firstOfferDraftById.value[id] ?? row.first_offer_bdt ?? row.seller_first_offer_bdt ?? null
  }

  const result = await orderStore.updateOrderItem({
    id,
    patch,
  })

  if (!result.success) {
    return
  }

  if ('ordered_quantity' in patch) {
    quantityInitialById.value[id] = patch.ordered_quantity
  }
  if ('price_gbp' in patch) {
    priceInitialById.value[id] = patch.price_gbp
  }
  if ('product_weight' in patch) {
    productWeightInitialById.value[id] = patch.product_weight
  }
  if ('package_weight' in patch) {
    packageWeightInitialById.value[id] = patch.package_weight
  }
  if ('first_offer_bdt' in patch) {
    firstOfferInitialById.value[id] = patch.first_offer_bdt
  }

  if (
    row.product_id &&
    ('product_weight' in patch || 'package_weight' in patch)
  ) {
    await productStore.updateProduct({
      id: row.product_id,
      product_weight: patch.product_weight ?? row.product_weight ?? null,
      package_weight: patch.package_weight ?? row.package_weight ?? null,
    })
  }
}
</script>
