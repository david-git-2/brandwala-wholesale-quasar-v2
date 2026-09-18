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
            <span v-if="recipientItems.length > 0" class="tab-btn__badge q-ml-xs">
              {{ recipientItems.length }}
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
          <div
            v-if="isCustomersLoading && !customers.length"
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
                <div class="item-aside">
                  <q-skeleton type="rect" width="90px" height="24px" class="rounded-borders q-mr-sm" />
                  <q-skeleton type="QBadge" width="60px" height="20px" class="rounded-borders" />
                </div>
              </div>
            </div>
          </div>

          <!-- Customer Zero State (No Customers) -->
          <div
            v-else-if="!customers.length && !appliedCustomerSearch"
            class="column items-center justify-center q-pa-xl text-center col clean-list-card"
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
            class="column items-center justify-center text-center text-grey-7 q-py-xl col clean-list-card"
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
          <div v-else class="clean-list-card col">
            <div class="clean-list-scroll">
              <div
                v-for="customer in customers"
                :key="customer.customer_group_id"
                class="clean-list-item"
                @click="openCustomerDrawer(customer)"
              >
                <!-- Left Side: Avatar + Group Name + Inline Meta -->
                <div class="item-main-info row items-center no-wrap">
                  <q-avatar size="32px" class="item-avatar flex-shrink-0 q-mr-sm">
                    {{ getInitials(customer.group_name) }}
                  </q-avatar>
                  <div class="item-info">
                    <div class="item-title-line">
                      <span class="item-name">{{ customer.group_name }}</span>
                      <span v-if="customer.admin_name" class="meta-subtext">({{ customer.admin_name }})</span>
                    </div>
                    <div class="item-meta-line">
                      <span v-if="customer.email" class="meta-item">{{ customer.email }}</span>
                      <span v-if="customer.email && customer.phone" class="meta-dot">·</span>
                      <span v-if="customer.phone" class="meta-item">{{ customer.phone }}</span>
                      <span v-if="(customer.email || customer.phone) && customer.address" class="meta-dot">·</span>
                      <span v-if="customer.address" class="meta-item meta-address">{{ customer.address }}</span>
                      <span class="meta-dot">·</span>
                      <span class="meta-item">{{ customer.member_count }} {{ customer.member_count === 1 ? 'member' : 'members' }}</span>
                    </div>
                  </div>
                </div>

                <!-- Right Side: Wallet Balance + Status + Chevron -->
                <div class="item-aside">
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

                  <q-icon name="ph ph-caret-right" size="16px" class="item-chevron" />
                </div>
              </div>

              <!-- Load More Button inside list -->
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
            </div>
          </div>
        </div>

        <!-- 2. RECIPIENT TAB -->
        <div
          v-else-if="activeTab === 'recipient' && hasRecipientAccess"
          class="column no-wrap full-height min-height-0"
        >
          <!-- Recipient Toolbar -->
          <div class="customer-toolbar row items-center no-wrap q-gutter-sm q-mb-sm">
            <q-input
              v-model="recipientSearchText"
              outlined
              dense
              placeholder="Search by recipient name, phone, district, or address..."
              class="search-box col"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
              </template>
              <template #append v-if="recipientSearchText">
                <q-icon
                  name="ph ph-x"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="recipientSearchText = ''"
                />
              </template>
            </q-input>

            <q-select
              v-if="isParentTenant && childTenantOptions.length > 1"
              v-model="selectedChildTenantId"
              :options="childTenantOptions"
              option-value="value"
              option-label="label"
              emit-value
              map-options
              outlined
              dense
              options-dense
              class="col-auto dense-tenant-select"
              style="min-width: 170px"
              aria-label="Filter by child tenant"
            >
              <template #prepend>
                <q-icon name="ph ph-buildings" size="16px" class="text-grey-6" />
              </template>
            </q-select>

            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-clockwise"
              color="grey-7"
              class="col-auto"
              :loading="recipientStore.loading"
              @click="loadRecipients"
            >
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>

            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Recipient"
              no-caps
              dense
              class="action-btn text-weight-bold col-auto q-px-sm"
              @click="openCreateRecipientDialog"
            />
          </div>

          <!-- Recipient Skeleton Loading State -->
          <div
            v-if="recipientStore.loading && !recipientItems.length"
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
                    <q-skeleton type="text" width="300px" height="13px" />
                  </div>
                </div>
                <div class="item-aside">
                  <q-skeleton type="QBtn" size="xs" width="20px" height="20px" />
                </div>
              </div>
            </div>
          </div>

          <!-- Recipient Zero State (No Profiles) -->
          <div
            v-else-if="!recipientItems.length"
            class="column items-center justify-center q-pa-xl text-center col clean-list-card"
          >
            <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
              <q-icon name="ph ph-identification-badge" size="28px" />
            </q-avatar>
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
              No Recipient Profiles Found
            </div>
            <p class="text-caption text-grey-6 q-mb-md" style="max-width: 380px">
              Manage saved delivery addresses and end-customer profiles for retail and dropship invoices.
            </p>
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Recipient"
              no-caps
              dense
              class="action-btn text-weight-bold q-px-md"
              @click="openCreateRecipientDialog"
            />
          </div>

          <!-- Recipient No Filter Matches State -->
          <div
            v-else-if="!filteredRecipientItems.length"
            class="column items-center justify-center text-center text-grey-7 q-py-xl col clean-list-card"
          >
            <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
            <div class="text-subtitle2 text-weight-medium text-slate-800">No recipient profiles found</div>
            <div class="text-caption text-grey-6 q-mt-xs">Try searching with a different keyword or select all child tenants.</div>
          </div>

          <!-- Recipient Linear-Style List Container -->
          <div v-else class="clean-list-card col">
            <div class="clean-list-scroll">
              <div
                v-for="row in filteredRecipientItems"
                :key="row.id"
                class="clean-list-item"
                @click="openRecipientDrawer(row)"
              >
                <!-- Left Side: Avatar + Recipient Name + Meta Line -->
                <div class="item-main-info row items-center no-wrap">
                  <q-avatar size="32px" class="item-avatar flex-shrink-0 q-mr-sm">
                    {{ getInitials(row.name) }}
                  </q-avatar>
                  <div class="item-info">
                    <div class="item-title-line">
                      <span class="item-name">{{ row.name }}</span>
                      <span
                        v-if="isParentTenant && row.tenant_name"
                        class="tenant-tag q-ml-xs"
                      >
                        <q-icon name="ph ph-buildings" size="12px" class="q-mr-2xs" />
                        {{ row.tenant_name }}
                      </span>
                    </div>
                    <div class="item-meta-line">
                      <span class="meta-item">{{ row.phone }}</span>
                      <span v-if="row.secondary_phone" class="meta-dot">·</span>
                      <span v-if="row.secondary_phone" class="meta-item">Alt: {{ row.secondary_phone }}</span>
                      <span v-if="row.district || row.thana" class="meta-dot">·</span>
                      <span v-if="row.district || row.thana" class="meta-item">{{ [row.district, row.thana].filter(Boolean).join(', ') }}</span>
                      <span v-if="row.address" class="meta-dot">·</span>
                      <span v-if="row.address" class="meta-item meta-address">{{ row.address }}</span>
                    </div>
                  </div>
                </div>

                <!-- Right Side: Chevron -->
                <div class="item-aside">
                  <q-icon name="ph ph-caret-right" size="16px" class="item-chevron" />
                </div>
              </div>
            </div>
          </div>
        </div>
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

    <!-- Recipient Detail Drawer -->
    <RecipientDetailDrawer
      v-model="recipientDrawerOpen"
      :recipient="selectedRecipient"
      :is-parent-tenant="isParentTenant"
      @deleted="onDrawerRecipientDeleted"
    />

    <!-- Recipient Create Dialog -->
    <q-dialog v-model="recipientDialogOpen" persistent>
      <q-card style="min-width: 480px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div>
            <div class="text-subtitle1 text-weight-bold">
              Create Recipient Profile
            </div>
            <div class="text-caption text-grey-6">Fill in courier-ready delivery details below</div>
          </div>
          <q-space />
          <q-btn v-close-popup icon="ph ph-x" flat round dense aria-label="Close" />
        </q-card-section>

        <q-form @submit.prevent="onRecipientFormSubmit">
          <q-card-section class="q-gutter-sm">
            <q-input
              v-model="recipientForm.name"
              label="Recipient Name *"
              outlined
              dense
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Name is required']"
            />
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model="recipientForm.phone"
                  label="Primary Phone *"
                  outlined
                  dense
                  class="soft-input"
                  lazy-rules
                  :rules="[(val) => (val && val.trim().length > 0) || 'Phone is required']"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model="recipientForm.secondary_phone"
                  label="Secondary Phone"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model="recipientForm.district"
                  label="District *"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model="recipientForm.thana"
                  label="Thana / Upazila *"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
            </div>
            <q-input
              v-model="recipientForm.address"
              label="Delivery Address *"
              outlined
              dense
              type="textarea"
              rows="3"
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Address is required']"
            />
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat no-caps label="Cancel" v-close-popup class="action-btn" />
            <q-btn
              color="primary"
              no-caps
              unelevated
              label="Create Profile"
              :loading="recipientStore.saving"
              type="submit"
              class="action-btn px-md text-weight-medium"
            />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useInfiniteCustomerListQuery, useCustomerMutations } from '../composables/useCustomerQuery';
import type { CustomerAccount } from '../types/customer';
import CustomerDetailDrawer from '../components/CustomerDetailDrawer.vue';
import RecipientDetailDrawer from '../components/RecipientDetailDrawer.vue';
import CreateCustomerDialog from '../components/CreateCustomerDialog.vue';
import { useCanAdministerCustomerGroup } from '../composables/useCanAdministerCustomerGroup';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import type { RecipientProfile } from 'src/types/recipientProfile';
import {
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';

type ActiveTab = 'customer' | 'recipient';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const tenantId = computed(() => authStore.tenantId as number);
const { hasModuleAccess } = useModulePermissions();
const { isParentTenant } = useInvoiceWorkspace();
const canAdministerCustomerGroup = useCanAdministerCustomerGroup();
const recipientStore = useRecipientProfileStore();

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
};

const openCustomerDrawer = (customer: CustomerAccount) => {
  selectedCustomer.value = customer;
  drawerOpen.value = true;
};

/* ----------------------------------------------------
   RECIPIENT TAB LOGIC
---------------------------------------------------- */
const recipientSearchText = ref('');
const recipientDialogOpen = ref(false);
const recipientDrawerOpen = ref(false);
const selectedRecipient = ref<RecipientProfile | null>(null);

const recipientForm = reactive({
  name: '',
  phone: '',
  secondary_phone: '',
  district: 'Dhaka',
  thana: 'Uttara',
  address: '',
});

const recipientItems = computed(() => recipientStore.items);

const selectedChildTenantId = ref<number | null>(null);

const childTenantOptions = computed(() => {
  const map = new Map<number, string>();
  for (const item of recipientItems.value) {
    if (item.tenant_id && item.tenant_name) {
      map.set(item.tenant_id, item.tenant_name);
    }
  }
  for (const t of tenantStore.items) {
    if (t.parent_id === tenantId.value) {
      map.set(t.id, t.name);
    }
  }
  const options: { label: string; value: number | null }[] = [
    { label: 'All Child Tenants', value: null },
  ];
  for (const [id, name] of map.entries()) {
    options.push({ label: name, value: id });
  }
  return options;
});

const filteredRecipientItems = computed(() => {
  const search = recipientSearchText.value.trim().toLowerCase();
  return recipientItems.value.filter((row) => {
    if (selectedChildTenantId.value !== null && row.tenant_id !== selectedChildTenantId.value) {
      return false;
    }
    if (!search) return true;
    return [
      row.name,
      row.phone,
      row.address,
      row.district || '',
      row.thana || '',
      row.secondary_phone || '',
      row.tenant_name || '',
    ].some((val) => val.toLowerCase().includes(search));
  });
});

const loadRecipients = async () => {
  if (!tenantId.value) return;
  await recipientStore.fetchRecipientProfiles(tenantId.value, isParentTenant.value);
};

watch(
  () => [tenantId.value, activeTab.value, isParentTenant.value] as const,
  ([newTenantId, newTab]) => {
    if (newTenantId && newTab === 'recipient' && hasRecipientAccess.value) {
      void loadRecipients();
    }
  },
);

const openCreateRecipientDialog = () => {
  recipientForm.name = '';
  recipientForm.phone = '';
  recipientForm.secondary_phone = '';
  recipientForm.district = 'Dhaka';
  recipientForm.thana = 'Uttara';
  recipientForm.address = '';
  recipientDialogOpen.value = true;
};

const openRecipientDrawer = (recipient: RecipientProfile) => {
  selectedRecipient.value = recipient;
  recipientDrawerOpen.value = true;
};

const onDrawerRecipientDeleted = () => {
  recipientDrawerOpen.value = false;
  selectedRecipient.value = null;
};

const onRecipientFormSubmit = async () => {
  if (!tenantId.value) return;

  const secondary = recipientForm.secondary_phone.trim() || null;
  const districtVal = recipientForm.district.trim() || null;
  const thanaVal = recipientForm.thana.trim() || null;

  const payload = isParentTenant.value
    ? {
        parent_tenant_id: tenantId.value,
        name: recipientForm.name.trim(),
        phone: recipientForm.phone.trim(),
        address: recipientForm.address.trim(),
        secondary_phone: secondary,
        district: districtVal,
        thana: thanaVal,
      }
    : {
        tenant_id: tenantId.value,
        name: recipientForm.name.trim(),
        phone: recipientForm.phone.trim(),
        address: recipientForm.address.trim(),
        secondary_phone: secondary,
        district: districtVal,
        thana: thanaVal,
      };

  const res = await recipientStore.upsertByPhone(payload);
  if (res.success) {
    recipientDialogOpen.value = false;
  }
};

/* ----------------------------------------------------
   HELPERS & LIFECYCLE
---------------------------------------------------- */
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

onMounted(() => {
  initTab();
  if (hasRecipientAccess.value) {
    void loadRecipients();
  }
});
</script>

<style scoped>
.customer-overview-page {
  background: var(--bw-brand-base, #eef0f4);
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

.clean-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--bw-neutral-surface, #ffffff);
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
  border-radius: var(--bw-radius-sm, 8px);
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.clean-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.clean-list-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--bw-neutral-border, #f1f5f9);
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 52px;
}

.clean-list-item:hover {
  background: #f8fafc;
}

.clean-list-item:hover .item-name {
  color: #0f172a;
}

.clean-list-item:hover .item-chevron {
  color: #0f172a;
  transform: translateX(2px);
}

.item-main-info {
  min-width: 0;
  flex: 1 1 auto;
}

.item-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.item-title-line {
  display: flex;
  align-items: center;
  gap: 6px;
}

.item-name {
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: -0.01em;
}

.item-meta-line {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  color: #64748b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.meta-item {
  font-weight: 400;
}

.meta-address {
  max-width: 320px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.meta-subtext {
  font-size: 12px;
  color: #64748b;
  font-weight: normal;
}

.meta-dot {
  color: #94a3b8;
  font-weight: 700;
}

.item-aside {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
  margin-left: 1rem;
}

.item-avatar {
  background: #e2e8f0;
  color: #475569;
  font-size: 12px;
  font-weight: 600;
  border-radius: 6px;
}

.tenant-tag {
  display: inline-flex;
  align-items: center;
  padding: 1.5px 6px;
  border-radius: 4px;
  background: #f1f5f9;
  color: #334155;
  font-size: 11px;
  font-weight: 500;
}

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

.item-chevron {
  color: #94a3b8;
  transition: all 0.15s ease;
}

.clean-list-item--skeleton {
  cursor: default;
}

.clean-list-item--skeleton:hover {
  background: transparent;
}

.load-more-btn {
  background: #f1f5f9;
  border-radius: var(--bw-radius-sm, 8px);
  font-size: 12px;
  transition: all 0.15s ease;
}

.load-more-btn:hover {
  background: #e2e8f0;
  color: #0f172a;
}

.numeric-cell {
  font-variant-numeric: tabular-nums;
  font-size: 13px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.dense-tenant-select :deep(.q-field__control) {
  border-radius: 8px;
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

body.body--dark .clean-list-card {
  background: #1e1e1e;
  border-color: #2e2e2e;
}

body.body--dark .clean-list-item {
  border-bottom-color: #2a2a2a;
}

body.body--dark .clean-list-item:hover {
  background: rgba(255, 255, 255, 0.04);
}

body.body--dark .load-more-btn {
  background: #262626;
  color: #f1f5f9;
}

body.body--dark .load-more-btn:hover {
  background: #333333;
}

body.body--dark .item-name {
  color: #f1f5f9;
}

body.body--dark .item-avatar {
  background: #334155;
  color: #e2e8f0;
}

body.body--dark .tenant-tag {
  background: #2a2a2a;
  color: #94a3b8;
}

body.body--dark .status-pill--inactive {
  background: #2a2a2a;
  color: #94a3b8;
}

body.body--dark .search-box :deep(.q-field--outlined .q-field__control:before) {
  border-color: #334155;
}
</style>
