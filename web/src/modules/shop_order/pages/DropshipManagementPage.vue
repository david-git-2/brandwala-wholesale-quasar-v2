<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <q-card flat bordered class="form-card q-pa-sm">
        <div class="row items-center q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              clearable
              debounce="300"
              placeholder="Search order no, merchant, recipient..."
              @update:model-value="onSearchChange"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6 col-md-3">
            <q-select
              v-model="statusFilter"
              dense
              outlined
              emit-value
              map-options
              :options="statusOptions"
              label="Status"
              @update:model-value="onStatusChange"
            />
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-py-xl">
          <q-spinner color="primary" size="3em" />
        </div>
        <q-list v-else separator>
          <q-item v-if="orders.length === 0" class="justify-center">
            <q-item-section class="text-center text-grey-6">
              No orders match your search or filter.
            </q-item-section>
          </q-item>

          <q-item
            v-for="order in orders"
            :key="order.id"
            v-ripple
            clickable
            @click="goToDetail(order.id)"
          >
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ order.order_no }}</q-item-label>
              <q-item-label caption>
                {{ order.customer_group_name || '—' }} · {{ order.recipient_name || '—' }} ·
                {{ order.courier_name || '—' }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge :color="statusColor(order.status)" :label="statusLabel(order.status)" />
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { showErrorNotification } from 'src/utils/appFeedback';
import { shopOrderService } from '../services/shopOrderService';
import type { ShopOrder, ShopOrderStatus } from '../types';

const DROPSHIP_MANAGEMENT_STATUSES = [
  'shipped',
  'delivered',
  'payment_received',
  'reseller_paid',
  'returned',
] as const satisfies readonly ShopOrderStatus[];

type DropshipManagementStatusFilter = 'all' | (typeof DROPSHIP_MANAGEMENT_STATUSES)[number];

const router = useRouter();
const authStore = useAuthStore();

const loading = ref(false);
const orders = ref<ShopOrder[]>([]);
const searchQuery = ref('');
const statusFilter = ref<DropshipManagementStatusFilter>('all');

const statusOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Payment received', value: 'payment_received' },
  { label: 'Reseller paid', value: 'reseller_paid' },
  { label: 'Returned', value: 'returned' },
] as const;

function resolveStatusPayload(filter: DropshipManagementStatusFilter): ShopOrderStatus[] {
  if (filter === 'all') return [...DROPSHIP_MANAGEMENT_STATUSES];
  return [filter];
}

const loadOrders = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const res = await shopOrderService.fetchDropshipStaffOrders(authStore.tenantId, {
      limit: 200,
      statuses: resolveStatusPayload(statusFilter.value),
      search: searchQuery.value.trim() || null,
    });
    orders.value = res.success && res.data ? res.data : [];
    if (!res.success && res.error) {
      showErrorNotification(res.error);
    }
  } catch (err) {
    console.error('Failed to load dropship management orders:', err);
    showErrorNotification('Failed to load dropship management orders.');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadOrders();
});

watch(
  () => authStore.tenantId,
  (tenantId) => {
    if (tenantId) void loadOrders();
  },
);

const onSearchChange = () => {
  void loadOrders();
};

const onStatusChange = () => {
  void loadOrders();
};

function statusLabel(status: ShopOrderStatus): string {
  if (status === 'payment_received') return 'Payment received';
  if (status === 'reseller_paid') return 'Reseller paid';
  return status.charAt(0).toUpperCase() + status.slice(1);
}

function statusColor(status: ShopOrderStatus): string {
  const colors: Partial<Record<ShopOrderStatus, string>> = {
    shipped: 'amber-9',
    delivered: 'positive',
    payment_received: 'info',
    reseller_paid: 'primary',
    returned: 'negative',
  };
  return colors[status] ?? 'grey-7';
}

function goToDetail(id: number) {
  router.push({ name: 'app-shop-dropship-management-detail-page', params: { id } });
}
</script>

<script lang="ts">
export default {
  name: 'DropshipManagementPage',
};
</script>
