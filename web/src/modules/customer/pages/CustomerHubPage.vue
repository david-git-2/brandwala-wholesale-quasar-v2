<template>
  <q-page class="customer-hub-page page-fixed-layout q-pa-md">
    <div class="customer-container column no-wrap full-height">
      <!-- 1. Top Unified Toolbar: Zero In-Page Headers, Search & Count (Left), Refresh & Create (Right) -->
      <div class="customer-toolbar floating-surface shadow-1 q-pa-sm q-mb-md">
        <div class="row items-center justify-between q-col-gutter-sm no-wrap">
          <!-- Left: Outlined Rounded Search Box & Count Badge -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-input
              v-model="searchQuery"
              outlined
              rounded
              dense
              placeholder="Search customer, admin, phone, email, address..."
              class="search-box"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-6" />
              </template>
              <template #append v-if="searchQuery">
                <q-icon
                  name="ph ph-x-circle"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="searchQuery = ''"
                />
              </template>
            </q-input>

            <q-chip dense square color="grey-2" text-color="grey-8" class="text-weight-bold text-caption q-ma-none">
              {{ customers.length }} {{ customers.length === 1 ? 'Customer' : 'Customers' }}
            </q-chip>
          </div>

          <!-- Right: Refresh & Primary Create Customer Action Button -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-clockwise"
              color="grey-7"
              :loading="customersQuery.isFetching.value"
              @click="customersQuery.refetch()"
            >
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>

            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Customer"
              no-caps
              class="action-btn text-weight-bold"
              @click="openCreateCustomerDialog"
            />
          </div>
        </div>
      </div>

      <!-- 2. Customer List Table with Sticky Headers and Internal Scroll -->
      <div class="col customer-table-wrap floating-surface shadow-1">
        <q-markup-table flat wrap-cells class="customer-table full-height">
          <thead>
            <tr>
              <th class="text-left" style="width: 280px">Customer &amp; Admin</th>
              <th class="text-left">Contact Info</th>
              <th class="text-left">Address</th>
              <th class="text-center" style="width: 100px">Members</th>
              <th class="text-right" style="width: 160px">Wallet Balance</th>
              <th class="text-center" style="width: 90px">Status</th>
            </tr>
          </thead>
          <tbody>
            <!-- Empty state -->
            <tr v-if="!customers.length && !customersQuery.isLoading.value">
              <td colspan="6" class="q-pa-none">
                <div class="column items-center justify-center q-pa-xl text-center">
                  <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
                    <q-icon name="ph ph-users" size="28px" />
                  </q-avatar>
                  <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
                    No Customers Found
                  </div>
                  <p class="text-caption text-grey-6 q-mb-md" style="max-width: 380px">
                    Create customer accounts to manage wholesale buyers, credit ledgers, and storefront access.
                  </p>
                  <q-btn
                    unelevated
                    color="primary"
                    icon="ph ph-plus"
                    label="Create Customer"
                    no-caps
                    class="action-btn text-weight-bold"
                    @click="openCreateCustomerDialog"
                  />
                </div>
              </td>
            </tr>

            <!-- Data Rows -->
            <tr
              v-for="customer in customers"
              :key="customer.id"
              class="customer-row cursor-pointer"
              :style="{
                boxShadow: customer.accent_color
                  ? `inset 3px 0 0 ${customer.accent_color}`
                  : 'inset 3px 0 0 #B45F34',
              }"
              @click="openCustomerDrawer(customer)"
            >
              <!-- 1. Customer & Admin Identity -->
              <td>
                <div class="row items-center no-wrap">
                  <q-avatar
                    size="36px"
                    text-color="white"
                    class="q-mr-sm text-weight-bold flex-shrink-0"
                    :style="{
                      backgroundColor: customer.accent_color || '#B45F34',
                    }"
                  >
                    {{ getInitials(customer.group_name) }}
                  </q-avatar>
                  <div class="ellipsis">
                    <div class="text-weight-bold text-grey-9 ellipsis">
                      {{ customer.group_name }}
                    </div>
                    <div class="text-caption text-grey-7 ellipsis">
                      {{ customer.admin_name }}
                    </div>
                  </div>
                </div>
              </td>

              <!-- 2. Contact Info -->
              <td>
                <div class="column">
                  <div v-if="customer.email" class="row items-center text-caption text-grey-9 no-wrap">
                    <q-icon name="ph ph-envelope" size="14px" class="q-mr-xs text-grey-6" />
                    <span>{{ customer.email }}</span>
                  </div>
                  <div v-if="customer.phone" class="row items-center text-caption text-grey-7 no-wrap q-mt-xs">
                    <q-icon name="ph ph-phone" size="14px" class="q-mr-xs text-grey-6" />
                    <span>{{ customer.phone }}</span>
                  </div>
                  <span v-if="!customer.email && !customer.phone" class="text-caption text-grey-5">—</span>
                </div>
              </td>

              <!-- 3. Address -->
              <td>
                <div class="text-caption text-grey-8 ellipsis-2-lines" style="max-width: 240px">
                  {{ customer.address || '—' }}
                </div>
              </td>

              <!-- 4. Member Count -->
              <td class="text-center">
                <q-chip dense square color="grey-2" text-color="grey-8" class="text-weight-medium text-caption q-ma-none">
                  {{ customer.member_count }}
                </q-chip>
              </td>

              <!-- 5. Wallet Available Balance -->
              <td class="text-right">
                <span class="text-weight-bold font-mono" :class="customer.wallet_available_balance >= 0 ? 'text-grey-9' : 'text-negative'">
                  {{ formatBdt(customer.wallet_available_balance) }}
                </span>
              </td>

              <!-- 6. Status -->
              <td class="text-center">
                <q-badge
                  :color="customer.is_active ? 'positive' : 'grey-5'"
                  class="q-px-sm q-py-xs text-weight-bold"
                  rounded
                >
                  {{ customer.is_active ? 'Active' : 'Inactive' }}
                </q-badge>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>

    <!-- Right Side Detail Drawer for Customer Details, Editable Fields & Members -->
    <CustomerDetailDrawer
      v-model="drawerOpen"
      :customer="selectedCustomer"
      :tenant-id="tenantId"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerListQuery } from '../composables/useCustomerQuery';
import type { CustomerAccount } from '../types/customer';
import CustomerDetailDrawer from '../components/CustomerDetailDrawer.vue';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const searchQuery = ref('');
const tenantId = computed(() => authStore.tenantId as number);

const drawerOpen = ref(false);
const selectedCustomer = ref<CustomerAccount | null>(null);

const customersQuery = useCustomerListQuery(tenantId, searchQuery);
const customers = computed(() => customersQuery.data.value ?? []);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const openCreateCustomerDialog = () => {
  void router.push(`${getTenantPrefix()}/app/customers/create`);
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
  background: var(--bw-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  overflow: hidden;
}

.customer-container {
  height: 100%;
}

.customer-toolbar {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  width: 320px;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 4px 12px -2px rgba(51, 65, 85, 0.05);
}

.customer-table-wrap {
  min-height: 0;
  overflow: hidden;
  border-radius: 8px;
}

.customer-table {
  height: 100%;
  background: #ffffff;
}

.customer-table :deep(.q-table__middle) {
  overflow-y: auto;
  max-height: 100%;
}

.customer-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  font-weight: 700;
  color: #475569;
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
}

.customer-row {
  transition: background-color 0.15s ease-in-out;
}

.customer-row:hover {
  background-color: rgba(241, 245, 249, 0.6);
}

/* Dark Mode */
body.body--dark .customer-hub-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .customer-toolbar,
body.body--dark .customer-table {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .customer-table :deep(thead tr th) {
  background: #242424;
  color: #94a3b8;
  border-color: #2e2e2e;
}

body.body--dark .customer-row:hover {
  background-color: rgba(255, 255, 255, 0.04);
}
</style>
