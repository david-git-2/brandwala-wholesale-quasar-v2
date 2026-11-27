<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <header class="row items-center justify-between q-pb-sm flex-shrink-0 q-gutter-sm">
      <TfDrawerSectionTabs
        v-model="activeTab"
        class="col"
        :tabs="tabOptions"
        aria-label="Proxy purchase sections"
      />
      <q-btn
        flat
        round
        dense
        color="primary"
        icon="ph ph-gear"
        :ripple="false"
        aria-label="Settings"
        :to="{ name: 'proxy-purchase-config-page' }"
      />
    </header>

    <div class="col min-h-0 overflow-auto">
      <template v-if="activeTab === 'requests'">
        <TfSkeletonRows v-if="requestsQuery.isPending.value" :rows="6" :cols="1" />
        <TfEmptyState
          v-else-if="!requests.length"
          title="No requests yet"
          message="Customer purchase requests will appear here after they are submitted."
          icon="ph ph-folder"
        />
        <TfEntityListShell v-else>
          <TfEntityListRow v-for="row in requests" :key="row.id">
            <template #title>
              <span class="text-weight-medium">{{ requestLabel(row) }}</span>
            </template>
            <template #meta>
              <span>{{ row.people_group_name }}</span>
              <span> · {{ formatDate(row.created_at) }}</span>
              <span v-if="row.line_count > 0">
                · {{ row.line_count }} item{{ row.line_count === 1 ? '' : 's' }}
              </span>
            </template>
            <template #aside>
              <TfStatusBadge :status="row.status" :label="statusLabel(row.status)" />
            </template>
          </TfEntityListRow>
        </TfEntityListShell>
      </template>

      <template v-else>
        <TfSkeletonRows v-if="orderLinesQuery.isPending.value" :rows="6" :cols="1" />
        <TfEmptyState
          v-else-if="!orderLines.length"
          title="No order lines"
          message="Order lines from customer requests will appear here."
          icon="ph ph-link"
        />
        <PpOrderLineList
          v-else
          :lines="orderLines"
          show-app-actions
          :deleting-line-id="deletingLineId"
          @edit="startEditLine"
          @delete="confirmDeleteLine"
        />
      </template>
    </div>

    <PpAppEditOrderLineDialog
      v-model="showLineDialog"
      :edit-line="editingLine"
      :loading="updateLine.isPending.value"
      @submit="onLineDialogSubmit"
    />
    <TfConfirmDialog
      v-model="showDeleteLineConfirm"
      title="Remove item?"
      message="This order line will be removed."
      confirm-label="Remove"
      destructive
      :confirm-loading="deleteLine.isPending.value"
      @confirm="onConfirmDeleteLine"
      @cancel="linePendingDelete = null"
    />
  </q-page>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import { computed, ref } from 'vue';
import TfConfirmDialog from 'src/components/ui/TfConfirmDialog.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import PpAppEditOrderLineDialog from '../components/PpAppEditOrderLineDialog.vue';
import PpOrderLineList from '../components/order-lines/PpOrderLineList.vue';
import { usePpStaffOrderLineMutations } from '../composables/usePpStaffOrderLineMutations';
import { usePpStaffOrderLinesQuery } from '../composables/usePpStaffOrderLinesQuery';
import { usePpStaffRequestsQuery } from '../composables/usePpStaffRequestsQuery';
import type {
  PpOrderLine,
  PpPurchaseRequestStaffListItem,
  PpPurchaseRequestStatus,
  PpStaffOrderLineUpdatePayload,
} from '../types/ppPurchaseRequest';

type DashboardTab = 'requests' | 'lines';

const activeTab = ref<DashboardTab>('requests');

const tabOptions = [
  { name: 'requests', label: 'Requests' },
  { name: 'lines', label: 'Order lines' },
];

const staffRequestsQueryEnabled = computed(() => activeTab.value === 'requests');
const staffOrderLinesQueryEnabled = computed(() => activeTab.value === 'lines');

const requestsQuery = usePpStaffRequestsQuery(staffRequestsQueryEnabled);
const requests = computed(() => requestsQuery.data.value ?? []);

const orderLinesQuery = usePpStaffOrderLinesQuery(staffOrderLinesQueryEnabled);
const orderLines = computed(() => orderLinesQuery.data.value ?? []);

const { updateLine, deleteLine } = usePpStaffOrderLineMutations();

const showLineDialog = ref(false);
const editingLine = ref<PpOrderLine | null>(null);
const deletingLineId = ref<number | null>(null);
const showDeleteLineConfirm = ref(false);
const linePendingDelete = ref<PpOrderLine | null>(null);

const startEditLine = (line: PpOrderLine) => {
  editingLine.value = line;
  showLineDialog.value = true;
};

const confirmDeleteLine = (line: PpOrderLine) => {
  linePendingDelete.value = line;
  showDeleteLineConfirm.value = true;
};

const onLineDialogSubmit = async (payload: PpStaffOrderLineUpdatePayload) => {
  await updateLine.mutateAsync(payload);
  showLineDialog.value = false;
  editingLine.value = null;
};

const onConfirmDeleteLine = async () => {
  const line = linePendingDelete.value;
  if (!line) return;
  deletingLineId.value = line.id;
  try {
    await deleteLine.mutateAsync(line.id);
    showDeleteLineConfirm.value = false;
    linePendingDelete.value = null;
  } finally {
    deletingLineId.value = null;
  }
};

const requestLabel = (row: PpPurchaseRequestStaffListItem) =>
  row.request_number?.trim() || `Request #${row.id}`;

const statusLabel = (status: PpPurchaseRequestStatus) =>
  status === 'requested' ? 'Requested' : 'Draft';

const formatDate = (value: string) => date.formatDate(value, 'D MMM YYYY');
</script>