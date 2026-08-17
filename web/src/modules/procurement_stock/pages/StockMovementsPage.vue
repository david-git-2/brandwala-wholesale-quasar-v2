<template>
  <q-page class="bw-page page-fixed-layout q-pa-md">
    <section class="bw-page__stack" style="min-width: 0; flex: 1 1 0%; display: flex; flex-direction: column; overflow: hidden;">
      <AppPageHeader
        dense
        eyebrow="Procurement & Stock"
        title="Movements"
        subtitle="Move stock between shelves or sellable / held / unsellable."
        class="q-mb-sm"
      >
        <template #action>
          <q-btn
            v-if="movements.length > 0"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="New movement"
            style="border-radius: 8px;"
            @click="openCreateDialog"
          />
        </template>
      </AppPageHeader>

      <q-banner v-if="error" class="bw-status-banner bg-negative text-white q-mb-md">
        {{ error }}
      </q-banner>

      <!-- Search Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          outlined
          rounded
          dense
          clearable
          class="col-grow"
          placeholder="Search by movement no, type or notes..."
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>
      </div>

      <PageInitialLoader v-if="loading && !movements.length" />

      <!-- Fixed Table Layout -->
      <div v-else class="table-fixed-wrap">
        <q-card flat bordered class="q-pa-none overflow-hidden full-height" style="min-width: 0; display: flex; flex-direction: column;">
          <q-table
            flat
            :rows="filteredMovements"
            :columns="columns"
            row-key="id"
            :loading="loading"
            :rows-per-page-options="[10, 20, 50]"
            @row-click="(_, row) => openDetail(row.id)"
          >
            <template #body-cell-movement_type="props">
              <q-td :props="props" class="cursor-pointer text-weight-medium text-grey-9">
                <span class="text-capitalize">{{ formatMovementType(props.row.movement_type) }}</span>
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td :props="props" class="cursor-pointer text-center">
                <q-chip
                  dense
                  square
                  :color="props.row.is_posted ? 'green-1' : 'amber-1'"
                  :text-color="props.row.is_posted ? 'green-9' : 'amber-9'"
                  class="text-weight-bold"
                >
                  <q-icon
                    :name="props.row.is_posted ? 'ph ph-check-circle' : 'ph ph-note-pencil'"
                    size="14px"
                    class="q-mr-xs"
                  />
                  {{ props.row.is_posted ? 'Posted' : 'Draft' }}
                </q-chip>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <q-btn
                  flat
                  dense
                  no-caps
                  color="primary"
                  icon="ph ph-eye"
                  label="View"
                  class="text-weight-bold"
                  @click.stop="openDetail(props.row.id)"
                />
              </q-td>
            </template>

            <template #no-data>
              <div class="full-width text-center text-grey-7 q-py-lg">
                <q-icon name="ph ph-arrows-left-right" size="48px" class="q-mb-sm text-grey-4" />
                <div class="text-subtitle1 text-weight-medium q-mb-xs">No movements yet</div>
                <div class="text-body2 q-mb-md">
                  Move stock between shelves or change sellable / held / unsellable.
                </div>
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-plus"
                  label="New movement"
                  style="border-radius: 8px;"
                  @click="openCreateDialog"
                />
              </div>
            </template>
          </q-table>
        </q-card>
      </div>
    </section>

    <!-- Dialogs -->
    <StockMovementFormDialog
      v-model="createDialogOpen"
      :tenant-id="authStore.tenantId"
      @created="onMovementCreated"
    />
    <StockMovementDetailDialog
      v-model="detailDialogOpen"
      :movement-id="selectedMovementId"
      @posted="loadMovements"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { date, type QTableColumn } from 'quasar';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { stockMovementRepository, type StockMovement } from '../repositories/stockMovementRepository';
import StockMovementFormDialog from '../components/StockMovementFormDialog.vue';
import StockMovementDetailDialog from '../components/StockMovementDetailDialog.vue';

const authStore = useAuthStore();
const loading = ref(false);
const error = ref<string | null>(null);
const movements = ref<StockMovement[]>([]);
const searchText = ref('');

const createDialogOpen = ref(false);
const detailDialogOpen = ref(false);
const selectedMovementId = ref<number | null>(null);

const filteredMovements = computed(() => {
  if (!searchText.value.trim()) return movements.value;
  const q = searchText.value.toLowerCase().trim();
  return movements.value.filter(
    (m) =>
      m.movement_no.toLowerCase().includes(q) ||
      m.movement_type.toLowerCase().includes(q) ||
      (m.notes && m.notes.toLowerCase().includes(q)),
  );
});

const columns: QTableColumn<StockMovement>[] = [
  { name: 'movement_no', label: 'No.', field: 'movement_no', align: 'left', sortable: true },
  { name: 'movement_type', label: 'Type', field: 'movement_type', align: 'left' },
  { name: 'status', label: 'Status', field: 'is_posted', align: 'center' },
  {
    name: 'created_at',
    label: 'Created',
    field: 'created_at',
    align: 'left',
    format: (v) => (v ? date.formatDate(v, 'DD MMM YYYY HH:mm') : '—'),
  },
  {
    name: 'posted_at',
    label: 'Posted',
    field: 'posted_at',
    align: 'left',
    format: (v) => (v ? date.formatDate(v, 'DD MMM YYYY HH:mm') : '—'),
  },
  {
    name: 'notes',
    label: 'Notes',
    field: 'notes',
    align: 'left',
    format: (v) => v || '—',
  },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const formatMovementType = (type: string) => type.replace(/_/g, ' ');

const loadMovements = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  error.value = null;
  try {
    movements.value = await stockMovementRepository.listMovements(authStore.tenantId);
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load movements';
  } finally {
    loading.value = false;
  }
};

const openCreateDialog = () => {
  createDialogOpen.value = true;
};

const openDetail = (id: number) => {
  selectedMovementId.value = id;
  detailDialogOpen.value = true;
};

const onMovementCreated = async (id: number) => {
  await loadMovements();
  openDetail(id);
};

onMounted(() => {
  void loadMovements();
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.table-fixed-wrap {
  flex: 1 1 0%;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

:deep(.q-table__card) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.q-table__container) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.q-table__middle) {
  flex: 1 1 0%;
  overflow-y: auto;
}

:deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc !important;
}
</style>
