<template>
  <q-page class="customer-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <!-- Tabs Bar -->
      <div class="customer-tabs-bar row items-center justify-between no-wrap q-mb-sm">
        <div class="tabs-track row items-center no-wrap">
          <button
            v-if="hasCustomerAccess"
            type="button"
            class="tab-btn row items-center no-wrap"
            :class="{ 'tab-btn--active': activeTab === 'customer' }"
            @click="setTab('customer')"
          >
            <q-icon name="ph ph-users" size="16px" class="q-mr-xs" />
            <span class="tab-btn__label">Customers</span>
            <span v-if="totalCustomers > 0" class="tab-btn__badge q-ml-xs">
              {{ totalCustomers }}
            </span>
          </button>

          <button
            v-if="hasRecipientAccess"
            type="button"
            class="tab-btn row items-center no-wrap"
            :class="{ 'tab-btn--active': activeTab === 'recipient' }"
            @click="setTab('recipient')"
          >
            <q-icon name="ph ph-identification-badge" size="16px" class="q-mr-xs" />
            <span class="tab-btn__label">Recipients</span>
            <span v-if="recipientItemCount > 0" class="tab-btn__badge q-ml-xs">
              {{ recipientItemCount }}
            </span>
          </button>
        </div>
      </div>

      <!-- Tab Content Area -->
      <div class="tab-content-container col column no-wrap min-height-0">
        <!-- 1. CUSTOMER TAB -->
        <div
          v-if="activeTab === 'customer' && hasCustomerAccess"
          class="column no-wrap full-height min-height-0"
        >
          <!-- Customer Toolbar -->
          <div class="customer-toolbar row items-center no-wrap q-gutter-sm q-mb-sm">
            <q-input
              v-model="customerSearchInput"
              outlined
              dense
              placeholder="Search by name, email, or phone — press Enter"
              class="search-box col"
              @keyup.enter.prevent="applyCustomerSearch"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
              </template>
              <template #append v-if="customerSearchInput || appliedCustomerSearch">
                <q-icon
                  name="ph ph-x"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="clearCustomerSearch"
                />
              </template>
            </q-input>

            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-clockwise"
              color="grey-7"
              class="col-auto"
              :loading="isCustomersFetching"
              @click="refetchCustomers()"
            >
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>

            <q-btn
              v-if="canAdministerCustomerGroup"
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Customer"
              no-caps
              dense
              class="action-btn text-weight-bold col-auto q-px-sm"
              @click="openCreateCustomerDialog"
            />
          </div>

          <!-- Customer Skeleton Loading State -->
          <TfEntityListShell v-if="isCustomersLoading && !customers.length" root-class="col">
            <TfEntityListRow v-for="n in 6" :key="n" skeleton />
          </TfEntityListShell>

          <!-- Customer Zero State (No Customers) -->
          <div
            v-else-if="!customers.length && !appliedCustomerSearch"
            class="column items-center justify-center q-pa-xl text-center col tf-entity-list-card"
          >
            <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
              <q-icon name="ph ph-users" size="28px" />
            </q-avatar>
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">No Customers Found</div>
            <p class="text-caption text-grey-6 q-mb-md" style="max-width: 380px">
              Create customer accounts to manage wholesale buyers, credit ledgers, and storefront access.
            </p>
            <q-btn
              v-if="canAdministerCustomerGroup"
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Customer"
              no-caps
              dense
              class="action-btn text-weight-bold q-px-md"
              @click="openCreateCustomerDialog"
            />
          </div>

          <!-- Customer No Search Matches State -->
          <div
            v-else-if="!customers.length"
            class="column items-center justify-center text-center text-grey-7 q-py-xl col tf-entity-list-card"
          >
            <q-icon name="ph ph-magnifying-glass" size="36px" class="q-mb-xs text-grey-4" />
            <div class="text-subtitle2 text-weight-medium text-slate-800">No matching customers found</div>
            <div class="text-caption text-grey-6 q-mt-xs">Try searching with a different name, email, or phone.</div>
            <q-btn
              flat
              no-caps
              color="primary"
              label="Clear search"
              class="q-mt-sm"
              @click="clearCustomerSearch"
            />
          </div>

          <!-- Customer Linear-Style List Container -->
          <TfEntityListShell v-else root-class="col">
            <TfEntityListRow
              v-for="customer in customers"
              :key="customer.customer_group_id"
              @click="openCustomerDrawer(customer)"
            >
              <template #avatar>{{ getInitials(customer.group_name) }}</template>
              <template #title>
                <span class="tf-entity-list-item__name">{{ customer.group_name }}</span>
                <span v-if="customer.admin_name" class="tf-entity-list-item__subtitle">
                  ({{ customer.admin_name }})
                </span>
              </template>
              <template #meta>{{ customerBrowseMeta(customer) }}</template>
              <template #aside>
                <div class="column items-end q-mr-xs">
                  <span
                    class="numeric-cell text-weight-bold"
                    :class="customer.wallet_available_balance >= 0 ? 'text-slate-800' : 'text-negative'"
                  >
                    {{ formatBdt(customer.wallet_available_balance) }}
                  </span>
                  <span class="text-caption text-grey-6" style="font-size: 11px">Wallet Balance</span>
                </div>
                <span
                  class="status-pill"
                  :class="customer.is_active ? 'status-pill--active' : 'status-pill--inactive'"
                >
                  {{ customer.is_active ? 'Active' : 'Inactive' }}
                </span>
              </template>
            </TfEntityListRow>
            <div v-if="hasMoreCustomers" class="row justify-center q-py-sm">
              <q-btn
                flat
                dense
                no-caps
                :loading="isFetchingNextPage"
                class="load-more-btn text-weight-medium text-slate-700 q-px-md"
                label="Load more"
                icon="ph ph-arrow-down"
                @click="fetchNextPage()"
              />
            </div>
          </TfEntityListShell>
        </div>

        <RecipientListPanel
          v-else-if="activeTab === 'recipient' && hasRecipientAccess"
        />
      </div>
    </div>

    <!-- Customer Dialogs & Drawers -->
    <CustomerDetailDrawer
      v-model="drawerOpen"
      :customer="selectedCustomer"
      :tenant-id="tenantId"
      @deleted="onDrawerCustomerDeleted"
    />

    <CreateCustomerDialog
      v-model="createDialogOpen"
      :tenant-id="tenantId"
      :saving="createCustomerMutation.isPending.value"
      @create="onCreateCustomer"
    />

  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useInfiniteCustomerListQuery, useCustomerMutations } from '../composables/useCustomerQuery';
import type { CustomerAccount } from '../types/customer';
import CustomerDetailDrawer from '../components/CustomerDetailDrawer.vue';
import {
  clearCustomerDrawerQuery,
  useRestoreCustomerDrawerFromQuery,
} from '../composables/useCustomerDrawerRouteQuery';
import CreateCustomerDialog from '../components/CreateCustomerDialog.vue';
import RecipientListPanel from '../components/RecipientListPanel.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import { useCanAdministerCustomerGroup } from '../composables/useCanAdministerCustomerGroup';
import { useInvoiceWorkspace } from 'src/modules/bills_pays/composables/useInvoiceWorkspace';
import { useRecipientProfileStore } from 'src/modules/people/submodules/customer/stores/recipientProfileStore';
import { getInitials } from 'src/modules/bills_pays/utils/invoiceListDisplay';
import {
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';

type ActiveTab = 'customer' | 'recipient';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantId = computed(() => authStore.tenantId as number);
const { hasModuleAccess } = useModulePermissions();
const { isParentTenant } = useInvoiceWorkspace();
const canAdministerCustomerGroup = useCanAdministerCustomerGroup();
const recipientStore = useRecipientProfileStore();
const recipientItemCount = computed(() => recipientStore.items.length);

const hasCustomerAccess = computed(() => hasModuleAccess('customer', 'view'));
const hasRecipientAccess = computed(
  () => hasModuleAccess('recipient_profile', 'view') || isParentTenant.value,
);

const activeTab = ref<ActiveTab>('customer');

// Initialize & sync tab with route query
const initTab = () => {
  const queryTab = route.query.tab as string | undefined;
  if (queryTab === 'recipient' && hasRecipientAccess.value) {
    activeTab.value = 'recipient';
  } else if (hasCustomerAccess.value) {
    activeTab.value = 'customer';
  } else if (hasRecipientAccess.value) {
    activeTab.value = 'recipient';
  }
};

const setTab = (tab: ActiveTab) => {
  activeTab.value = tab;
  void router.replace({
    query: {
      ...route.query,
      tab: tab === 'customer' ? undefined : tab,
    },
  });
};

watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab === 'recipient' && hasRecipientAccess.value) {
      activeTab.value = 'recipient';
    } else if (hasCustomerAccess.value) {
      activeTab.value = 'customer';
    }
  },
);

/* ----------------------------------------------------
   CUSTOMER TAB LOGIC
---------------------------------------------------- */
const customerSearchInput = ref('');
const appliedCustomerSearch = ref('');
const drawerOpen = ref(false);
const createDialogOpen = ref(false);
const selectedCustomer = ref<CustomerAccount | null>(null);

const {
  customers,
  totalCustomers,
  hasMore: hasMoreCustomers,
  fetchNextPage,
  isFetchingNextPage,
  isLoading: isCustomersLoading,
  isFetching: isCustomersFetching,
  refetch: refetchCustomers,
} = useInfiniteCustomerListQuery(tenantId, appliedCustomerSearch);

const { createCustomerMutation } = useCustomerMutations();

const applyCustomerSearch = () => {
  appliedCustomerSearch.value = customerSearchInput.value.trim();
};

const clearCustomerSearch = () => {
  customerSearchInput.value = '';
  appliedCustomerSearch.value = '';
};

const openCreateCustomerDialog = () => {
  createDialogOpen.value = true;
};

const onCreateCustomer = async (payload: {
  group_name: string;
  phone: string;
  phone_country_code: string;
}) => {
  try {
    await createCustomerMutation.mutateAsync({
      tenant_id: tenantId.value,
      group_name: payload.group_name,
      phone: payload.phone,
      phone_country_code: payload.phone_country_code,
    });
    createDialogOpen.value = false;
    showSuccessNotification('Customer created.');
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to create customer.';
    showErrorNotification(message);
  }
};

const onDrawerCustomerDeleted = () => {
  drawerOpen.value = false;
  selectedCustomer.value = null;
  clearCustomerDrawerQuery(router, route);
};

useRestoreCustomerDrawerFromQuery({
  tenantId,
  customers,
  selectedCustomer,
  drawerOpen,
});

const openCustomerDrawer = (customer: CustomerAccount) => {
  selectedCustomer.value = customer;
  drawerOpen.value = true;
};

const formatBdt = (val?: number | null) => {
  const num = Number(val) || 0;
  return `${num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
};

const customerBrowseMeta = (customer: CustomerAccount) => {
  const parts: string[] = [];
  if (customer.email) parts.push(customer.email);
  if (customer.phone) parts.push(customer.phone);
  if (customer.address) parts.push(customer.address);
  const members =
    customer.member_count === 1 ? '1 member' : `${customer.member_count} members`;
  parts.push(members);
  return parts.join(' · ');
};

onMounted(() => {
  initTab();
  if (hasRecipientAccess.value && tenantId.value) {
    void recipientStore.fetchRecipientProfiles(tenantId.value, isParentTenant.value);
  }
});
</script>

<style scoped lang="scss">
.customer-overview-page {
  background: var(--tf-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.overview-container {
  height: 100%;
  min-height: 0;
}

.customer-tabs-bar {
  flex-shrink: 0;
}

.tabs-track {
  display: flex;
  gap: 6px;
  padding: 4px;
  border-radius: 8px;
  background: rgba(226, 232, 240, 0.6);
}

.tab-btn {
  border: none;
  background: transparent;
  padding: 6px 14px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s ease-in-out;
}

.tab-btn:hover {
  color: #1e293b;
  background: rgba(255, 255, 255, 0.5);
}

.tab-btn--active {
  background: #ffffff !important;
  color: #0f172a !important;
  font-weight: 600;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}

.tab-btn__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: #e2e8f0;
  color: #475569;
  font-size: 11px;
  font-weight: 600;
}

.tab-btn--active .tab-btn__badge {
  background: #f1f5f9;
  color: #0f172a;
}

.customer-toolbar {
  background: transparent;
  flex-shrink: 0;
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  min-width: 0;
}

.search-box :deep(.q-field__control) {
  border-radius: 8px;
}

.search-box :deep(.q-field--outlined .q-field__control:before) {
  border: 1px solid #e2e8f0;
}

.search-box :deep(.q-field--outlined .q-field__control:hover:before) {
  border-color: #cbd5e1;
}

@import 'src/css/tf-entity-list.scss';

.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  font-weight: 500;
  padding: 2.5px 8px;
  border-radius: 999px;
  white-space: nowrap;
}

.status-pill--active {
  background: #dcfce7;
  color: #166534;
}

.status-pill--inactive {
  background: #f1f5f9;
  color: #64748b;
}

.load-more-btn {
  background: #f1f5f9;
  border-radius: var(--tf-radius-sm, 8px);
  font-size: 12px;
  transition: all 0.15s ease;
}

.load-more-btn:hover {
  background: #e2e8f0;
  color: var(--tf-neutral-ink);
}

.numeric-cell {
  font-variant-numeric: tabular-nums;
  font-size: 13px;
}

/* Dark mode */
body.body--dark .customer-overview-page {
  background: #171717;
}

body.body--dark .tabs-track {
  background: #262626;
}

body.body--dark .tab-btn {
  color: #94a3b8;
}

body.body--dark .tab-btn:hover {
  color: #f8fafc;
  background: rgba(255, 255, 255, 0.05);
}

body.body--dark .tab-btn--active {
  background: #1c1c1c !important;
  color: #f8fafc !important;
}

body.body--dark .tab-btn__badge {
  background: #334155;
  color: #94a3b8;
}

body.body--dark .load-more-btn {
  background: #262626;
  color: #f1f5f9;
}

body.body--dark .load-more-btn:hover {
  background: #333333;
}

body.body--dark .status-pill--inactive {
  background: #2a2a2a;
  color: #94a3b8;
}

body.body--dark .search-box :deep(.q-field--outlined .q-field__control:before) {
  border-color: #334155;
}
</style>
