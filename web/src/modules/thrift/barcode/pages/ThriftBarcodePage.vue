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
        <div class="text-subtitle2 text-weight-bold q-mb-md text-primary">
          Bulk Barcode Generator
        </div>
        <q-form @submit.prevent="showConfirmGenDialog" class="row q-col-gutter-md items-end">
          <div class="col-12 col-sm-6 text-grey-8">
            The system will automatically determine the next sequential prefix (starting from AA)
            and append the current year (e.g. {{ currentYear }}).
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
              :loading="generateMutation.isPending.value"
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
          :rows="barcodes"
          :columns="columns"
          row-key="id"
          selection="multiple"
          v-model:selected="selected"
          :loading="loading"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[50]"
          @request="onTableRequest"
        >
          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                class="status-chip"
                :style="props.value === 'AVAILABLE' ? activeChipStyle : inactiveChipStyle"
              >
                <span
                  class="status-dot"
                  :style="{ backgroundColor: props.value === 'AVAILABLE' ? '#2f8b5d' : '#a85b2f' }"
                />
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
                <span
                  class="status-dot"
                  :style="{ backgroundColor: props.value === 1 ? '#2f5b8b' : '#66758c' }"
                />
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
      <q-card style="min-width: 400px; border-radius: 12px">
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
            <div>
              • Total previously generated codes: <strong>{{ prevCount }}</strong>
            </div>
            <div>
              • Total available catalog codes: <strong>{{ availableCount }}</strong>
            </div>
            <div>
              • Total unprinted codes: <strong>{{ unprintedCount }}</strong>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pt-none">
          <q-btn flat label="Cancel" color="grey" v-close-popup />
          <q-btn
            unelevated
            label="Generate"
            color="primary"
            class="pill-btn"
            :loading="generateMutation.isPending.value"
            @click="handleGenerate"
            v-close-popup
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Print Setup Dialog -->
    <q-dialog v-model="printDialog" persistent>
      <q-card style="min-width: 450px; border-radius: 12px">
        <q-card-section class="bg-primary text-white q-py-sm">
          <div class="text-subtitle1 text-weight-bold">Print Setup</div>
        </q-card-section>

        <q-card-section class="q-py-md">
          <div class="q-pa-sm rounded-borders bg-blue-1 q-mb-md">
            <div class="text-caption text-grey-8 q-mb-xs">
              Only barcodes with <strong>Printed = No</strong> and
              <strong>Status = Available</strong> can go to print.
            </div>
            <div class="text-h6 text-weight-bold text-primary">
              {{ printableCount }} ready to print
            </div>
          </div>

          <!-- Option A: Print Selected checkboxes -->
          <div v-if="selected.length > 0" class="q-mb-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">
              Option 1: Print Selected Barcodes
            </div>
            <div class="text-body2 text-grey-7 q-mb-md">
              You currently have <strong>{{ selected.length }}</strong> barcodes selected in the
              table.
            </div>
            <q-btn
              color="secondary"
              no-caps
              label="Print Selected Only"
              icon="print"
              class="pill-btn"
              :disabled="selectedPrintableCount === 0"
              @click="confirmSelectedPrint"
            />
            <div
              v-if="selected.length > selectedPrintableCount"
              class="text-caption text-warning q-mt-xs"
            >
              {{ selected.length - selectedPrintableCount }} barcode(s) skipped (must be Not printed
              and Available).
            </div>
            <q-separator class="q-my-lg" />
          </div>

          <!-- Option B: Bulk print -->
          <div>
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">
              Bulk Print Barcodes
            </div>
            <div class="text-body2 text-grey-7 q-mb-md">
              Choose how many eligible barcodes to print. The system picks the first ones in
              sequence (Not printed + Available only).
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
                  :max="printableCount"
                  hide-bottom-space
                />
              </div>
              <div class="col-4 text-right text-caption text-grey-7">
                Ready to print: <strong>{{ printableCount }}</strong>
              </div>
            </div>

            <q-banner
              v-if="!hasSufficientForBulk"
              class="bg-warning text-dark q-mb-md"
              rounded
              dense
            >
              Insufficient barcodes. You requested {{ printQty }} but only
              {{ printableCount }} eligible barcodes (Not printed + Available) exist.
            </q-banner>

            <q-btn
              color="primary"
              no-caps
              label="Proceed to Print Preview"
              icon="navigate_next"
              class="pill-btn full-width"
              :disabled="!hasSufficientForBulk || printQty <= 0"
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
      <q-card style="min-width: 320px; text-align: center; border-radius: 14px">
        <q-card-section class="bg-grey-2 q-py-xs text-right">
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-lg">
          <div class="text-overline text-grey-7 q-mb-xs">THRIFT BARCODE PREVIEW</div>
          <div class="q-mb-md text-weight-bold text-subtitle1">
            {{ previewBarcode?.barcode_id }}
          </div>

          <div class="q-my-md q-px-md row justify-center">
            <div
              style="
                width: 100%;
                max-width: 240px;
                border: 1px solid #e0e0e0;
                padding: 12px;
                border-radius: 8px;
                background: #fff;
              "
            >
              <BarcodeRenderer
                v-if="previewBarcode"
                :value="previewBarcode.barcode_id"
                :display-value="false"
              />
            </div>
          </div>

          <div class="text-caption text-grey-8 q-mt-md">
            <span v-if="previewBarcode?.status === 'AVAILABLE'">Available</span>
            <span v-if="previewBarcode?.status === 'AVAILABLE' && previewBarcode?.is_printed === 0">
              ·
            </span>
            <span v-if="previewBarcode?.is_printed === 0">Not printed (No)</span>
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftBarcodesQuery, type BarcodeQueryParams } from '../composables/useThriftBarcodesQuery';
import { useGenerateBarcodesMutation } from '../composables/useThriftBarcodeMutations';
import { thriftBarcodeRepository } from '../repositories/thriftBarcodeRepository';
import BarcodeRenderer from '../components/BarcodeRenderer.vue';
import type { ThriftBarcode, ThriftBarcodeListMeta } from '../types';
import { isBarcodePrintEligible } from '../types';

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

// Generator State
const genQuantity = ref(50);
const qtyOptions = [50, 100, 150, 200, 300, 400, 500];

// Dialog state
const confirmGenDialog = ref(false);
const previewDialog = ref(false);
const previewBarcode = ref<ThriftBarcode | null>(null);
const printDialog = ref(false);
const printQty = ref(50);

// Filter & Pagination State
const filterText = ref('');
const filterPrinted = ref('ALL');
const filterStatus = ref('ALL');
const page = ref(1);
const pageSize = ref(50);

const printedOptions = [
  { label: 'All Printed Statuses', value: 'ALL' },
  { label: 'Printed Only', value: 'PRINTED' },
  { label: 'Not Printed Only', value: 'UNPRINTED' },
];

const statusOptions = [
  { label: 'All Statuses', value: 'ALL' },
  { label: 'Available', value: 'AVAILABLE' },
  { label: 'Used', value: 'USED' },
];

function mapPrintedFilter(value: string): number | null {
  if (value === 'PRINTED') return 1;
  if (value === 'UNPRINTED') return 0;
  return null;
}

function mapStatusFilter(value: string): string | null {
  return value === 'ALL' ? null : value;
}

const queryParams = computed<BarcodeQueryParams>(() => ({
  tenantId: authStore.tenantId ?? 0,
  page: page.value,
  pageSize: pageSize.value,
  search: filterText.value.trim() || undefined,
  isPrinted: mapPrintedFilter(filterPrinted.value),
  status: mapStatusFilter(filterStatus.value),
}));

const { data: barcodeData, isLoading: loading, error: queryError } = useThriftBarcodesQuery(queryParams);

const generateMutation = useGenerateBarcodesMutation();

const barcodes = computed(() => barcodeData.value?.data ?? []);
const meta = computed<ThriftBarcodeListMeta>(
  () =>
    barcodeData.value?.meta ?? {
      total: 0,
      page: 1,
      page_size: 50,
      total_pages: 0,
      unprinted_total: 0,
      available_total: 0,
      printable_total: 0,
      latest_current_year_barcode_id: null,
    },
);

const error = computed(() => (queryError.value as Error | null)?.message ?? null);

const tablePagination = computed(() => ({
  page: page.value,
  rowsPerPage: pageSize.value,
  rowsNumber: meta.value.total,
}));

const selected = ref<ThriftBarcode[]>([]);

const columns = [
  {
    name: 'barcode_id',
    label: 'Barcode ID',
    field: 'barcode_id',
    align: 'left' as const,
    sortable: false,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const, sortable: false },
  {
    name: 'is_printed',
    label: 'Printed',
    field: 'is_printed',
    align: 'center' as const,
    sortable: false,
  },
  {
    name: 'inserted_by',
    label: 'Generated By',
    field: 'inserted_by',
    align: 'left' as const,
    sortable: false,
  },
  {
    name: 'created_at',
    label: 'Created At',
    field: 'created_at',
    align: 'left' as const,
    sortable: false,
  },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' as const },
];

const currentYear = computed(() => new Date().getFullYear().toString().slice(-2));

const prevCount = computed(() => meta.value.total);
const availableCount = computed(() => meta.value.available_total);
const unprintedCount = computed(() => meta.value.unprinted_total);
const printableCount = computed(() => meta.value.printable_total);
const hasSufficientForBulk = computed(() => printableCount.value >= printQty.value);
const selectedPrintableCount = computed(() => selected.value.filter(isBarcodePrintEligible).length);

let searchDebounce: ReturnType<typeof setTimeout> | null = null;

watch([filterText, filterPrinted, filterStatus], () => {
  if (searchDebounce) clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    page.value = 1;
    selected.value = [];
  }, 300);
});

const onTableRequest = (props: { pagination: { page: number; rowsPerPage: number } }) => {
  page.value = props.pagination.page;
  selected.value = [];
};

const estimatedRange = computed(() => {
  const yr = currentYear.value;
  let prefix = 'AA';
  let startSeq = 1;
  const latest = meta.value.latest_current_year_barcode_id;

  if (latest) {
    const parts = latest.split('-');
    if (parts.length === 4) {
      prefix = parts[1] || 'AA';
      startSeq = parseInt(parts[3] || '0', 10) + 1;
    } else if (parts.length === 3) {
      prefix = parts[0] || 'AA';
      startSeq = parseInt(parts[2] || '0', 10) + 1;
    }

    if (startSeq > 999999) {
      let c1 = prefix.charCodeAt(0);
      let c2 = prefix.charCodeAt(1);
      c2++;
      if (c2 > 90) {
        c2 = 65;
        c1++;
      }
      prefix = String.fromCharCode(c1) + String.fromCharCode(c2);
      startSeq = 1;
    }
  }

  const startSeqStr = startSeq.toString().padStart(6, '0');
  const endSeqStr = (startSeq + genQuantity.value - 1).toString().padStart(6, '0');
  const tenantPrefix = authStore.tenantId
    ? authStore.tenantId.toString().padStart(2, '0') + '-'
    : '';

  return `${tenantPrefix}${prefix}-${yr}-${startSeqStr} ~ ${tenantPrefix}${prefix}-${yr}-${endSeqStr}`;
});

const activeChipStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
};
const inactiveChipStyle = {
  backgroundColor: '#f3dbdb',
  color: '#8b2f2f',
  border: '1px solid #d49f9f',
};
const printedChipStyle = {
  backgroundColor: '#c3dbe8',
  color: '#1f3e5d',
  border: '1px solid #9fbad4',
};
const unprintedChipStyle = {
  backgroundColor: '#e2e5eb',
  color: '#4f555d',
  border: '1px solid #c2c6cc',
};

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleString();
};

const showConfirmGenDialog = () => {
  confirmGenDialog.value = true;
};

const handleGenerate = async () => {
  if (!authStore.tenantId) return;
  try {
    await generateMutation.mutateAsync({
      tenantId: authStore.tenantId,
      quantity: genQuantity.value,
      insertedBy: authStore.user?.email || 'System',
    });
    selected.value = [];
    page.value = 1;
    $q.notify({
      type: 'positive',
      message: `Successfully generated ${genQuantity.value} barcodes.`,
    });
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Failed to generate barcodes',
    });
  }
};

const onPreviewBarcode = (barcode: ThriftBarcode) => {
  previewBarcode.value = barcode;
  previewDialog.value = true;
};

const onClickPrint = () => {
  printDialog.value = true;
};

const confirmSelectedPrint = () => {
  const printable = selected.value.filter(isBarcodePrintEligible);

  if (printable.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'No eligible barcodes in selection (must be Not printed and Available).',
    });
    return;
  }

  if (printable.length < selected.value.length) {
    $q.notify({
      type: 'info',
      message: `${selected.value.length - printable.length} barcode(s) skipped (must be Not printed and Available).`,
    });
  }

  const ids = printable.map((s) => s.id).join(',');
  printDialog.value = false;
  void router.push({
    name: 'thrift-barcodes-print-preview',
    query: { ids },
  });
};

const confirmBulkPrint = async () => {
  if (!authStore.tenantId) return;
  try {
    const result = await thriftBarcodeRepository.fetchBarcodesPaginated({
      tenantId: authStore.tenantId,
      page: 1,
      pageSize: printQty.value,
      isPrinted: 0,
      status: 'AVAILABLE',
    });

    const toPrint = result.data;

    if (toPrint.length === 0) {
      $q.notify({
        type: 'warning',
        message: 'No eligible barcodes to print (Not printed + Available).',
      });
      return;
    }

    const ids = toPrint.map((b) => b.id).join(',');
    printDialog.value = false;
    void router.push({
      name: 'thrift-barcodes-print-preview',
      query: { ids },
    });
  } catch {
    $q.notify({ type: 'negative', message: 'Failed to load barcodes for printing.' });
  }
};
</script>

<style scoped>
.barcode-list-page {
  background: transparent;
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
