<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment Details"
        @click="onBack"
      />
    </div>

    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">
        Batch Code PC: #{{ shipmentStore.selectedShipment?.id }} {{ shipmentStore.selectedShipment?.name }}
      </div>
      <q-btn
        color="primary"
        no-caps
        label="Insert Batch Rows"
        :disable="insertDisabled"
        :loading="shipmentStore.saving"
        @click="onInsertRows"
      />
    </div>

    <q-banner v-if="shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <q-card flat bordered class="bg-grey-1">
      <q-card-section class="bg-blue-1">
        <q-btn-toggle
          v-model="activeTab"
          no-caps
          unelevated
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="tabOptions"
        />
      </q-card-section>

      <q-tab-panels v-model="activeTab" animated>
        <q-tab-panel name="insert" class="bg-grey-1">
          <div class="batch-input-row row no-wrap q-col-gutter-md">
            <div class="col">
              <q-input
                v-model="productCodesText"
                type="textarea"
                autogrow
                outlined
                label="Product Codes (one per line)"
                hint="Paste product codes like COSBIO037"
              />
            </div>
            <div class="col">
              <q-input
                v-model="batchIdsText"
                type="textarea"
                autogrow
                outlined
                label="Batch IDs (one per line)"
              />
            </div>
            <div class="col">
              <q-input
                v-model="manufacturingDatesText"
                type="textarea"
                autogrow
                outlined
                label="Manufacturing Dates (DD/MM/YYYY, one per line)"
              />
            </div>
          </div>
          <div class="text-caption text-grey-7 q-mt-sm">
            Rows are matched by line number. Product code is matched from shipment items.
          </div>
          <q-markup-table flat class="q-mt-md">
            <thead>
              <tr>
                <th class="text-right">SL</th>
                <th class="text-left">Product Code</th>
                <th class="text-left">Shipment Item ID</th>
                <th class="text-left">Batch ID</th>
                <th class="text-left">Manufacturing Date</th>
                <th class="text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in previewRows" :key="`${index}-${row.productCode}-${row.batchId}`">
                <td class="text-right">{{ index + 1 }}</td>
                <td>{{ row.productCode || '-' }}</td>
                <td>{{ row.shipmentItemId ?? '-' }}</td>
                <td>{{ row.batchId || '-' }}</td>
                <td>
                  <span v-if="!row.isEmptyDate">{{ row.manufacturingDateRaw }}</span>
                  <span v-else class="text-grey-6">blank</span>
                </td>
                <td>
                  <span :class="row.matchOk ? 'text-positive' : 'text-warning'">
                    {{ row.matchMessage }}
                  </span>
                </td>
              </tr>
              <tr v-if="!previewRows.length">
                <td colspan="6" class="text-center text-grey-6 q-pa-md">Paste product codes to preview.</td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-tab-panel>

        <q-tab-panel name="data" class="bg-grey-1">
          <div class="row justify-end q-mb-sm">
            <q-btn
              flat
              no-caps
              color="primary"
              icon="refresh"
              label="Refresh"
              :loading="shipmentStore.loading"
              @click="onRefreshRows"
            />
          </div>
          <q-markup-table flat>
            <thead>
              <tr>
                <th class="text-right">SL</th>
                <th class="text-left">Image</th>
                <th class="text-left">Product Name</th>
                <th class="text-left">Product Code</th>
                <th class="text-left batch-id-col">Batch ID</th>
                <th class="text-left">Manufacturing Date</th>
                <th class="text-left">Expire Date</th>
                <th class="text-left">Time Left</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in batchRowsForUi" :key="row.id">
                <td class="text-right">{{ index + 1 }}</td>
                <td>
                  <q-img
                    v-if="row.imageUrl"
                    :src="row.imageUrl"
                    fit="contain"
                    style="width: 40px; height: 40px"
                  />
                  <span v-else>-</span>
                </td>
                <td>{{ row.productName ?? '-' }}</td>
                <td>{{ row.product_code ?? '-' }}</td>
                <td class="batch-id-col">{{ row.batch_id ?? '-' }}</td>
                <td>{{ formatIsoDateToDdMmYyyy(row.manufacturing_date) }}</td>
                <td>{{ formatIsoDateToDdMmYyyy(row.uiExpireDate) }}</td>
                <td>{{ row.timeLeftLabel }}</td>
              </tr>
              <tr v-if="!shipmentStore.batchCodePcRows.length">
                <td colspan="8" class="text-center text-grey-6 q-pa-md">No batch code rows found.</td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-tab-panel>
      </q-tab-panels>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from '../stores/shipmentStore'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()

const shipmentId = computed(() => Number(route.params.id))

const productCodesText = ref('')
const batchIdsText = ref('')
const manufacturingDatesText = ref('')
const activeTab = ref<'insert' | 'data'>('data')
const tabOptions = [
  { label: 'Data', value: 'data' as const },
  { label: 'Insert', value: 'insert' as const },
]

const parseLines = (value: string) =>
  value
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)

const parseLinesKeepBlanks = (value: string) => value.split('\n').map((line) => line.trim())

const normalizeDdMmYyyyToIso = (value: string): string | null => {
  const raw = value.trim()
  if (raw.toLowerCase() === 'null') {
    return null
  }
  const match = raw.match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
  if (!match) return null

  const day = Number(match[1])
  const month = Number(match[2])
  const year = Number(match[3])
  if (!Number.isFinite(day) || !Number.isFinite(month) || !Number.isFinite(year)) return null
  if (month < 1 || month > 12 || day < 1 || day > 31) return null

  const dt = new Date(year, month - 1, day)
  if (
    dt.getFullYear() !== year ||
    dt.getMonth() !== month - 1 ||
    dt.getDate() !== day
  ) {
    return null
  }

  const mm = String(month).padStart(2, '0')
  const dd = String(day).padStart(2, '0')
  return `${year}-${mm}-${dd}`
}

const shipmentItemByProductCode = computed(() => {
  const map = new Map<string, number>()
  shipmentStore.shipmentItems.forEach((item) => {
    const code = String(item.product_code ?? '')
      .trim()
      .toLowerCase()
    if (code && !map.has(code)) {
      map.set(code, item.id)
    }
  })
  return map
})

const shipmentItemDetailsMap = computed(() => {
  const byId = new Map<number, { name: string | null; image_url: string | null }>()
  const byCode = new Map<string, { name: string | null; image_url: string | null }>()

  shipmentStore.shipmentItems.forEach((item) => {
    byId.set(item.id, { name: item.name ?? null, image_url: item.image_url ?? null })
    const code = String(item.product_code ?? '').trim().toLowerCase()
    if (code && !byCode.has(code)) {
      byCode.set(code, { name: item.name ?? null, image_url: item.image_url ?? null })
    }
  })

  return { byId, byCode }
})

const addMonthsToIsoDate = (isoDate: string, months: number): string | null => {
  const parts = isoDate.split('-').map((v) => Number(v))
  if (parts.length !== 3 || parts.some((v) => !Number.isFinite(v))) return null
  const year = parts[0] as number
  const month = parts[1] as number
  const day = parts[2] as number
  const dt = new Date(year, month - 1 + months, day)
  if (!Number.isFinite(dt.getTime())) return null
  const yyyy = String(dt.getFullYear())
  const mm = String(dt.getMonth() + 1).padStart(2, '0')
  const dd = String(dt.getDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

const getExpireLeftLabel = (expireDate: string | null): string => {
  if (!expireDate) return '-'
  const parts = expireDate.split('-').map((v) => Number(v))
  const y = parts[0] as number
  const m = parts[1] as number
  const d = parts[2] as number
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) return '-'

  const today = new Date()
  const start = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  const end = new Date(y, m - 1, d)
  if (!Number.isFinite(end.getTime())) return '-'
  if (end < start) return 'Expired'

  let months = (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth())
  let candidate = new Date(start.getFullYear(), start.getMonth() + months, start.getDate())
  if (candidate > end) {
    months -= 1
    candidate = new Date(start.getFullYear(), start.getMonth() + months, start.getDate())
  }

  const days = Math.floor((end.getTime() - candidate.getTime()) / (1000 * 60 * 60 * 24))
  return `${months} month${months === 1 ? '' : 's'} ${days} day${days === 1 ? '' : 's'}`
}

const formatIsoDateToDdMmYyyy = (value: string | null | undefined): string => {
  if (!value) return '-'
  const [y, m, d] = value.split('-')
  if (!y || !m || !d) return '-'
  return `${d}/${m}/${y}`
}

const batchRowsForUi = computed(() =>
  shipmentStore.batchCodePcRows.map((row) => {
    const byId = row.shipment_item_id
      ? shipmentItemDetailsMap.value.byId.get(row.shipment_item_id)
      : undefined
    const byCode = row.product_code
      ? shipmentItemDetailsMap.value.byCode.get(row.product_code.trim().toLowerCase())
      : undefined
    const details = byId ?? byCode

    const uiExpireDate = row.manufacturing_date
      ? addMonthsToIsoDate(row.manufacturing_date, 36)
      : null

    return {
      ...row,
      productName: details?.name ?? null,
      imageUrl: details?.image_url ?? null,
      uiExpireDate,
      timeLeftLabel: getExpireLeftLabel(uiExpireDate),
    }
  }),
)

const previewRows = computed(() => {
  const productCodes = parseLines(productCodesText.value)
  const batchIds = parseLinesKeepBlanks(batchIdsText.value)
  const manufacturingDates = parseLinesKeepBlanks(manufacturingDatesText.value)

  return productCodes.map((productCode, index) => {
    const normalizedCode = productCode.toLowerCase()
    const shipmentItemId = shipmentItemByProductCode.value.get(normalizedCode) ?? null
    const batchId = batchIds[index] ?? ''
    const manufacturingDateRaw = manufacturingDates[index] ?? ''
    const isNullToken = manufacturingDateRaw.toLowerCase() === 'null'
    const isEmptyDate = !manufacturingDateRaw || isNullToken
    const manufacturingDateIso = manufacturingDateRaw
      ? normalizeDdMmYyyyToIso(manufacturingDateRaw)
      : null
    const matchOk = shipmentItemId != null
    const dateOk = isEmptyDate || Boolean(manufacturingDateIso)
    const rowOk = dateOk

    return {
      productCode,
      shipmentItemId,
      batchId,
      manufacturingDateRaw,
      manufacturingDateIso,
      isEmptyDate,
      matchOk,
      rowOk,
      matchMessage: matchOk
        ? dateOk
          ? 'Ready'
          : 'Invalid date format (use DD/MM/YYYY)'
        : dateOk
          ? 'Product code not found in this shipment (will insert with null shipment item)'
          : 'Invalid date format (use DD/MM/YYYY)',
    }
  })
})

const insertDisabled = computed(() => {
  const productCodes = parseLines(productCodesText.value)
  const batchIds = parseLinesKeepBlanks(batchIdsText.value)
  const manufacturingDates = parseLinesKeepBlanks(manufacturingDatesText.value)

  if (!productCodes.length) return true
  if (batchIds.length !== productCodes.length) return true
  if (manufacturingDates.length < productCodes.length) return true
  if (previewRows.value.some((row) => !row.rowOk)) return true
  return false
})

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}`)
}

const onInsertRows = async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) return

  const productCodes = parseLines(productCodesText.value)
  const batchIds = parseLinesKeepBlanks(batchIdsText.value)
  const manufacturingDates = parseLinesKeepBlanks(manufacturingDatesText.value)

  if (!productCodes.length) {
    $q.notify({ type: 'warning', message: 'Please paste product codes.' })
    return
  }

  if (batchIds.length !== productCodes.length) {
    $q.notify({ type: 'warning', message: 'Batch IDs count must match product codes count.' })
    return
  }

  if (manufacturingDates.length < productCodes.length) {
    $q.notify({
      type: 'warning',
      message: 'Please include one date line per product code (blank is allowed).',
    })
    return
  }

  const rows = previewRows.value.map((row) => {
    const expireDateIso = row.manufacturingDateIso
      ? addMonthsToIsoDate(row.manufacturingDateIso, 36)
      : null
    return {
      shipment_id: shipmentId.value,
      shipment_item_id: row.shipmentItemId == null ? null : Number(row.shipmentItemId),
      product_code: row.productCode,
      batch_id: row.batchId,
      manufacturing_date: row.manufacturingDateIso,
      expire_date: expireDateIso,
    }
  })

  const result = await shipmentStore.bulkCreateBatchCodePc({ rows })
  if (!result.success) return

  await shipmentStore.fetchBatchCodePcByShipment(shipmentId.value)
  productCodesText.value = ''
  batchIdsText.value = ''
  manufacturingDatesText.value = ''
}

const onRefreshRows = async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) return
  await shipmentStore.fetchBatchCodePcByShipment(shipmentId.value)
}

onMounted(async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  await shipmentStore.fetchShipmentById(shipmentId.value)
  await shipmentStore.fetchBatchCodePcByShipment(shipmentId.value)
})
</script>

<style scoped>
.batch-input-row > .col {
  min-width: 0;
}

:deep(th.batch-id-col),
:deep(td.batch-id-col) {
  background: #eaf7ef;
}
</style>
