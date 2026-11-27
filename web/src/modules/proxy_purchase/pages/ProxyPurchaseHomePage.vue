<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <header class="row items-center justify-between q-pb-sm flex-shrink-0 q-gutter-sm">
      <div class="row items-center no-wrap col min-width-0 q-gutter-x-xs">
        <TfDrawerSectionTabs
          v-model="activeTab"
          class="col min-width-0"
          :tabs="tabOptions"
          aria-label="Proxy purchase sections"
        />
        <q-chip
          v-if="activeTab === 'lines' && activeRequestFilterLabel"
          dense
          removable
          color="primary"
          text-color="white"
          class="flex-shrink-0"
          :aria-label="`Clear filter: ${activeRequestFilterLabel}`"
          @remove="clearRequestLineFilter"
        >
          {{ activeRequestFilterLabel }}
        </q-chip>
        <TfBtn
          v-if="activeTab === 'lines' && filteredRequestId != null"
          variant="secondary"
          size="sm"
          label="Add item"
          icon="ph ph-plus"
          class="flex-shrink-0"
          aria-label="Add item to filtered request"
          :loading="addLine.isPending.value && addItemRequestId === filteredRequestId"
          @click="openAddItemForFilteredRequest"
        />
        <q-btn
          v-if="activeTab === 'lines'"
          flat
          round
          dense
          color="primary"
          icon="ph ph-faders"
          class="flex-shrink-0"
          :ripple="false"
          aria-label="Filter and group order lines"
          @click="openLineFilterDrawer"
        >
          <q-badge
            v-if="lineListViewBadgeCount > 0"
            color="primary"
            floating
            rounded
            :label="String(lineListViewBadgeCount)"
          />
          <q-tooltip>Filter &amp; group</q-tooltip>
        </q-btn>
      </div>
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

    <div
      class="col min-h-0"
      :class="activeTab === 'lines' ? 'column no-wrap overflow-hidden' : 'overflow-auto'"
    >
      <template v-if="activeTab === 'requests'">
        <TfSkeletonRows v-if="requestsQuery.isPending.value" :rows="6" :cols="1" />
        <TfEmptyState
          v-else-if="!requests.length"
          title="No requests yet"
          message="Customer purchase requests will appear here after they are submitted."
          icon="ph ph-folder"
        />
        <TfEntityListShell v-else>
          <TfEntityListRow
            v-for="row in requests"
            :key="row.id"
            clickable
            show-chevron
            @click="viewLinesForRequest(row)"
          >
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
              <div class="row items-center no-wrap q-gutter-xs">
                <PpGeneralInstructionMenuBtn
                  :instructions="row.bucket_instructions"
                  :request-label="requestLabel(row)"
                />
                <TfBtn
                  variant="secondary"
                  size="sm"
                  label="Add item"
                  icon="ph ph-plus"
                  aria-label="Add item to request"
                  :loading="addLine.isPending.value && addItemRequestId === row.id"
                  @click.stop="openAddItemForRequest(row)"
                />
                <TfStatusBadge :status="row.status" :label="statusLabel(row.status)" />
              </div>
            </template>
          </TfEntityListRow>
        </TfEntityListShell>
      </template>

      <template v-else>
        <div class="column no-wrap col min-h-0">
          <TfSkeletonRows v-if="orderLinesQuery.isPending.value" :rows="6" :cols="1" />
          <TfEmptyState
            v-else-if="!orderLines.length"
            :title="activeLineFilterCount > 0 ? 'No matching order lines' : 'No order lines'"
            :message="
              activeLineFilterCount > 0
                ? 'Try changing or clearing filters.'
                : 'Order lines from customer requests will appear here.'
            "
            icon="ph ph-link"
          />
          <PpAppOrderLineList
            v-else
            ref="orderLineListRef"
            class="col min-h-0"
            :lines="orderLines"
            :group-by="lineGroupBy"
            :updating-line-id="updatingLineId"
            @edit="startEditLine"
            @patch="onPatchLine"
            @delete-selected="confirmDeleteSelected"
          />
        </div>
      </template>

    <PpAppOrderLineFilterDrawer
      v-model="lineFilterDrawerOpen"
      :draft="draftLineFilters"
      :draft-group-by="draftLineGroupBy"
      :filter-options="lineFilterOptionsQuery.data.value"
      :loading="lineFilterOptionsQuery.isPending.value"
      @update:draft="draftLineFilters = $event"
      @update:draft-group-by="draftLineGroupBy = $event"
      @apply="applyLineFilters"
      @reset="resetLineFilters"
    />
    </div>

    <PpAppEditOrderLineDialog
      v-model="showAddItemDialog"
      add-mode
      :loading="addLine.isPending.value"
      @create="onAddItemDialogSubmit"
    />
    <PpAppEditOrderLineDialog
      v-model="showLineDialog"
      :edit-line="editingLine"
      :loading="updateLine.isPending.value"
      @submit="onLineDialogSubmit"
    />
    <TfConfirmDialog
      v-model="showDeleteSelectedConfirm"
      title="Remove selected items?"
      :message="deleteSelectedMessage"
      confirm-label="Remove"
      destructive
      :confirm-loading="deleteLines.isPending.value"
      @confirm="onConfirmDeleteSelected"
      @cancel="pendingDeleteIds = []"
    />
  </q-page>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import TfConfirmDialog from 'src/components/ui/TfConfirmDialog.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import PpGeneralInstructionMenuBtn from '../components/PpGeneralInstructionMenuBtn.vue';
import PpAppEditOrderLineDialog from '../components/PpAppEditOrderLineDialog.vue';
import PpAppOrderLineFilterDrawer from '../components/order-lines/PpAppOrderLineFilterDrawer.vue';
import PpAppOrderLineList from '../components/order-lines/PpAppOrderLineList.vue';
import { usePpStaffOrderLineFilterOptionsQuery } from '../composables/usePpStaffOrderLineFilterOptionsQuery';
import { usePpStaffOrderLineMutations } from '../composables/usePpStaffOrderLineMutations';
import { usePpStaffOrderLinesQuery } from '../composables/usePpStaffOrderLinesQuery';
import { usePpStaffRequestsQuery } from '../composables/usePpStaffRequestsQuery';
import {
  countActivePpAppOrderLineFilters,
  emptyPpAppOrderLineListFilters,
  ppAppOrderLineRequestFilterLabel,
  type PpAppOrderLineGroupBy,
  type PpAppOrderLineListFilters,
} from '../types/ppAppOrderLineFilters';
import type {
  PpOrderLine,
  PpPurchaseRequestStaffListItem,
  PpPurchaseRequestStatus,
  PpStaffOrderLineUpdatePayload,
  PpStaffOrderLineWritePayload,
} from '../types/ppPurchaseRequest';

type DashboardTab = 'requests' | 'lines';

const DASHBOARD_TABS = ['requests', 'lines'] as const satisfies readonly DashboardTab[];

const isDashboardTab = (value: string): value is DashboardTab =>
  (DASHBOARD_TABS as readonly string[]).includes(value);

const route = useRoute();
const router = useRouter();

const activeTab = ref<DashboardTab>('requests');

const tabQueryValue = (tab: DashboardTab): string | undefined =>
  tab === 'requests' ? undefined : tab;

const syncTabFromQuery = () => {
  const raw = route.query.tab;
  const next = typeof raw === 'string' && isDashboardTab(raw) ? raw : 'requests';
  if (activeTab.value !== next) {
    activeTab.value = next;
  }
};

watch(() => route.query.tab, () => syncTabFromQuery());

watch(activeTab, (tab) => {
  const desired = tabQueryValue(tab);
  const current = typeof route.query.tab === 'string' ? route.query.tab : undefined;
  if (current === desired || (desired === undefined && !current)) {
    return;
  }
  void router.replace({
    name: route.name ?? 'proxy-purchase-home-page',
    query: {
      ...route.query,
      tab: desired,
    },
  });
});

onMounted(() => {
  syncTabFromQuery();
});

const tabOptions = [
  { name: 'requests', label: 'Requests' },
  { name: 'lines', label: 'Order lines' },
];

const staffRequestsQueryEnabled = computed(() => activeTab.value === 'requests');
const staffOrderLinesQueryEnabled = computed(() => activeTab.value === 'lines');

const requestsQuery = usePpStaffRequestsQuery(staffRequestsQueryEnabled);
const requests = computed(() => requestsQuery.data.value ?? []);

const appliedLineFilters = ref<PpAppOrderLineListFilters>(emptyPpAppOrderLineListFilters());
const draftLineFilters = ref<PpAppOrderLineListFilters>(emptyPpAppOrderLineListFilters());
const draftLineGroupBy = ref<PpAppOrderLineGroupBy>('none');
const lineFilterDrawerOpen = ref(false);
const lineGroupBy = ref<PpAppOrderLineGroupBy>('none');
const activeRequestFilterLabel = ref<string | null>(null);

const lineFilterOptionsQueryEnabled = computed(
  () => activeTab.value === 'lines' || lineFilterDrawerOpen.value,
);
const lineFilterOptionsQuery = usePpStaffOrderLineFilterOptionsQuery(lineFilterOptionsQueryEnabled);

const orderLinesQuery = usePpStaffOrderLinesQuery(staffOrderLinesQueryEnabled, appliedLineFilters);
const orderLines = computed(() => orderLinesQuery.data.value ?? []);

const activeLineFilterCount = computed(() => countActivePpAppOrderLineFilters(appliedLineFilters.value));

const filteredRequestId = computed(() => appliedLineFilters.value.purchase_request_id);

const lineListViewBadgeCount = computed(
  () => activeLineFilterCount.value + (lineGroupBy.value === 'store_url' ? 1 : 0),
);

const openLineFilterDrawer = () => {
  draftLineFilters.value = { ...appliedLineFilters.value };
  draftLineGroupBy.value = lineGroupBy.value;
  lineFilterDrawerOpen.value = true;
};

const purchaseRequestFilterLabel = (id: number | null): string | null => {
  if (id == null) return null;
  const match = lineFilterOptionsQuery.data.value?.purchase_requests?.find((r) => r.id === id);
  if (match) return ppAppOrderLineRequestFilterLabel(match);
  return `Request #${id}`;
};

const applyLineFilters = () => {
  appliedLineFilters.value = { ...draftLineFilters.value };
  lineGroupBy.value = draftLineGroupBy.value;
  activeRequestFilterLabel.value = purchaseRequestFilterLabel(
    appliedLineFilters.value.purchase_request_id,
  );
};

const resetLineFilters = () => {
  draftLineFilters.value = emptyPpAppOrderLineListFilters();
  draftLineGroupBy.value = 'none';
  appliedLineFilters.value = emptyPpAppOrderLineListFilters();
  lineGroupBy.value = 'none';
  activeRequestFilterLabel.value = null;
};

const clearRequestLineFilter = () => {
  activeRequestFilterLabel.value = null;
  appliedLineFilters.value = {
    ...appliedLineFilters.value,
    purchase_request_id: null,
  };
  draftLineFilters.value = {
    ...draftLineFilters.value,
    purchase_request_id: null,
  };
};

const viewLinesForRequest = (row: PpPurchaseRequestStaffListItem) => {
  activeRequestFilterLabel.value = requestLabel(row);
  draftLineFilters.value = {
    ...emptyPpAppOrderLineListFilters(),
    purchase_request_id: row.id,
  };
  appliedLineFilters.value = {
    ...emptyPpAppOrderLineListFilters(),
    purchase_request_id: row.id,
  };
  lineGroupBy.value = 'none';
  draftLineGroupBy.value = 'none';
  activeTab.value = 'lines';
};

const { addLine, updateLine, deleteLines } = usePpStaffOrderLineMutations();

const showAddItemDialog = ref(false);
const addItemRequestId = ref<number | null>(null);

const openAddItemForRequest = (row: PpPurchaseRequestStaffListItem) => {
  addItemRequestId.value = row.id;
  showAddItemDialog.value = true;
};

const openAddItemForFilteredRequest = () => {
  const id = filteredRequestId.value;
  if (id == null) return;
  addItemRequestId.value = id;
  showAddItemDialog.value = true;
};

const onAddItemDialogSubmit = async (payload: PpStaffOrderLineWritePayload) => {
  const requestId = addItemRequestId.value;
  if (requestId == null) return;
  await addLine.mutateAsync({ requestId, line: payload });
  showAddItemDialog.value = false;
  addItemRequestId.value = null;
};

const orderLineListRef = ref<{ clearSelection: () => void } | null>(null);
const showLineDialog = ref(false);
const editingLine = ref<PpOrderLine | null>(null);
const updatingLineId = ref<number | null>(null);
const showDeleteSelectedConfirm = ref(false);
const pendingDeleteIds = ref<number[]>([]);

const deleteSelectedMessage = computed(() => {
  const count = pendingDeleteIds.value.length;
  return count === 1
    ? 'This order line will be removed.'
    : `${count} order lines will be removed.`;
});

const startEditLine = (line: PpOrderLine) => {
  editingLine.value = line;
  showLineDialog.value = true;
};

const onPatchLine = async (payload: PpStaffOrderLineUpdatePayload) => {
  updatingLineId.value = payload.lineId;
  try {
    await updateLine.mutateAsync(payload);
  } finally {
    updatingLineId.value = null;
  }
};

const onLineDialogSubmit = async (payload: PpStaffOrderLineUpdatePayload) => {
  await updateLine.mutateAsync(payload);
  showLineDialog.value = false;
  editingLine.value = null;
};

const confirmDeleteSelected = (lineIds: number[]) => {
  pendingDeleteIds.value = lineIds;
  showDeleteSelectedConfirm.value = true;
};

const onConfirmDeleteSelected = async () => {
  const ids = pendingDeleteIds.value;
  if (ids.length === 0) return;
  await deleteLines.mutateAsync(ids);
  showDeleteSelectedConfirm.value = false;
  pendingDeleteIds.value = [];
  orderLineListRef.value?.clearSelection();
};

const requestLabel = (row: PpPurchaseRequestStaffListItem) =>
  row.request_number?.trim() || `Request #${row.id}`;

const statusLabel = (status: PpPurchaseRequestStatus) =>
  status === 'requested' ? 'Requested' : 'Draft';

const formatDate = (value: string) => date.formatDate(value, 'D MMM YYYY');
</script>
