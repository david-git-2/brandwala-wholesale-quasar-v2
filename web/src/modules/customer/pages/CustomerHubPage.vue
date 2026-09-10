<template>
  <q-page class="customer-hub-page page-fixed-layout q-pa-md">
    <div class="customer-container column no-wrap full-height">
      <div class="customer-toolbar row items-center no-wrap q-gutter-sm q-mb-md">
        <q-input
          v-model="searchInput"
          outlined
          dense
          placeholder="Search by name, email, or phone — press Enter"
          class="search-box col"
          @keyup.enter.prevent="applySearch"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
          </template>
          <template #append v-if="searchInput || appliedSearch">
            <q-icon
              name="ph ph-x"
              size="16px"
              class="cursor-pointer text-grey-5"
              @click="clearSearch"
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
          :loading="customersQuery.isFetching.value"
          @click="customersQuery.refetch()"
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
          class="action-btn text-weight-medium col-auto"
          @click="openCreateCustomerDialog"
        />
      </div>

      <div
        v-if="!customers.length && !customersQuery.isLoading.value"
        class="column items-center justify-center q-pa-xl text-center col"
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
          class="action-btn text-weight-bold"
          @click="openCreateCustomerDialog"
        />
      </div>

      <div v-else class="treasury-table-wrap col">
        <q-table
          flat
          :rows="customers"
          :columns="columns"
          row-key="customer_group_id"
          class="customer-table cursor-pointer col"
          :loading="customersQuery.isFetching.value"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
          @row-click="(_, row) => openCustomerDrawer(row)"
        >
          <template #body-cell-customer="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-avatar size="32px" class="q-mr-sm customer-avatar flex-shrink-0">
                  {{ getInitials(props.row.group_name) }}
                </q-avatar>
                <div class="two-line ellipsis">
                  <div class="text-weight-medium text-grey-9 ellipsis">{{ props.row.group_name }}</div>
                  <div class="line-muted ellipsis">{{ props.row.admin_name || '—' }}</div>
                </div>
              </div>
            </q-td>
          </template>

          <template #body-cell-contact="props">
            <q-td :props="props">
              <div class="two-line">
                <div class="ellipsis text-grey-9">{{ props.row.email || '—' }}</div>
                <div class="line-muted ellipsis">{{ props.row.phone || '—' }}</div>
              </div>
            </q-td>
          </template>

          <template #body-cell-address="props">
            <q-td :props="props">
              <div class="two-line">
                <div class="ellipsis text-grey-8">{{ props.row.address || '—' }}</div>
                <div class="line-muted">&nbsp;</div>
              </div>
            </q-td>
          </template>

          <template #body-cell-members="props">
            <q-td :props="props" class="text-right">
              <span class="numeric-cell">{{ props.row.member_count }}</span>
            </q-td>
          </template>

          <template #body-cell-wallet="props">
            <q-td :props="props" class="text-right">
              <span
                class="numeric-cell"
                :class="props.row.wallet_available_balance >= 0 ? 'text-grey-8' : 'text-negative'"
              >
                {{ formatBdt(props.row.wallet_available_balance) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <span
                class="status-chip"
                :class="props.row.is_active ? 'status-chip--active' : 'status-chip--inactive'"
              >
                {{ props.row.is_active ? 'Active' : 'Inactive' }}
              </span>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right" @click.stop>
              <q-btn
                flat
                round
                dense
                color="grey-7"
                icon="ph ph-dots-three"
                :loading="deletingCustomerId === props.row.customer_group_id"
                aria-label="Customer actions"
              >
                <q-menu anchor="bottom right" self="top right">
                  <q-list dense style="min-width: 148px">
                    <q-item v-close-popup clickable @click="openCustomerDrawer(props.row)">
                      <q-item-section>View</q-item-section>
                    </q-item>
                    <q-item
                      v-if="canAdministerCustomerGroup"
                      v-close-popup
                      clickable
                      class="text-negative"
                      @click="onDeleteCustomer(props.row)"
                    >
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </div>
    </div>

    <CustomerDetailDrawer
      v-model="drawerOpen"
      :customer="selectedCustomer"
      :tenant-id="tenantId"
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
import { computed, ref } from 'vue';
import type { QTableProps } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerListQuery, useCustomerMutations } from '../composables/useCustomerQuery';
import type { CustomerAccount } from '../types/customer';
import CustomerDetailDrawer from '../components/CustomerDetailDrawer.vue';
import CreateCustomerDialog from '../components/CreateCustomerDialog.vue';
import { useCanAdministerCustomerGroup } from '../composables/useCanAdministerCustomerGroup';
import { showErrorNotification, showSuccessNotification, requestConfirmation } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const canAdministerCustomerGroup = useCanAdministerCustomerGroup();

const searchInput = ref('');
const appliedSearch = ref('');
const tenantId = computed(() => authStore.tenantId as number);

const drawerOpen = ref(false);
const createDialogOpen = ref(false);
const selectedCustomer = ref<CustomerAccount | null>(null);

const pagination = ref({
  page: 1,
  rowsPerPage: 20,
});

const customersQuery = useCustomerListQuery(
  tenantId,
  appliedSearch,
  computed(() => pagination.value.page),
  computed(() => pagination.value.rowsPerPage),
);
const customers = computed(() => customersQuery.data.value?.data ?? []);
const totalCustomers = computed(() => customersQuery.data.value?.meta.total ?? 0);
const { createCustomerMutation, deleteCustomerGroupMutation } = useCustomerMutations();
const deletingCustomerId = ref<number | null>(null);

const columns: QTableProps['columns'] = [
  { name: 'customer', label: 'Customer', field: 'group_name', align: 'left' },
  { name: 'contact', label: 'Contact', field: 'email', align: 'left' },
  { name: 'address', label: 'Address', field: 'address', align: 'left' },
  { name: 'members', label: 'Members', field: 'member_count', align: 'right' },
  { name: 'wallet', label: 'Wallet Balance', field: 'wallet_available_balance', align: 'right' },
  { name: 'status', label: 'Status', field: 'is_active', align: 'left' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const tablePagination = computed({
  get: () => ({
    page: pagination.value.page,
    rowsPerPage: pagination.value.rowsPerPage,
    rowsNumber: totalCustomers.value,
  }),
  set: (val) => {
    pagination.value.page = val.page;
    pagination.value.rowsPerPage = val.rowsPerPage;
  },
});

const onTableRequest = (props: { pagination: { page: number; rowsPerPage: number } }) => {
  tablePagination.value = props.pagination;
};

const applySearch = () => {
  appliedSearch.value = searchInput.value.trim();
  pagination.value.page = 1;
};

const clearSearch = () => {
  searchInput.value = '';
  appliedSearch.value = '';
  pagination.value.page = 1;
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

const onDeleteCustomer = async (customer: CustomerAccount) => {
  const confirmed = await requestConfirmation(
    `Remove "${customer.group_name}" from the customer list? Orders and invoices stay. You can use the same phone on a new customer.`,
    'Delete customer group',
    'Delete',
  );
  if (!confirmed) return;

  deletingCustomerId.value = customer.customer_group_id;
  try {
    await deleteCustomerGroupMutation.mutateAsync({
      id: customer.customer_group_id,
      tenant_id: tenantId.value,
    });
    if (selectedCustomer.value?.customer_group_id === customer.customer_group_id) {
      drawerOpen.value = false;
      selectedCustomer.value = null;
    }
    showSuccessNotification('Customer group deleted.');
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Failed to delete customer group.';
    showErrorNotification(message);
  } finally {
    deletingCustomerId.value = null;
  }
};

const openCustomerDrawer = (customer: CustomerAccount) => {
  selectedCustomer.value = customer;
  drawerOpen.value = true;
};

const getInitials = (name?: string | null) => {
  if (!name) return 'C';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'C';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'C';
};

const formatBdt = (val?: number | null) => {
  const num = Number(val) || 0;
  return `${num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
};
</script>

<style scoped>
.customer-hub-page {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.customer-container {
  height: 100%;
  min-height: 0;
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

.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.customer-table {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: transparent;
}

.customer-table :deep(.q-table__container) {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  box-shadow: none;
  background: transparent;
}

.customer-table :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.customer-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.05em;
  color: #64748b;
  border-bottom: 1px solid #e2e8f0;
}

.customer-table :deep(tbody tr td) {
  padding: 12px 16px;
  vertical-align: middle;
  border-bottom: 1px solid #f1f5f9;
}

.two-line {
  min-height: 36px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.line-muted {
  font-size: 12px;
  line-height: 16px;
  color: #64748b;
}

.customer-avatar {
  background: #e2e8f0;
  color: #475569;
  font-size: 12px;
  font-weight: 600;
}

.numeric-cell {
  font-variant-numeric: tabular-nums;
  font-weight: 500;
  font-size: 13px;
}

.status-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
  line-height: 18px;
}

.status-chip--active {
  background: #e6f4ea;
  color: #137333;
}

.status-chip--inactive {
  background: #f1f3f4;
  color: #5f6368;
}

.customer-table :deep(tbody tr) {
  transition: background-color 0.15s ease-in-out;
}

.customer-table :deep(tbody tr:hover) {
  background-color: rgba(241, 245, 249, 0.6);
}

body.body--dark .line-muted {
  color: #94a3b8;
}

body.body--dark .customer-avatar {
  background: #334155;
  color: #e2e8f0;
}

body.body--dark .search-box :deep(.q-field--outlined .q-field__control:before) {
  border-color: #334155;
}

body.body--dark .status-chip--inactive {
  background: #2a2a2a;
  color: #94a3b8;
}

body.body--dark .customer-table :deep(thead tr th) {
  background: #242424;
  color: #94a3b8;
  border-color: #2e2e2e;
}

body.body--dark .customer-table :deep(tbody tr:hover) {
  background-color: rgba(255, 255, 255, 0.04);
}
</style>
