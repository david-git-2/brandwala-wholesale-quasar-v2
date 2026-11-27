<template>
  <div class="column no-wrap pp-shipments-panel">
    <div class="row items-center q-gutter-sm q-mb-sm flex-shrink-0">
      <div class="col text-body2 text-weight-medium text-grey-8">Shipments</div>
      <TfBtn
        variant="primary"
        size="md"
        label="Add shipment"
        icon="ph ph-plus"
        class="col-auto"
        @click="createDialogOpen = true"
      />
    </div>

    <TfEntityListShell
      v-if="shipmentsQuery.isLoading.value && !shipments.length"
      root-class="pp-shipments-list--fit"
    >
      <TfEntityListRow v-for="n in 3" :key="n" skeleton />
    </TfEntityListShell>

    <TfEmptyState
      v-else-if="!shipments.length"
      title="No shipments yet"
      message="Create a draft shipment to start grouping proxy purchase lines."
      icon="ph ph-truck"
    >
      <TfBtn variant="primary" size="md" label="Add shipment" @click="createDialogOpen = true" />
    </TfEmptyState>

    <TfEntityListShell v-else root-class="pp-shipments-list--fit">
      <TfEntityListRow v-for="shipment in shipments" :key="shipment.id">
        <template #title>
          <span class="text-weight-medium">{{ shipment.name }}</span>
        </template>
        <template #meta>
          <span class="text-caption text-grey-7 q-mr-sm">{{ shipment.shipment_code }}</span>
          <span
            class="pp-shipment-status-pill"
            :class="`pp-shipment-status-pill--${statusSlug(shipment.status)}`"
          >
            {{ PP_SHIPMENT_STATUS_LABELS[shipment.status] }}
          </span>
        </template>
      </TfEntityListRow>
    </TfEntityListShell>

    <PpCreateShipmentDialog
      v-model="createDialogOpen"
      :loading="createShipment.isPending.value"
      @submit="onCreateShipment"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import PpCreateShipmentDialog from './PpCreateShipmentDialog.vue';
import { usePpShipmentsQuery } from '../composables/usePpShipmentsQuery';
import { usePpShipmentMutations } from '../composables/usePpShipmentMutations';
import {
  PP_SHIPMENT_STATUS_LABELS,
  type PpShipmentStatus,
} from '../types/ppShipment';

const createDialogOpen = ref(false);

const shipmentsQuery = usePpShipmentsQuery();
const shipments = computed(() => shipmentsQuery.data.value ?? []);

const { createShipment } = usePpShipmentMutations();

const statusSlug = (status: PpShipmentStatus) => {
  if (status === 'in_transit') return 'transit';
  return status;
};

const onCreateShipment = async (payload: { name: string }) => {
  try {
    await createShipment.mutateAsync(payload);
    createDialogOpen.value = false;
  } catch {
    /* notified */
  }
};
</script>

<style scoped>
.pp-shipments-panel {
  width: 100%;
  flex: 0 0 auto;
  align-self: flex-start;
}

.pp-shipments-panel :deep(.pp-shipments-list--fit.tf-entity-list-card) {
  flex: 0 0 auto;
  min-height: 0;
}

.pp-shipments-panel :deep(.pp-shipments-list--fit .tf-entity-list-scroll) {
  flex: 0 0 auto;
  min-height: 0;
  overflow: visible;
}

.pp-shipment-status-pill {
  display: inline-block;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.4;
  padding: 2px 8px;
  border-radius: 4px;
  text-transform: capitalize;
}

.pp-shipment-status-pill--draft {
  color: var(--q-grey-8);
  background: color-mix(in srgb, var(--q-grey-6) 18%, transparent);
}

.pp-shipment-status-pill--transit {
  color: var(--q-warning);
  background: color-mix(in srgb, var(--q-warning) 16%, transparent);
}

.pp-shipment-status-pill--received {
  color: var(--q-positive);
  background: color-mix(in srgb, var(--q-positive) 16%, transparent);
}

.pp-shipment-status-pill--cancelled {
  color: var(--q-negative);
  background: color-mix(in srgb, var(--q-negative) 14%, transparent);
}
</style>