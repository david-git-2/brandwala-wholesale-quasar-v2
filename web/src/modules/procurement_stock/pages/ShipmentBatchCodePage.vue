<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="loading" class="col row justify-center items-center">
      <q-spinner color="primary" size="3em" />
    </div>

    <q-banner v-else-if="error" class="bw-status-banner bg-negative text-white q-ma-xs shrink-0">
      {{ error }}
    </q-banner>

    <template v-else-if="listId && parentTenantId">
      <BatchCodeListHeaderBar
        :list-id="listId"
        :parent-tenant-id="parentTenantId"
        show-back
        class="q-mb-xs"
        @back="goBack"
        @updated="onHeaderUpdated"
      />
      <ShipmentBatchCodeGrid class="col" :list-id="listId" />
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useQueryClient } from '@tanstack/vue-query';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import BatchCodeListHeaderBar from '../components/BatchCodeListHeaderBar.vue';
import ShipmentBatchCodeGrid from '../components/ShipmentBatchCodeGrid.vue';
import { useCreateBatchCodeListMutation } from '../composables/useBatchCodeMutations';
import { batchCodeRepository, type BatchCodeListRow } from '../repositories/batchCodeRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const shipmentStore = useGlobalShipmentStore();
const queryClient = useQueryClient();
const createListMutation = useCreateBatchCodeListMutation();

const shipmentId = computed(() => Number(route.params.id));
const loading = ref(true);
const error = ref<string | null>(null);
const listId = ref<number | null>(null);
const parentTenantId = ref<number | null>(null);
const listMeta = ref<BatchCodeListRow | null>(null);

const resolveParentTenantId = (): number => {
  const currentTenant =
    tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
  const tenantId = currentTenant?.parent_id ?? authStore.tenantId;
  if (!tenantId) throw new Error('No tenant found');
  return tenantId;
};

const seedListCache = (row: BatchCodeListRow) => {
  queryClient.setQueryData(procurementStockQueryKeys.batchCodeList(row.id), row);
  if (row.shipment_id) {
    queryClient.setQueryData(procurementStockQueryKeys.batchCodeListByShipment(row.shipment_id), row);
  }
};

const onHeaderUpdated = (row: BatchCodeListRow) => {
  listMeta.value = row;
};

const ensureList = async () => {
  loading.value = true;
  error.value = null;
  try {
    parentTenantId.value = resolveParentTenantId();
    await shipmentStore.fetchShipmentDetails(shipmentId.value);
    const shipment = shipmentStore.currentShipment;
    if (!shipment) {
      error.value = 'Shipment not found.';
      return;
    }
    const existing = await batchCodeRepository.getByShipmentId(shipmentId.value);
    if (existing) {
      const full = await batchCodeRepository.getById(existing.id);
      if (full) {
        seedListCache(full);
        listMeta.value = full;
        listId.value = full.id;
        return;
      }
    }

    const created = await createListMutation.mutateAsync({
      parentTenantId: parentTenantId.value,
      payload: {
        parent_tenant_id: parentTenantId.value,
        shipment_id: shipmentId.value,
      },
      relations: {
        shipment: {
          id: shipment.id,
          name: shipment.name,
          tenant_shipment_id: shipment.tenant_shipment_id ?? null,
        },
      },
    });
    listId.value = created.id;
    seedListCache({
      ...created,
      shipment: {
        id: shipment.id,
        name: shipment.name,
        tenant_shipment_id: shipment.tenant_shipment_id ?? null,
      },
      batch_code_items: [{ count: 0 }],
    });
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to open batch code list.';
  } finally {
    loading.value = false;
  }
};

const goBack = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { tenantSlug, id: shipmentId.value },
    });
    return;
  }
  void router.push({
    name: 'app-procurement-shipment-details',
    params: { id: shipmentId.value },
  });
};

onMounted(() => {
  void ensureList();
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}
</style>
