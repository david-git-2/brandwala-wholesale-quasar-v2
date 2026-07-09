<template>
  <q-page class="q-pa-md costing-details-page theme-app">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack costing-page">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="text-h6 text-weight-bold">Costing file details</div>
              <div class="text-caption text-grey-8">{{ subtitle }}</div>
            </div>
            <div class="col-auto row items-center q-gutter-sm">
              <q-btn
                outline
                color="primary"
                icon="view_column"
                label="Columns"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
              >
                <q-menu>
                  <q-list style="min-width: 240px">
                    <q-item>
                      <q-item-section>
                        <div class="text-subtitle2">Show Columns</div>
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section>
                        <q-checkbox
                          v-model="allSelectableColumnsSelected"
                          label="Select / Deselect All"
                        />
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section>
                        <q-option-group
                          v-model="visibleColumns"
                          type="checkbox"
                          :options="columnSelectorOptions"
                        />
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
              <q-chip
                v-if="selectedFile"
                dense
                square
                :style="statusChipStyle(selectedFile.status)"
                class="costing-status-chip"
              >
                <span
                  class="status-dot"
                  :style="{ backgroundColor: statusDotColor(selectedFile.status) }"
                />
                {{ selectedFile.status }}
              </q-chip>
              <q-btn
                outline
                color="primary"
                label="Add item"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                :disable="!canEditFile"
                @click="addItemDialogOpen = true"
              />
              <q-btn
                color="primary"
                unelevated
                label="Send to review"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                :disable="!canSendToReview"
                :loading="savingStatus"
                @click="handleSendToReview"
              />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-card v-if="loadingPage || !selectedFile" flat class="floating-surface shadow-1">
        <q-card-section class="text-grey-7"> Loading costing file details... </q-card-section>
      </q-card>

      <template v-else>
        <div v-if="productRows.length" class="costing-page__body">
          <q-card flat class="floating-surface shadow-1">
            <q-table
              flat
              row-key="id"
              :rows="productRows"
              :columns="visibleProductColumns"
              :pagination="{ rowsPerPage: 0 }"
              hide-bottom
              class="costing-page__table"
            >
              <template #body-cell-sl="props">
                <q-td :props="props" class="costing-page__sl-cell">
                  {{ props.row.sl }}
                </q-td>
              </template>

              <template #body-cell-image="props">
                <q-td :props="props">
                  <div class="costing-page__image-cell">
                    <q-img
                      v-if="props.row.imageUrl"
                      :src="toExternalUrl(props.row.imageUrl)"
                      fit="contain"
                      class="costing-page__image"
                    />
                    <div v-else class="costing-page__image costing-page__image--placeholder">
                      No image
                    </div>
                  </div>
                </q-td>
              </template>

              <template #body-cell-websiteUrl="props">
                <q-td :props="props" class="costing-page__link-cell">
                  <a
                    class="costing-page__link"
                    :href="toExternalUrl(props.row.websiteUrl)"
                    :title="props.row.websiteUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {{ props.row.websiteUrl }}
                  </a>
                </q-td>
              </template>

              <template #body-cell-extraInformation1="props">
                <q-td :props="props">
                  <div v-html="props.value" class="costing-table__rich-text-cell" />
                </q-td>
              </template>

              <template #body-cell-extraInformation2="props">
                <q-td :props="props">
                  <div v-html="props.value" class="costing-table__rich-text-cell" />
                </q-td>
              </template>

              <template #body-cell-name="props">
                <q-td :props="props" class="costing-page__name-cell">
                  <span class="costing-page__name-text" :title="props.row.name">
                    {{ props.row.name }}
                  </span>
                </q-td>
              </template>

              <template #body-cell-priceInWebGbp="props">
                <q-td :props="props" class="costing-page__numeric-cell">
                  {{ props.row.priceInWebGbp }}
                </q-td>
              </template>

              <template #body-cell-productWeight="props">
                <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
                  {{ props.row.productWeight }}
                </q-td>
              </template>

              <template #body-cell-packageWeight="props">
                <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
                  {{ props.row.packageWeight }}
                </q-td>
              </template>

              <template #body-cell-quantity="props">
                <q-td :props="props" class="costing-page__numeric-cell">
                  {{ props.row.quantity }}
                </q-td>
              </template>

              <template #body-cell-actions="props">
                <q-td :props="props" auto-width>
                  <q-btn
                    flat
                    dense
                    round
                    color="primary"
                    icon="o_edit"
                    :disable="!canEditFile"
                    @click="openEditDialog(props.row.id)"
                  />
                </q-td>
              </template>

              <template #bottom-row>
                <q-tr class="costing-page__totals-row">
                  <q-td
                    v-for="column in visibleProductColumns"
                    :key="column.name"
                    class="costing-page__totals-cell"
                    :class="getProductTotalsCellClass(column.name)"
                  >
                    {{ getProductTotalsValue(column.name) }}
                  </q-td>
                </q-tr>
              </template>
            </q-table>
          </q-card>
        </div>

        <q-card v-else flat class="floating-surface shadow-1">
          <q-card-section class="text-center">
            <div class="text-subtitle1">No items yet</div>
            <div class="text-body2 text-grey-7 q-mt-sm">
              Add the first item for this costing file.
            </div>
          </q-card-section>
        </q-card>
      </template>

      <AddCostingFileItemDialog
        v-model="addItemDialogOpen"
        :loading="creatingItem"
        @save="handleCreateItem"
      />

      <StaffCostingFileItemEditDialog
        v-model="editDialogOpen"
        :item="editingItem"
        :loading="savingItemId === editingItem?.id"
        @save="handleSaveItem"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import AddCostingFileItemDialog from 'src/modules/costingFile/components/AddCostingFileItemDialog.vue';
import StaffCostingFileItemEditDialog from 'src/modules/costingFile/components/StaffCostingFileItemEditDialog.vue';
import {
  buildAdminProductRows,
  summarizeAdminProductRows,
} from 'src/modules/costingFile/composables/useCostingFileDetailRows';
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore';
import type {
  CostingFileDetails,
  CostingFileItem,
  CostingFileStatus,
} from 'src/modules/costingFile/types';

const route = useRoute();
const router = useRouter();
const costingFileStore = useCostingFileStore();
const selectedFile = computed<CostingFileDetails | null>(() => costingFileStore.selectedItem);
const costingFileItems = computed<CostingFileItem[]>(() => costingFileStore.costingFileItems);
const detailsLoading = computed(() => costingFileStore.detailsLoading);
const itemLoading = computed(() => costingFileStore.itemLoading);

const addItemDialogOpen = ref(false);
const editDialogOpen = ref(false);
const initialLoading = ref(true);
const creatingItem = ref(false);
const savingItemId = ref<number | null>(null);
const savingStatus = ref(false);
const editingItemId = ref<number | null>(null);

const editableStatuses: CostingFileStatus[] = ['customer_submitted'];

const formatFixed = (value: number | null | undefined) =>
  value == null ? '' : Number(value).toFixed(2);

const formatWhole = (value: number | null | undefined) =>
  value == null ? '' : String(Math.round(Number(value)));

const productRows = computed(() => buildAdminProductRows(costingFileItems.value));
const productTotals = computed(() => summarizeAdminProductRows(productRows.value));
const editingItem = computed<CostingFileItem | null>(
  () => costingFileItems.value.find((item) => item.id === editingItemId.value) ?? null,
);

const productColumns = [
  {
    name: 'actions',
    label: '',
    field: 'actions',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
  },
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'left' as const,
    style: 'width: 60px; min-width: 60px;',
    headerStyle: 'width: 60px; min-width: 60px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--sl',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--sl',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'left' as const,
    style: 'width: 108px; min-width: 108px;',
    headerStyle: 'width: 108px; min-width: 108px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--image',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--image',
  },

  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left' as const,
    style: 'min-width: 280px;',
    headerStyle: 'min-width: 280px;',
  },
  {
    name: 'itemType',
    label: 'Type',
    field: 'itemType',
    align: 'left' as const,
    style: 'width: 110px; min-width: 110px;',
    headerStyle: 'width: 110px; min-width: 110px;',
  },
  {
    name: 'quantity',
    label: 'Qty',
    field: 'quantity',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
  },
  {
    name: 'websiteUrl',
    label: 'Web link',
    field: 'websiteUrl',
    align: 'left' as const,
    style: 'width: 220px; min-width: 220px;',
    headerStyle: 'width: 220px; min-width: 220px;',
  },
  {
    name: 'size',
    label: 'Size',
    field: 'size',
    align: 'left' as const,
    style: 'width: 96px; min-width: 96px;',
    headerStyle: 'width: 96px; min-width: 96px;',
  },
  {
    name: 'color',
    label: 'Color',
    field: 'color',
    align: 'left' as const,
    style: 'width: 96px; min-width: 96px;',
    headerStyle: 'width: 96px; min-width: 96px;',
  },
  {
    name: 'extraInformation1',
    label: 'Extra info 1',
    field: 'extraInformation1',
    align: 'left' as const,
    style: 'width: 180px; min-width: 180px;',
    headerStyle: 'width: 180px; min-width: 180px;',
  },
  {
    name: 'extraInformation2',
    label: 'Extra info 2',
    field: 'extraInformation2',
    align: 'left' as const,
    style: 'width: 180px; min-width: 180px;',
    headerStyle: 'width: 180px; min-width: 180px;',
  },
  {
    name: 'priceInWebGbp',
    label: 'Web price (GBP)',
    field: 'priceInWebGbp',
    align: 'left' as const,
    style: 'width: 110px; min-width: 110px;',
    headerStyle: 'width: 110px; min-width: 110px;',
  },
  {
    name: 'productWeight',
    label: 'Product wt',
    field: 'productWeight',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
  },
  {
    name: 'packageWeight',
    label: 'Package wt',
    field: 'packageWeight',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
  },
];

const alwaysVisibleColumns = ['actions', 'sl', 'image', 'name'] as const;
const selectableColumns = productColumns
  .map((column) => column.name)
  .filter((name) => !alwaysVisibleColumns.includes(name as (typeof alwaysVisibleColumns)[number]));
const visibleColumns = ref<string[]>([...alwaysVisibleColumns, ...selectableColumns]);
const columnSelectorOptions = productColumns
  .filter((column) => selectableColumns.includes(column.name))
  .map((column) => ({ label: column.label, value: column.name }));
const allSelectableColumnsSelected = computed({
  get: () => selectableColumns.every((name) => visibleColumns.value.includes(name)),
  set: (checked: boolean) => {
    visibleColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumns]
      : [...alwaysVisibleColumns];
  },
});
const visibleProductColumns = computed(() =>
  productColumns.filter((column) => visibleColumns.value.includes(column.name)),
);

const subtitle = computed(() =>
  selectedFile.value
    ? `Staff can add items and send this file to review.`
    : 'Loading costing file details.',
);

const loadingPage = computed(() => detailsLoading.value || itemLoading.value);
const canEditFile = computed(() =>
  Boolean(selectedFile.value && editableStatuses.includes(selectedFile.value.status)),
);
const canSendToReview = computed(() =>
  Boolean(selectedFile.value && editableStatuses.includes(selectedFile.value.status)),
);

const getProductTotalsValue = (columnName: string) => {
  switch (columnName) {
    case 'actions':
    case 'image':
      return '';
    case 'sl':
      return 'Total';
    case 'name':
      return `${productRows.value.length} Items`;
    case 'priceInWebGbp':
      return formatFixed(productTotals.value.priceInWebGbp);
    case 'productWeight':
      return formatWhole(productTotals.value.productWeight);
    case 'packageWeight':
      return formatWhole(productTotals.value.packageWeight);
    case 'quantity':
      return formatWhole(productTotals.value.quantity);
    default:
      return '';
  }
};

const getProductTotalsCellClass = (columnName: string) =>
  columnName === 'priceInWebGbp' ? 'costing-page__tone-indigo' : '';

const statusChipStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending';
  if (value === 'draft') {
    return {
      backgroundColor: '#f1f5f9',
      color: '#475569',
      border: '1px solid #cbd5e1',
    };
  }
  if (value === 'customer_submitted') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    };
  }
  if (value === 'in_review') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    };
  }
  if (value === 'accepted') {
    return {
      backgroundColor: '#d1fae5',
      color: '#065f46',
      border: '1px solid #a7f3d0',
    };
  }
  if (value === 'po_placed') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    };
  }
  return {
    backgroundColor: '#f1f5f9',
    color: '#475569',
    border: '1px solid #cbd5e1',
  };
};
const statusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending';
  if (value === 'draft') return '#64748b';
  if (value === 'customer_submitted') return '#3f51b5';
  if (value === 'in_review') return '#9a6a24';
  if (value === 'offered') return '#3f67b3';
  if (value === 'accepted') return '#059669';
  if (value === 'po_placed') return '#2f8b5d';
  if (value === 'cancelled') return '#a64c62';
  return '#64748b';
};

const toExternalUrl = (value: string) => (/^https?:\/\//i.test(value) ? value : `https://${value}`);

const loadFile = async () => {
  const fileId = Number(route.params.id);

  if (!Number.isFinite(fileId) || fileId <= 0) {
    await router.replace({ name: 'staff-costing-file-page' });
    return;
  }

  costingFileStore.clearSelectedItem();

  const result = await costingFileStore.fetchCostingFileWithItems(fileId);

  if (!result.success || !result.data) {
    await router.replace({ name: 'staff-costing-file-page' });
    return;
  }

  if (!editableStatuses.includes(result.data.status)) {
    await router.replace({ name: 'staff-costing-file-page' });
  }
};

const openEditDialog = (itemId: number) => {
  editingItemId.value = itemId;
  editDialogOpen.value = true;
};

const handleCreateItem = async (payload: {
  websiteUrl: string;
  quantity: number;
  name: string;
  itemType: string | null;
  size: string | null;
  color: string | null;
  extraInformation1: string | null;
  extraInformation2: string | null;
  imageUrl: string;
  productWeight: number;
  packageWeight: number;
  priceInWebGbp: number;
  deliveryPriceGbp: number;
}) => {
  if (!selectedFile.value || !canEditFile.value) {
    return;
  }

  creatingItem.value = true;
  try {
    const result = await costingFileStore.createCostingFileItem({
      costingFileId: selectedFile.value.id,
      websiteUrl: payload.websiteUrl,
      quantity: payload.quantity,
      name: payload.name,
      itemType: payload.itemType,
      size: payload.size,
      color: payload.color,
      extraInformation1: payload.extraInformation1,
      extraInformation2: payload.extraInformation2,
      imageUrl: payload.imageUrl,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      priceInWebGbp: payload.priceInWebGbp,
      deliveryPriceGbp: payload.deliveryPriceGbp,
      status: 'pending',
    });

    if (result.success) {
      addItemDialogOpen.value = false;
    }
  } finally {
    creatingItem.value = false;
  }
};

const handleSaveItem = async (payload: {
  id: number;
  name: string;
  itemType: string | null;
  imageUrl: string;
  productWeight: number;
  packageWeight: number;
  priceInWebGbp: number;
  deliveryPriceGbp: number;
}) => {
  if (!selectedFile.value || !canEditFile.value) {
    return;
  }

  savingItemId.value = payload.id;
  try {
    const result = await costingFileStore.updateCostingFileItemEnrichment({
      id: payload.id,
      name: payload.name,
      itemType: payload.itemType,
      imageUrl: payload.imageUrl,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      priceInWebGbp: payload.priceInWebGbp,
      deliveryPriceGbp: payload.deliveryPriceGbp,
    });

    if (result.success) {
      editDialogOpen.value = false;
    }
  } finally {
    savingItemId.value = null;
  }
};

const handleSendToReview = async () => {
  if (!selectedFile.value || !canSendToReview.value) {
    return;
  }

  savingStatus.value = true;
  try {
    const result = await costingFileStore.updateCostingFileStatus({
      id: selectedFile.value.id,
      status: 'in_review',
    });

    if (result.success) {
      await router.replace({ name: 'staff-costing-file-page' });
    }
  } finally {
    savingStatus.value = false;
  }
};

watch(
  () => route.params.id,
  async () => {
    try {
      addItemDialogOpen.value = false;
      editDialogOpen.value = false;
      editingItemId.value = null;
      await loadFile();
    } finally {
      initialLoading.value = false;
    }
  },
  { immediate: true },
);

watch(editDialogOpen, (isOpen) => {
  if (!isOpen) {
    editingItemId.value = null;
  }
});
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
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

.costing-page__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.9rem 1rem;
}

.costing-page__heading {
  min-width: 0;
  flex: 1 1 auto;
}

.costing-page__toolbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.75rem;
  align-items: center;
}

.costing-page__summary {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  align-items: center;
  padding: 0.75rem 1rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.72);
}

.costing-page__summary-main {
  min-width: 0;
}

.costing-page__body {
  min-width: 0;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.costing-page__table :deep(.q-table th),
.costing-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__table :deep(.q-table th:nth-child(4)),
.costing-page__table :deep(.q-table td:nth-child(4)) {
  text-align: left;
}

.costing-page__table :deep(.q-table th:nth-child(5)),
.costing-page__table :deep(.q-table td:nth-child(5)) {
  text-align: left;
}

.costing-page__table :deep(.q-table th:last-child),
.costing-page__table :deep(.q-table td:last-child) {
  text-align: right;
}

.costing-page__table :deep(.costing-page__sticky-col) {
  position: sticky;
  background: var(--bw-theme-surface, #fff);
}

.costing-page__table :deep(td.costing-page__sticky-col) {
  z-index: 2;
}

.costing-page__table :deep(th.costing-page__sticky-col) {
  z-index: 3;
}

.costing-page__table :deep(.costing-page__sticky-col--sl) {
  left: 0;
}

.costing-page__table :deep(.costing-page__sticky-col--image) {
  left: 60px;
}

.costing-page__table :deep(td.costing-page__sticky-col--sl) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table :deep(td.costing-page__sticky-col--image) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__table :deep(th.costing-page__sticky-col--sl) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table :deep(th.costing-page__sticky-col--image) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__sl-cell {
  width: 60px;
  max-width: 60px;
  white-space: nowrap;
}

.costing-page__image-cell {
  width: 96px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.costing-page__image {
  display: block;
  width: 96px;
  height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-theme-surface);
}

.costing-page__image :deep(.q-img__image) {
  object-fit: contain !important;
  object-position: center;
}

.costing-page__image--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed var(--bw-theme-border);
  color: var(--bw-theme-muted);
  font-size: 0.75rem;
  text-align: center;
  padding: 0.5rem;
}

.costing-page__link-cell {
  width: 144px;
  max-width: 144px;
}

.costing-page__link {
  display: inline-block;
  max-width: 144px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--bw-theme-primary);
  text-decoration: none;
}

.costing-page__name-cell {
  width: 280px;
  max-width: 280px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 280px;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.costing-page__weight-cell {
  width: 72px;
  max-width: 72px;
  white-space: nowrap;
}

.costing-page__numeric-cell {
  font-weight: 700;
  font-size: 0.95rem;
  line-height: 1.35;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.costing-page :deep(.costing-page__tone-indigo) {
  background: #e6f4ea;
  color: #1f6a43;
}

.costing-page__totals-row {
  background: inherit;
}

.costing-page__totals-cell {
  font-weight: 700;
  text-align: center;
  vertical-align: middle;
}

@media (max-width: 900px) {
  .costing-page__header {
    flex-direction: column;
  }

  .costing-page__toolbar {
    justify-content: flex-start;
  }
}

@media (max-width: 599px) {
  .costing-page__image-cell {
    width: 72px;
  }

  .costing-page__image {
    width: 72px;
    height: 72px;
  }
}
</style>
