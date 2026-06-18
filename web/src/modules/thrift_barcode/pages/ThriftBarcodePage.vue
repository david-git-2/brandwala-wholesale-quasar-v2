<template>
  <q-page class="q-pa-md barcode-list-page">
    <!-- Page Title Card -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Thrift Barcodes</div>
            <div class="text-caption text-grey-8">Generate and print barcodes in bulk</div>
          </div>
          <div class="col-auto row q-gutter-sm">
            <q-btn
              color="secondary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="print"
              label="Print Barcodes"
              @click="onClickPrint"
            />
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="check_circle"
              label="Mark Printed"
              :disabled="selected.length === 0"
              @click="onMarkPrinted"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Error Alert Banner -->
    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <!-- Barcode Bulk Generator Form -->
    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold q-mb-md text-primary">Bulk Barcode Generator</div>
        <q-form @submit.prevent="showConfirmGenDialog" class="row q-col-gutter-md items-end">
          <div class="col-12 col-sm-6 text-grey-8">
            The system will automatically determine the next sequential prefix (starting from AA) and append the current year (e.g. {{ currentYear }}).
          </div>
          <div class="col-12 col-sm-3">
            <q-select
              v-model="genQuantity"
              label="Quantity to Generate"
              outlined
              dense
              :options="qtyOptions"
              emit-value
              map-options
              hide-bottom-space
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-btn
              type="submit"
              color="primary"
              no-caps
              icon="add"
              label="Generate"
              class="full-width pill-btn"
              :loading="loading"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>

    <!-- Data Table & Filter Panel -->
    <q-card flat class="floating-surface shadow-1">
      <!-- Search & Filters Header -->
      <q-card-section class="q-py-md">
        <div class="row q-col-gutter-sm items-center">
          <div class="col-12 col-sm-4">
            <q-input
              v-model="filterText"
              label="Search Barcodes"
              outlined
              dense
              placeholder="e.g. 01-AA-26-"
              clearable
            >
              <template v-slot:append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-4">
            <q-select
              v-model="filterPrinted"
              label="Printed Status"
              outlined
              dense
              :options="printedOptions"
              emit-value
              map-options
            />
          </div>
          <div class="col-12 col-sm-4">
            <q-select
              v-model="filterStatus"
              label="Barcode Status"
              outlined
              dense
              :options="statusOptions"
              emit-value
              map-options
            />
          </div>
        </div>
      </q-card-section>

      <!-- Table -->
      <q-card-section class="q-pa-none">
        <q-table
          flat
          :rows="filteredRows"
          :columns="columns"
          row-key="id"
          selection="multiple"
          v-model:selected="selected"
          :loading="loading"
          :pagination="{ rowsPerPage: 15 }"
        >
          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                class="status-chip"
                :style="props.value === 'AVAILABLE' ? activeChipStyle : inactiveChipStyle"
              >
                <span class="status-dot" :style="{ backgroundColor: props.value === 'AVAILABLE' ? '#2f8b5d' : '#a85b2f' }" />
                {{ props.value }}
              </q-chip>
            </q-td>
          </template>

          <template v-slot:body-cell-is_printed="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                class="status-chip"
                :style="props.value === 1 ? printedChipStyle : unprintedChipStyle"
              >
                <span class="status-dot" :style="{ backgroundColor: props.value === 1 ? '#2f5b8b' : '#66758c' }" />
                {{ props.value === 1 ? 'Yes' : 'No' }}
              </q-chip>
            </q-td>
          </template>

          <template v-slot:body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.value) }}
            </q-td>
          </template>

          <template v-slot:body-cell-actions="props">
            <q-td :props="props" class="text-center">
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="visibility"
                @click="onPreviewBarcode(props.row)"
              >
                <q-tooltip>Preview Barcode</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Barcode Generation Confirmation Dialog -->
    <q-dialog v-model="confirmGenDialog" persistent>
      <q-card style="min-width: 400px; border-radius: 12px;">
        <q-card-section class="bg-primary text-white q-py-sm">
          <div class="text-subtitle1 text-weight-bold">Confirm Generation</div>
        </q-card-section>

        <q-card-section class="q-py-md">
          <div class="text-body2 q-mb-md">
            You are about to generate <strong>{{ genQuantity }}</strong> new barcodes.
          </div>
          <div class="q-pl-sm q-py-xs bg-grey-2 rounded-borders q-mb-md">
            <div><strong>Estimated Range:</strong> {{ estimatedRange }}</div>
            <div><strong>Current Year Code:</strong> {{ currentYear }}</div>
          </div>
          <div class="text-caption text-grey-8">
            <div>• Total previously generated codes: <strong>{{ prevCount }}</strong></div>
            <div>• Total available (unprinted) codes: <strong>{{ availableCount }}</strong></div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pt-none">
          <q-btn flat label="Cancel" color="grey" v-close-popup />
          <q-btn unelevated label="Generate" color="primary" class="pill-btn" @click="handleGenerate" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Print Setup Dialog -->
    <q-dialog v-model="printDialog" persistent>
      <q-card style="min-width: 450px; border-radius: 12px;">
        <q-card-section class="bg-primary text-white q-py-sm">
          <div class="text-subtitle1 text-weight-bold">Print Setup</div>
        </q-card-section>

        <q-card-section class="q-py-md">
          <!-- Option A: Print Selected checkboxes -->
          <div v-if="selected.length > 0" class="q-mb-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Option 1: Print Selected Barcodes</div>
            <div class="text-body2 text-grey-7 q-mb-md">
              You currently have <strong>{{ selected.length }}</strong> barcodes selected in the table.
            </div>
            <q-btn
              color="secondary"
              no-caps
              label="Print Selected Only"
              icon="print"
              class="pill-btn"
              @click="confirmSelectedPrint"
            />
            <q-separator class="q-my-lg" />
          </div>

          <!-- Option B: Print Bulk Unprinted range -->
          <div>
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Bulk Print Unprinted Barcodes</div>
            <div class="text-body2 text-grey-7 q-mb-md">
              Choose the quantity of unprinted barcodes you want to print. The system will grab the first available ones.
            </div>
            
            <div class="row q-col-gutter-sm items-center q-mb-md">
              <div class="col-8">
                <q-input
                  v-model.number="printQty"
                  type="number"
                  label="Quantity to Print"
                  outlined
                  dense
                  min="1"
                  :max="unprintedCount"
                  hide-bottom-space
                />
              </div>
              <div class="col-4 text-right text-caption text-grey-7">
                Available unprinted: <strong>{{ unprintedCount }}</strong>
              </div>
            </div>

            <!-- Validation Error Warning -->
            <q-banner v-if="!hasSufficientUnprinted" class="bg-warning text-dark q-mb-md" rounded dense>
              Insufficient barcodes. You requested to print {{ printQty }} but only {{ unprintedCount }} unprinted barcodes exist. Please generate more first.
            </q-banner>

            <q-btn
              color="primary"
              no-caps
              label="Proceed to Print Preview"
              icon="navigate_next"
              class="pill-btn full-width"
              :disabled="!hasSufficientUnprinted || printQty <= 0"
              @click="confirmBulkPrint"
            />
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pt-none">
          <q-btn flat label="Close" color="grey" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Single Barcode Preview Dialog -->
    <q-dialog v-model="previewDialog">
      <q-card style="min-width: 320px; text-align: center; border-radius: 14px;">
        <q-card-section class="bg-grey-2 q-py-xs text-right">
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-lg">
          <div class="text-overline text-grey-7 q-mb-xs">THRIFT BARCODE PREVIEW</div>
          <div class="q-mb-md text-weight-bold text-subtitle1">{{ previewBarcode?.barcode_id }}</div>
          
          <div class="q-my-md q-px-md row justify-center">
            <div style="width: 100%; max-width: 240px; border: 1px solid #e0e0e0; padding: 12px; border-radius: 8px; background: #fff;">
              <BarcodeRenderer v-if="previewBarcode" :value="previewBarcode.barcode_id" :display-value="false" />
            </div>
          </div>

          <div class="text-caption text-grey-8 q-mt-md">
            Status: {{ previewBarcode?.status }} | Printed: {{ previewBarcode?.is_printed === 1 ? 'Yes' : 'No' }}
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useThriftBarcodeStore } from '../stores/thriftBarcodeStore'
import BarcodeRenderer from '../components/BarcodeRenderer.vue'
import type { ThriftBarcode } from '../types'

const router = useRouter()
const authStore = useAuthStore()
const barcodeStore = useThriftBarcodeStore()

const { barcodes, loading, error } = storeToRefs(barcodeStore)

// Generator State
const genQuantity = ref(50)
const qtyOptions = [50, 100, 150, 200, 300, 400, 500]

// Dialog state
const confirmGenDialog = ref(false)
const previewDialog = ref(false)
const previewBarcode = ref<ThriftBarcode | null>(null)
const printDialog = ref(false)
const printQty = ref(50)

// Filter State
const filterText = ref('')
const filterPrinted = ref('ALL')
const filterStatus = ref('ALL')

const printedOptions = [
  { label: 'All Printed Statuses', value: 'ALL' },
  { label: 'Printed Only', value: 'PRINTED' },
  { label: 'Not Printed Only', value: 'UNPRINTED' },
]

const statusOptions = [
  { label: 'All Statuses', value: 'ALL' },
  { label: 'Available', value: 'AVAILABLE' },
  { label: 'Used', value: 'USED' },
]

const selected = ref<ThriftBarcode[]>([])

// Columns Definitions
const columns = [
  { name: 'barcode_id', label: 'Barcode ID', field: 'barcode_id', align: 'left' as const, sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const, sortable: true },
  { name: 'is_printed', label: 'Printed', field: 'is_printed', align: 'center' as const, sortable: true },
  { name: 'inserted_by', label: 'Generated By', field: 'inserted_by', align: 'left' as const, sortable: true },
  { name: 'created_at', label: 'Created At', field: 'created_at', align: 'left' as const, sortable: true },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' as const },
]

// Year Calculation
const currentYear = computed(() => new Date().getFullYear().toString().slice(-2))

// Inventory Metrics
const prevCount = computed(() => barcodes.value.length)
const availableCount = computed(() => barcodes.value.filter(b => b.status === 'AVAILABLE').length)
const unprintedCount = computed(() => barcodes.value.filter(b => b.is_printed === 0).length)
const hasSufficientUnprinted = computed(() => unprintedCount.value >= printQty.value)

// Predict Next Sequence Range
const estimatedRange = computed(() => {
  const yr = currentYear.value
  const yearMatch = new RegExp(`^(\\d{2}-)?[A-Z]{2}-${yr}-\\d{6}$`)
  const matching = barcodes.value.filter(b => yearMatch.test(b.barcode_id))
  
  let prefix = 'AA'
  let startSeq = 1

  if (matching.length > 0) {
    const latest = [...matching].sort((a, b) => b.barcode_id.localeCompare(a.barcode_id))[0]
    if (latest) {
      const parts = latest.barcode_id.split('-')
      if (parts.length === 4) {
        prefix = parts[1] || 'AA'
        startSeq = parseInt(parts[3] || '0', 10) + 1
      } else {
        prefix = parts[0] || 'AA'
        startSeq = parseInt(parts[2] || '0', 10) + 1
      }
      
      if (startSeq > 999999) {
        // Increment prefix
        let c1 = prefix.charCodeAt(0)
        let c2 = prefix.charCodeAt(1)
        c2++
        if (c2 > 90) {
          c2 = 65
          c1++
        }
        prefix = String.fromCharCode(c1) + String.fromCharCode(c2)
        startSeq = 1
      }
    }
  }

  const startSeqStr = startSeq.toString().padStart(6, '0')
  const endSeqStr = (startSeq + genQuantity.value - 1).toString().padStart(6, '0')
  const tenantPrefix = authStore.tenantId ? authStore.tenantId.toString().padStart(2, '0') + '-' : ''

  return `${tenantPrefix}${prefix}-${yr}-${startSeqStr} ~ ${tenantPrefix}${prefix}-${yr}-${endSeqStr}`
})

// Filter logic
const filteredRows = computed(() => {
  return barcodes.value.filter((row) => {
    // 1. Text filter
    if (filterText.value) {
      const needle = filterText.value.toLowerCase()
      if (!row.barcode_id.toLowerCase().includes(needle)) {
        return false
      }
    }
    // 2. Printed filter
    if (filterPrinted.value === 'PRINTED' && row.is_printed !== 1) {
      return false
    }
    if (filterPrinted.value === 'UNPRINTED' && row.is_printed !== 0) {
      return false
    }
    // 3. Status filter
    if (filterStatus.value !== 'ALL' && row.status !== filterStatus.value) {
      return false
    }
    return true
  })
})

// Chip styling configurations
const activeChipStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
}
const inactiveChipStyle = {
  backgroundColor: '#f3dbdb',
  color: '#8b2f2f',
  border: '1px solid #d49f9f',
}
const printedChipStyle = {
  backgroundColor: '#c3dbe8',
  color: '#1f3e5d',
  border: '1px solid #9fbad4',
}
const unprintedChipStyle = {
  backgroundColor: '#e2e5eb',
  color: '#4f555d',
  border: '1px solid #c2c6cc',
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

const showConfirmGenDialog = () => {
  confirmGenDialog.value = true
}

const handleGenerate = async () => {
  if (!authStore.tenantId) return
  try {
    await barcodeStore.generateBarcodes({
      tenantId: authStore.tenantId,
      quantity: genQuantity.value,
      insertedBy: authStore.user?.email || 'System',
    })
    selected.value = []
  } catch (err) {
    // Error handled by store
  }
}

const onPreviewBarcode = (barcode: ThriftBarcode) => {
  previewBarcode.value = barcode
  previewDialog.value = true
}

const onClickPrint = () => {
  printDialog.value = true
}

const confirmSelectedPrint = () => {
  const ids = selected.value.map(s => s.id).join(',')
  printDialog.value = false
  void router.push({
    name: 'thrift-barcodes-print-preview',
    query: { ids }
  })
}

const confirmBulkPrint = () => {
  const unprintedList = barcodes.value.filter(b => b.is_printed === 0)
  const toPrint = unprintedList.slice(0, printQty.value)
  const ids = toPrint.map(b => b.id).join(',')
  printDialog.value = false
  void router.push({
    name: 'thrift-barcodes-print-preview',
    query: { ids }
  })
}

const onMarkPrinted = async () => {
  if (selected.value.length === 0 || !authStore.tenantId) return
  const ids = selected.value.map(s => s.id)
  try {
    await barcodeStore.markBarcodesPrinted(ids, authStore.tenantId)
    selected.value = []
  } catch (err) {
    // Handled by store
  }
}

onMounted(() => {
  if (authStore.tenantId) {
    void barcodeStore.fetchBarcodes(authStore.tenantId)
  }
})
</script>

<style scoped>
.barcode-list-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
