<template>
  <q-page class="tf-page-fill theme-shop proxy-dashboard-page">
    <div class="proxy-dashboard-page__inner">
      <TfEmptyState
        v-if="!isCustomerRole"
        title="Proxy dashboard"
        message="Your assigned purchase lines will appear here in a later step."
        icon="ph ph-list-dashes"
      />

      <template v-else>
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
                <TfStatusBadge :status="row.status" :label="statusLabel(row.status)" />
              </template>
            </TfEntityListRow>
          </TfEntityListShell>
        </template>

        <TfEmptyState
          v-else
          title="Order lines"
          message="A line list for your group will appear here in a later step."
          icon="ph ph-link"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { usePpCustomerDashboardQuery } from '../../composables/usePpCustomerDashboardQuery';
import { usePpPurchaseRequestMutations } from '../../composables/usePpPurchaseRequestMutations';
import type { PpPurchaseRequestListItem, PpPurchaseRequestStatus } from '../../types/ppPurchaseRequest';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

type DashboardTab = 'requests' | 'lines';

const activeTab = ref<DashboardTab>('requests');

const tabOptions = [
  { name: 'requests', label: 'Requests' },
  { name: 'lines', label: 'Order lines' },
];

const isCustomerRole = computed(() => {
  const role = authStore.matchedRole;
  return role === 'proxy_customer_admin' || role === 'proxy_customer_staff';
});

const customerQueryEnabled = computed(
  () => isCustomerRole.value && activeTab.value === 'requests',
);

const requestsQuery = usePpCustomerDashboardQuery(customerQueryEnabled);
const requests = computed(() => requestsQuery.data.value ?? []);

const draftRequestId = ref<number | null>(null);
const { createDraft } = usePpPurchaseRequestMutations(draftRequestId);

const requestLabel = (row: PpPurchaseRequestListItem) =>
  row.request_number?.trim() || `Request #${row.id}`;

const statusLabel = (status: PpPurchaseRequestStatus) =>
  status === 'post' ? 'Posted' : 'Draft';

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
</style>