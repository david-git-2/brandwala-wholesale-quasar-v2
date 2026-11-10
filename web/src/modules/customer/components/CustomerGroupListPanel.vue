<template>
  <div
    class="customer-group-list column no-wrap"
    :class="{ 'customer-group-list--fill': fillHeight }"
  >
    <div class="customer-toolbar row items-center no-wrap q-gutter-sm q-mb-md">
      <q-input
        v-model="searchInput"
        outlined
        dense
        hide-bottom-space
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
        :ripple="false"
        :loading="customersQuery.isFetching.value"
        @click="customersQuery.refetch()"
      >
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>
      <q-btn
        v-if="canAdministerCustomerGroup"
        unelevated
        no-caps
        color="primary"
        icon="ph ph-plus"
        label="Create Customer"
        class="action-btn text-weight-medium col-auto"
        :ripple="false"
        @click="openCreateCustomerDialog"
      />
    </div>

    <div
      v-if="customersQuery.isLoading.value && !customers.length"
      class="clean-list-card col"
    >
      <div class="clean-list-scroll">
        <div
          v-for="n in 6"
          :key="n"
          class="clean-list-item clean-list-item--skeleton"
        >
          <div class="item-main-info row items-center no-wrap">
            <q-skeleton type="QAvatar" size="32px" class="q-mr-sm" />
            <div class="item-info">
              <q-skeleton type="text" width="180px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="280px" height="13px" />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div
      v-else-if="!customers.length && appliedSearch"
      class="column items-center justify-center text-center text-grey-7 q-py-xl col clean-list-card"
    >
      <q-icon name="ph ph-magnifying-glass" size="36px" class="q-mb-xs text-grey-5" />
      <div class="text-subtitle2 text-weight-medium">No matching customers found</div>
      <div class="text-caption text-grey-6 q-mt-xs">Try a different name, email, or phone.</div>
      <q-btn flat no-caps color="primary" label="Clear search" class="q-mt-sm" :ripple="false" @click="clearSearch" />
    </div>

    <div
      v-else-if="!customers.length && !customersQuery.isLoading.value"
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
        no-caps
        color="primary"
        icon="ph ph-plus"
        label="Create Customer"
        class="action-btn text-weight-bold"
        :ripple="false"
        @click="openCreateCustomerDialog"
      />
    </div>

    <div v-else class="clean-list-card col column no-wrap">
      <div class="clean-list-scroll" :class="{ 'opacity-60': customersQuery.isFetching.value }">
        <CustomerGroupListCard
          v-for="customer in customers"
          :key="customer.customer_group_id"
          :customer="customer"
          :initials="getInitials(customer.group_name)"
          @open="openCustomerDrawer(customer)"
        />
      </div>
      <div v-if="totalPages > 1" class="row justify-center q-pa-sm customer-list-pagination">
        <q-pagination
          v-model="pagination.page"
          :max="totalPages"
          :max-pages="7"
          direction-links
          boundary-links
          :ripple="false"
          color="primary"
          active-design="outline"
          size="sm"
        />
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
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerListQuery, useCustomerMutations } from '../composables/useCustomerQuery';
import type { CustomerAccount } from '../types/customer';
import CustomerDetailDrawer from './CustomerDetailDrawer.vue';
import CustomerGroupListCard from './CustomerGroupListCard.vue';
import CreateCustomerDialog from './CreateCustomerDialog.vue';
import { useCanAdministerCustomerGroup } from '../composables/useCanAdministerCustomerGroup';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

withDefaults(
  defineProps<{
    /** Fill parent height (full-page hub). Off when embedded in People tabs. */
    fillHeight?: boolean;
  }>(),
  { fillHeight: true },
);

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
const totalPages = computed(() => customersQuery.data.value?.meta.totalPages ?? 1);
const { createCustomerMutation } = useCustomerMutations();

watch(appliedSearch, () => {
  pagination.value.page = 1;
});

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
</script>

<style scoped lang="scss">
@import '../styles/customer-clean-list.scss';

.customer-group-list--fill {
  height: 100%;
  min-height: 0;
}

.customer-toolbar {
  background: transparent;
  flex-shrink: 0;
}

.action-btn {
  border-radius: var(--tf-radius-sm, 8px) !important;
}

.search-box {
  min-width: 0;
}

.search-box :deep(.q-field__control) {
  border-radius: var(--tf-radius-sm, 8px);
}
</style>
