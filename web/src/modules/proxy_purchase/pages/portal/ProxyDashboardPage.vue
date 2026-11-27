<template>
  <q-page
    class="theme-shop proxy-dashboard-page"
    :class="isCustomerRole ? 'tf-page-fill' : isSupplierRole ? 'q-pa-sm page-fixed-layout column no-wrap overflow-hidden' : 'tf-page-fill'"
  >
    <div
      class="proxy-dashboard-page__inner"
      :class="{ 'proxy-dashboard-page__inner--supplier column col min-h-0 no-wrap': isSupplierRole }"
    >
      <template v-if="isCustomerRole">
        <header class="proxy-dashboard-page__head row items-center justify-between q-mb-sm q-gutter-sm">
          <TfDrawerSectionTabs
            v-model="activeTab"
            class="col"
            :tabs="tabOptions"
            aria-label="Customer dashboard sections"
          />
          <TfBtn
            variant="primary"
            size="md"
            label="Add request"
            icon="ph ph-plus"
            :loading="createDraft.isPending.value"
            @click="onAddRequest"
          />
        </header>

        <template v-if="activeTab === 'requests'">
          <TfSkeletonRows v-if="requestsQuery.isPending.value" :rows="6" :cols="1" />
          <TfEmptyState
            v-else-if="!requests.length"
            title="No requests yet"
            message="Create a purchase request and add product links for your admin to review."
            icon="ph ph-folder"
          >
            <TfBtn
              variant="primary"
              size="md"
              label="Add request"
              icon="ph ph-plus"
              class="q-mt-sm"
              :loading="createDraft.isPending.value"
              @click="onAddRequest"
            />
          </TfEmptyState>
          <TfEntityListShell v-else>
            <TfEntityListRow
              v-for="row in requests"
              :key="row.id"
              clickable
              show-chevron
              @click="openRequest(row.id)"
            >
              <template #title>
                <span class="text-weight-medium">{{ requestLabel(row) }}</span>
              </template>
              <template #meta>
                <span>{{ formatDate(row.created_at) }}</span>
                <span v-if="row.line_count > 0"> · {{ row.line_count }} item{{ row.line_count === 1 ? '' : 's' }}</span>
              </template>
              <template #aside>
                <div class="row items-center no-wrap q-gutter-xs">
                  <TfBtn
                    v-if="row.status === 'draft'"
                    variant="icon"
                    icon="ph ph-trash"
                    color="negative"
                    aria-label="Delete draft request"
                    :loading="deleteDraft.isPending.value && draftRequestId === row.id"
                    @click.stop="confirmDeleteRequest(row.id)"
                  />
                  <TfStatusBadge :status="row.status" :label="statusLabel(row.status)" />
                </div>
              </template>
            </TfEntityListRow>
          </TfEntityListShell>
        </template>

        <template v-else>
          <TfSkeletonRows v-if="orderLinesQuery.isPending.value" :rows="6" :cols="1" />
          <TfEmptyState
            v-else-if="!orderLines.length"
            title="No order lines"
            message="Add items to a purchase request to see them here."
            icon="ph ph-link"
          />
          <PpCustomerOrderLineList v-else :lines="orderLines" />
        </template>
      </template>

      <template v-else-if="isSupplierRole">
        <header class="proxy-dashboard-page__head row items-center justify-between q-mb-sm">
          <div>
            <h1 class="text-h6 text-weight-medium q-my-none">Assigned order lines</h1>
            <p v-if="supplierGroupName" class="text-caption text-grey-7 q-mb-none q-mt-xs">
              {{ supplierGroupName }}
            </p>
          </div>
        </header>
        <TfSkeletonRows v-if="supplierOrderLinesQuery.isPending.value" :rows="6" :cols="1" />
        <TfEmptyState
          v-else-if="!supplierOrderLines.length"
          title="No order lines"
          message="Lines assigned to your supplier group will appear here after app staff assigns them."
          icon="ph ph-list-dashes"
        />
        <PpSupplierOrderLineList
          v-else
          class="proxy-dashboard-page__supplier-table col min-h-0"
          :lines="supplierOrderLines"
          :updating-line-id="supplierUpdatingLineId"
          @patch="onSupplierPatchLine"
        />
      </template>

      <TfEmptyState
        v-else
        title="Proxy dashboard"
        message="Your account does not have access to this area."
        icon="ph ph-warning"
      />
    </div>

    <TfConfirmDialog
      v-model="showDeleteConfirm"
      title="Delete draft request?"
      message="This cannot be undone. The request and its items will be removed."
      confirm-label="Delete"
      destructive
      :confirm-loading="deleteDraft.isPending.value"
      @confirm="onConfirmDeleteRequest"
      @cancel="draftRequestId = null"
    />
  </q-page>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfConfirmDialog from 'src/components/ui/TfConfirmDialog.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import PpCustomerOrderLineList from '../../components/order-lines/PpCustomerOrderLineList.vue';
import PpSupplierOrderLineList from '../../components/order-lines/PpSupplierOrderLineList.vue';
import { usePpCustomerDashboardQuery } from '../../composables/usePpCustomerDashboardQuery';
import { usePpCustomerOrderLinesQuery } from '../../composables/usePpCustomerOrderLinesQuery';
import { usePpSupplierOrderLinesQuery } from '../../composables/usePpSupplierOrderLinesQuery';
import { usePpSupplierOrderLineMutations } from '../../composables/usePpSupplierOrderLineMutations';
import { usePpPurchaseRequestMutations } from '../../composables/usePpPurchaseRequestMutations';
import type {
  PpPurchaseRequestListItem,
  PpPurchaseRequestStatus,
  PpSupplierOrderLineUpdatePayload,
} from '../../types/ppPurchaseRequest';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

type DashboardTab = 'requests' | 'lines';

const activeTab = ref<DashboardTab>('requests');
const showDeleteConfirm = ref(false);

const tabOptions = [
  { name: 'requests', label: 'Requests' },
  { name: 'lines', label: 'Order lines' },
];

const isCustomerRole = computed(() => {
  const role = authStore.matchedRole;
  return role === 'proxy_customer_admin' || role === 'proxy_customer_staff';
});

const isSupplierRole = computed(() => {
  const role = authStore.matchedRole;
  return role === 'proxy_supplier_admin' || role === 'proxy_supplier_staff';
});

const supplierOrderLinesQueryEnabled = computed(() => isSupplierRole.value);
const supplierOrderLinesQuery = usePpSupplierOrderLinesQuery(supplierOrderLinesQueryEnabled);
const supplierOrderLines = computed(() => supplierOrderLinesQuery.data.value ?? []);

const supplierGroupName = computed(() => authStore.customerGroup?.name?.trim() || null);

const { updateLine: updateSupplierLine } = usePpSupplierOrderLineMutations();
const supplierUpdatingLineId = ref<number | null>(null);

const onSupplierPatchLine = async (payload: PpSupplierOrderLineUpdatePayload) => {
  supplierUpdatingLineId.value = payload.lineId;
  try {
    await updateSupplierLine.mutateAsync(payload);
  } finally {
    supplierUpdatingLineId.value = null;
  }
};

const customerRequestsQueryEnabled = computed(
  () => isCustomerRole.value && activeTab.value === 'requests',
);

const customerOrderLinesQueryEnabled = computed(
  () => isCustomerRole.value && activeTab.value === 'lines',
);

const requestsQuery = usePpCustomerDashboardQuery(customerRequestsQueryEnabled);
const requests = computed(() => requestsQuery.data.value ?? []);

const orderLinesQuery = usePpCustomerOrderLinesQuery(customerOrderLinesQueryEnabled);
const orderLines = computed(() => orderLinesQuery.data.value ?? []);

const draftRequestId = ref<number | null>(null);
const { createDraft, deleteDraft } = usePpPurchaseRequestMutations(draftRequestId);

const requestLabel = (row: PpPurchaseRequestListItem) =>
  row.request_number?.trim() || `Request #${row.id}`;

const statusLabel = (status: PpPurchaseRequestStatus) =>
  status === 'requested' ? 'Requested' : 'Draft';

const formatDate = (value: string) => date.formatDate(value, 'D MMM YYYY');

const onAddRequest = async () => {
  const created = await createDraft.mutateAsync();
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '';
  await router.push({
    name: 'proxy-purchase-request-page',
    params: { tenantSlug, requestId: String(created.id) },
  });
};

const openRequest = (requestId: number) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '';
  void router.push({
    name: 'proxy-purchase-request-page',
    params: { tenantSlug, requestId: String(requestId) },
  });
};

const confirmDeleteRequest = (requestId: number) => {
  draftRequestId.value = requestId;
  showDeleteConfirm.value = true;
};

const onConfirmDeleteRequest = async () => {
  try {
    await deleteDraft.mutateAsync();
    showDeleteConfirm.value = false;
    draftRequestId.value = null;
  } catch {
    /* error toast handled in mutation */
  }
};
</script>

<style scoped>
.proxy-dashboard-page__inner {
  width: 100%;
  max-width: 1200px;
  margin-inline: auto;
  padding: 0 0.25rem 1rem;
}

.proxy-dashboard-page__head {
  flex-wrap: wrap;
}

.proxy-dashboard-page__inner--supplier {
  width: 100%;
  max-width: none;
  margin-inline: 0;
  padding: 0 0 0.5rem;
}

.proxy-dashboard-page__supplier-table {
  min-height: 0;
  flex: 1 1 auto;
}
</style>