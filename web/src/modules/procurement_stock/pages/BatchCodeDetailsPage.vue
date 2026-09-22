<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <BatchCodeListHeaderBar
      v-if="parentTenantId && listId"
      :list-id="listId"
      :parent-tenant-id="parentTenantId"
      show-back
      show-delete
      class="q-mb-xs"
      @back="goBack"
      @deleted="goBack"
      @updated="onHeaderUpdated"
      @load-error="onHeaderLoadError"
    />

    <div v-if="pageLoading" class="col row justify-center items-center">
      <q-spinner color="primary" size="3em" />
    </div>

    <q-banner v-else-if="pageError" class="bw-status-banner bg-negative text-white q-ma-xs shrink-0">
      {{ pageError }}
    </q-banner>

    <ShipmentBatchCodeGrid v-else-if="listId" class="col" :list-id="listId" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import BatchCodeListHeaderBar from '../components/BatchCodeListHeaderBar.vue';
import ShipmentBatchCodeGrid from '../components/ShipmentBatchCodeGrid.vue';
import type { BatchCodeListRow } from '../repositories/batchCodeRepository';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const listId = computed(() => Number(route.params.listId));
const pageLoading = ref(true);
const pageError = ref<string | null>(null);
const parentTenantId = ref<number | null>(null);
const listMeta = ref<BatchCodeListRow | null>(null);

const resolveParentTenantId = (): number => {
  const currentTenant =
    tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
  const tenantId = currentTenant?.parent_id ?? authStore.tenantId;
  if (!tenantId) throw new Error('No tenant found');
  return tenantId;
};

onMounted(() => {
  try {
    parentTenantId.value = resolveParentTenantId();
    pageLoading.value = false;
  } catch (err: unknown) {
    pageError.value = (err as Error).message || 'Failed to load batch list.';
    pageLoading.value = false;
  }
});

const onHeaderUpdated = (row: BatchCodeListRow) => {
  listMeta.value = row;
};

const onHeaderLoadError = (message: string) => {
  pageError.value = message;
};

const goBack = () => {
  if (route.query.from === 'list') {
    const tenantSlug = route.params.tenantSlug;
    if (tenantSlug) {
      void router.push({ name: 'app-procurement-batch-code-list', params: { tenantSlug } });
      return;
    }
    void router.push({ name: 'app-procurement-batch-code-list' });
    return;
  }

  if (listMeta.value?.shipment_id) {
    const tenantSlug = route.params.tenantSlug;
    if (tenantSlug) {
      void router.push({
        name: 'app-procurement-shipment-details',
        params: { tenantSlug, id: listMeta.value.shipment_id },
      });
      return;
    }
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { id: listMeta.value.shipment_id },
    });
    return;
  }

  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({ name: 'app-procurement-batch-code-list', params: { tenantSlug } });
    return;
  }
  void router.push({ name: 'app-procurement-batch-code-list' });
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}
</style>
