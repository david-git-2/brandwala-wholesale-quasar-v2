<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="column no-wrap" style="width: 780px; max-width: 95vw; height: 80vh; max-height: 700px; border-radius: 12px">
      <!-- Modal Header -->
      <q-card-section class="row items-center justify-between q-py-sm q-px-md border-bottom bg-grey-1 flex-shrink-0">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="32px" color="blue-grey-1" text-color="blue-grey-8" icon="ph ph-archive-box" font-size="18px" />
          <div>
            <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
              <span>Archived Shipments</span>
              <q-badge color="blue-grey-2" text-color="blue-grey-9" rounded class="text-weight-bold q-ml-xs">
                {{ archivedList.length }}
              </q-badge>
            </div>
            <div class="text-caption text-grey-6 text-xxs">
              Restorable shipments or permanent purge for drafts & cancelled
            </div>
          </div>
        </div>

        <q-btn flat round dense icon="ph ph-x" color="grey-7" v-close-popup />
      </q-card-section>

      <!-- Search & Refresh Toolbar -->
      <q-card-section class="q-py-xs q-px-md border-bottom bg-white flex-shrink-0">
        <div class="row items-center justify-between q-gutter-x-sm">
          <q-input
            v-model="filterSearch"
            dense
            outlined
            rounded
            clearable
            placeholder="Search archived shipments..."
            class="col dense-search-input"
            style="max-width: 320px"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="15px" color="grey-6" />
            </template>
          </q-input>

          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            :loading="loading"
            class="text-xs"
            @click="loadArchivedShipments"
          />
        </div>
      </q-card-section>

      <!-- Content Area -->
      <q-card-section class="col q-pa-none overflow-hidden relative-position">
        <q-inner-loading :showing="loading" />

        <!-- Empty State -->
        <div
          v-if="!loading && filteredArchivedList.length === 0"
          class="column items-center justify-center full-height q-pa-lg text-center text-grey-6"
        >
          <q-icon name="ph ph-archive" size="48px" color="grey-4" class="q-mb-sm" />
          <div class="text-weight-bold text-body2 text-grey-8">No Archived Shipments Found</div>
          <div class="text-caption text-grey-5">
            {{ filterSearch ? 'No archived shipments match your search.' : 'All shipments are active.' }}
          </div>
        </div>

        <!-- Table View of Archived Shipments -->
        <q-scroll-area v-else class="full-height">
          <q-list separator dense class="q-py-none">
            <q-item
              v-for="shipment in filteredArchivedList"
              :key="shipment.id"
              class="q-py-sm q-px-md items-center hover-bg-grey"
            >
              <!-- ID & Icon -->
              <q-item-section avatar style="min-width: 42px">
                <span class="text-caption text-weight-bold font-mono text-grey-7">
                  #{{ (shipment as any).tenant_shipment_id || shipment.id }}
                </span>
              </q-item-section>

              <!-- Main Info: Name & Date -->
              <q-item-section>
                <div class="text-weight-bold text-body2 text-grey-9 ellipsis">
                  {{ shipment.name }}
                </div>
                <div class="text-caption text-grey-6 text-xxs row items-center q-gutter-x-xs">
                  <span>Archived {{ formatArchivedDate(shipment.archived_at) }}</span>
                  <span>·</span>
                  <span class="text-capitalize">{{ shipment.type }}</span>
                </div>
              </q-item-section>

              <!-- Status Badge -->
              <q-item-section side class="q-pr-sm">
                <q-chip
                  square
                  dense
                  :color="getStatusColor(shipment.status).bg"
                  :text-color="getStatusColor(shipment.status).text"
                  class="text-weight-bold text-uppercase text-xxs q-ma-none"
                  style="letter-spacing: 0.04em"
                >
                  {{ shipment.status }}
                </q-chip>
              </q-item-section>

              <!-- Action Buttons -->
              <q-item-section side>
                <div class="row items-center q-gutter-x-xs">
                  <!-- Restore / Unarchive Button -->
                  <q-btn
                    unelevated
                    dense
                    no-caps
                    size="sm"
                    color="primary"
                    icon="ph ph-arrow-counter-clockwise"
                    label="Restore"
                    class="q-px-xs rounded-sq-btn"
                    style="border-radius: 6px"
                    :loading="restoringId === shipment.id"
                    @click="confirmRestore(shipment)"
                  >
                    <q-tooltip>Restore shipment back to active list</q-tooltip>
                  </q-btn>

                  <!-- Permanent Delete Button (ONLY for draft and cancelled) -->
                  <q-btn
                    v-if="shipment.status === 'draft' || shipment.status === 'cancelled'"
                    flat
                    round
                    dense
                    size="sm"
                    color="negative"
                    icon="ph ph-trash"
                    :loading="purgingId === shipment.id"
                    @click="confirmPermanentDelete(shipment)"
                  >
                    <q-tooltip>Permanently delete this archived {{ shipment.status }} shipment</q-tooltip>
                  </q-btn>
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-scroll-area>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const $q = useQuasar();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();

const loading = ref(false);
const filterSearch = ref('');
const restoringId = ref<number | null>(null);
const purgingId = ref<number | null>(null);

const archivedList = computed(() => shipmentStore.archivedRows);

const filteredArchivedList = computed(() => {
  if (!filterSearch.value.trim()) return archivedList.value;
  const q = filterSearch.value.toLowerCase().trim();
  return archivedList.value.filter((s) => {
    const nameMatch = s.name.toLowerCase().includes(q);
    const idMatch = ((s as any).tenant_shipment_id || s.id).toString().includes(q);
    return nameMatch || idMatch;
  });
});

const loadArchivedShipments = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    await shipmentStore.fetchArchivedShipments(authStore.tenantId);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadArchivedShipments();
});

const formatArchivedDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '—';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return dateStr.split('T')[0] ?? '—';
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return { bg: 'grey-2', text: 'grey-9' };
    case 'in_transit':
      return { bg: 'blue-1', text: 'blue-9' };
    case 'received':
      return { bg: 'teal-1', text: 'teal-9' };
    case 'cancelled':
      return { bg: 'red-1', text: 'red-9' };
    default:
      return { bg: 'grey-2', text: 'grey-8' };
  }
};

const confirmRestore = (shipment: GlobalShipment) => {
  $q.dialog({
    title: 'Restore Shipment',
    message: `Are you sure you want to restore "${shipment.name}" (#${(shipment as any).tenant_shipment_id || shipment.id}) back to the active shipments list?`,
    cancel: {
      flat: true,
      label: 'Cancel',
      noCaps: true,
    },
    ok: {
      unelevated: true,
      color: 'primary',
      label: 'Restore',
      noCaps: true,
    },
  }).onOk(async () => {
    restoringId.value = shipment.id;
    try {
      await shipmentStore.unarchiveShipment(shipment.id);
      $q.notify({
        type: 'positive',
        message: `Shipment "${shipment.name}" restored successfully.`,
        timeout: 2000,
      });
      onDialogOK({ action: 'restored', id: shipment.id });
    } catch (err: unknown) {
      $q.notify({
        type: 'negative',
        message: (err as Error).message || 'Failed to restore shipment',
      });
    } finally {
      restoringId.value = null;
    }
  });
};

const confirmPermanentDelete = (shipment: GlobalShipment) => {
  $q.dialog({
    title: 'Permanently Delete Shipment',
    message: `This action CANNOT be undone. Are you sure you want to permanently delete archived ${shipment.status} shipment "${shipment.name}" (#${(shipment as any).tenant_shipment_id || shipment.id}) and all its associated items?`,
    color: 'negative',
    cancel: {
      flat: true,
      label: 'Cancel',
      noCaps: true,
    },
    ok: {
      unelevated: true,
      color: 'negative',
      label: 'Delete Permanently',
      noCaps: true,
    },
  }).onOk(async () => {
    purgingId.value = shipment.id;
    try {
      await shipmentStore.purgeArchivedShipment(shipment.id);
      $q.notify({
        type: 'positive',
        message: `Shipment "${shipment.name}" permanently deleted.`,
        timeout: 2000,
      });
      onDialogOK({ action: 'purged', id: shipment.id });
    } catch (err: unknown) {
      $q.notify({
        type: 'negative',
        message: (err as Error).message || 'Failed to permanently delete shipment',
      });
    } finally {
      purgingId.value = null;
    }
  });
};
</script>

<style scoped>
.dense-search-input :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
}
.dense-search-input :deep(.q-field__marginal) {
  height: 32px;
}
.dense-search-input :deep(input) {
  font-size: 13px;
}
.hover-bg-grey:hover {
  background-color: #f8fafc;
}
</style>
