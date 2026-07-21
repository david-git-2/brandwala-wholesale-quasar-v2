<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order</div>
          <h1 class="text-h5 q-my-none">Dropship Operations Desk</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Queue and process middle-man orders for courier dispatch and profit settlement.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            icon="local_shipping"
            label="Courier Catalog"
            no-caps
            :to="{ name: 'app-shop-dropship-couriers-page' }"
          />
          <q-btn
            outline
            color="secondary"
            icon="storefront"
            label="Merchants & Pickup"
            no-caps
            :to="{ name: 'app-shop-dropship-merchants-page' }"
          />
          <q-btn
            outline
            color="secondary"
            icon="account_balance_wallet"
            label="Payout Ledger"
            no-caps
            :to="{ name: 'app-shop-dropship-ledger-page' }"
          />
        </div>
      </section>

      <!-- Filters & Search Toolbar -->
      <q-card flat bordered class="form-card q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-md">
          <!-- Search Input -->
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              hide-bottom-space
              placeholder="Search order no, recipient, phone, AWB..."
              clearable
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>

          <!-- Status Stepper Chips Filter -->
          <div class="col-12 col-sm-6 col-md-auto row q-gutter-xs items-center">
            <q-chip
              v-for="st in statusOptions"
              :key="st.val"
              clickable
              :outline="selectedStatus !== st.val"
              :color="selectedStatus === st.val ? 'primary' : 'grey-4'"
              :text-color="selectedStatus === st.val ? 'white' : 'grey-9'"
              @click="onSelectStatus(st.val)"
            >
              {{ st.label }} ({{ getCountForStatus(st.val) }})
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Orders Table Card -->
      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-py-xl">
          <q-spinner color="primary" size="3em" />
        </div>
        <q-markup-table v-else flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Order No</th>
              <th class="text-left">Middle Man</th>
              <th class="text-left">Recipient</th>
              <th class="text-left">Courier &amp; AWB</th>
              <th class="text-left">Status</th>
              <th class="text-right">COD Collect</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="filteredOrders.length === 0">
              <td colspan="7" class="text-center text-grey-7 q-py-xl">
                <q-icon name="inbox" size="36px" class="text-grey-4 q-mb-xs" />
                <div>No dropship consignments found for this filter.</div>
              </td>
            </tr>
            <tr v-for="c in filteredOrders" :key="c.id" class="hover-row">
              <td>
                <div class="text-weight-bold text-primary">{{ c.order_no }}</div>
                <div class="text-caption text-grey-6">{{ formatDate(c.created_at) }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.customer_group_name || c.created_by_email || '—' }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.recipient_name || '—' }}</div>
                <div class="text-caption text-grey-7">
                  {{ c.recipient_phone || '—' }}
                </div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ (c as any).courier_name || 'Not Selected' }}</div>
                <div class="text-caption text-primary" v-if="(c as any).courier_awb_number">AWB: {{ (c as any).courier_awb_number }}</div>
              </td>
              <td>
                <q-chip dense :color="getStatusColor(c.status)" text-color="white" size="sm">
                  {{ c.status.toUpperCase().replace(/_/g, ' ') }}
                </q-chip>
              </td>
              <td class="text-right text-weight-bold text-grey-9">
                {{ (c as any).cod_collect_amount ?? c.total_amount ?? 0 }} BDT
              </td>
              <td class="text-right">
                <q-btn
                  color="primary"
                  unelevated
                  size="sm"
                  no-caps
                  label="Process Order"
                  :to="{ name: 'app-shop-dropship-order-detail-page', params: { id: c.id } }"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderService } from '../services/shopOrderService';
import type { ShopOrder } from '../types';

const authStore = useAuthStore();
const loading = ref(false);
const orders = ref<ShopOrder[]>([]);
const searchQuery = ref('');
const selectedStatus = ref<string>('all');

const statusOptions = [
  { label: 'All Orders', val: 'all' },
  { label: 'Processing', val: 'processing' },
  { label: 'Ready for Pickup', val: 'ready_for_pickup' },
  { label: 'Shipped', val: 'shipped' },
  { label: 'Delivered', val: 'delivered' },
  { label: 'Returned', val: 'returned' },
];

const loadOrders = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const res = await shopOrderService.fetchDropshipStaffOrders(authStore.tenantId, {
      limit: 200,
      status: selectedStatus.value === 'all' ? null : selectedStatus.value,
      search: searchQuery.value.trim() || null,
    });
    orders.value = res.success && res.data ? res.data : [];
  } catch (err) {
    console.error('Failed to load dropship orders:', err);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadOrders();
});

const onSelectStatus = (status: string) => {
  selectedStatus.value = status;
  void loadOrders();
};

const filteredOrders = computed(() => {
  let res = orders.value;
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    res = res.filter(
      (c) =>
        (c.order_no && c.order_no.toLowerCase().includes(q)) ||
        (c.recipient_name && c.recipient_name.toLowerCase().includes(q)) ||
        (c.recipient_phone && c.recipient_phone.includes(q)) ||
        (c.customer_group_name && c.customer_group_name.toLowerCase().includes(q)) ||
        (c.created_by_email && c.created_by_email.toLowerCase().includes(q)) ||
        ((c as any).courier_name && (c as any).courier_name.toLowerCase().includes(q)) ||
        ((c as any).courier_awb_number && (c as any).courier_awb_number.toLowerCase().includes(q)),
    );
  }
  return res;
});

const getCountForStatus = (val: string) => {
  if (val === 'all') return orders.value.length;
  return orders.value.filter((c) => c.status === val).length;
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'processing':
      return 'orange-8';
    case 'ready_for_pickup':
      return 'blue-7';
    case 'shipped':
      return 'purple-7';
    case 'delivered':
      return 'positive';
    case 'returned':
      return 'negative';
    default:
      return 'grey';
  }
};

const formatDate = (isoStr: string) => {
  return new Date(isoStr).toLocaleDateString();
};
</script>
