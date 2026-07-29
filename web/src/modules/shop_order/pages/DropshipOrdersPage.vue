<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Shop &amp; Order</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Dropship Operations Desk</h1>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            color="primary"
            unelevated
            icon="ph ph-bank"
            label="Finance Hub"
            no-caps
            :to="{ name: 'app-shop-dropship-finance-hub-page' }"
          />
          <q-btn
            outline
            color="primary"
            icon="ph ph-truck"
            label="Courier Catalog"
            no-caps
            :to="{ name: 'app-shop-dropship-couriers-page' }"
          />
          <q-btn
            outline
            color="secondary"
            icon="ph ph-storefront"
            label="Merchants & Pickup"
            no-caps
            :to="{ name: 'app-shop-dropship-merchants-page' }"
          />
        </div>
      </section>

      <!-- Filters & Search Toolbar -->
      <q-card flat bordered class="form-card q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              hide-bottom-space
              placeholder="Search order no, recipient, phone, AWB..."
              clearable
              debounce="300"
              @update:model-value="onSearchChange"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>

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
              <th class="text-left">Courier</th>
              <th class="text-left">AWB</th>
              <th class="text-left">Status</th>
              <th class="text-right">COD Collect</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="filteredOrders.length === 0">
              <td colspan="8" class="text-center text-grey-7 q-py-xl">
                <q-icon name="ph ph-tray" size="36px" class="text-grey-4 q-mb-xs" />
                <div>No dropship consignments found for this filter.</div>
              </td>
            </tr>
            <tr
              v-for="c in filteredOrders"
              :key="c.id"
              class="hover-row cursor-pointer"
              @click="goToOrderDetail(c.id)"
            >
              <td>
                <router-link
                  class="text-weight-bold text-primary text-decoration-none"
                  :to="{ name: 'app-shop-dropship-order-detail-page', params: { id: c.id } }"
                  @click.stop
                >
                  {{ c.order_no }}
                </router-link>
                <div class="text-caption text-grey-6">{{ formatDate(c.created_at) }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">
                  {{ c.customer_group_name || c.created_by_email || '—' }}
                </div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.recipient_name || '—' }}</div>
                <div class="text-caption text-grey-7">{{ c.recipient_phone || '—' }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.courier_name || 'Not Selected' }}</div>
              </td>
              <td>
                <div v-if="c.courier_awb_number" class="text-caption text-primary" style="font-family: monospace">
                  {{ c.courier_awb_number }}
                </div>
                <div v-else class="text-caption text-grey-5">—</div>
              </td>
              <td>
                <q-chip dense :color="getStatusColor(c.status)" text-color="white" size="sm">
                  {{ c.status.toUpperCase().replace(/_/g, ' ') }}
                </q-chip>
              </td>
              <td class="text-right text-weight-bold text-grey-9">
                {{ formatAmount(c.cod_collect_amount ?? c.total_amount ?? 0) }} BDT
              </td>
              <td class="text-right" @click.stop>
                <div class="row reverse q-gutter-xs justify-end items-center no-wrap">
                  <q-btn flat round dense icon="ph ph-dots-three-vertical" color="grey-7">
                    <q-menu auto-close anchor="bottom right" self="top right">
                      <q-list style="min-width: 140px">
                        <q-item clickable @click="deleteOrderFromList(c)">
                          <q-item-section avatar min-width="24px">
                            <q-icon name="ph ph-trash" color="negative" size="18px" />
                          </q-item-section>
                          <q-item-section class="text-negative">Delete</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </div>
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
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';
import {
  showSuccessNotification,
  showErrorNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';
import { shopOrderService } from '../services/shopOrderService';
import type { ShopOrder } from '../types';

const router = useRouter();
const authStore = useAuthStore();
const loading = ref(false);
const orders = ref<ShopOrder[]>([]);
const searchQuery = ref('');
const selectedStatus = ref<string>('all');

const actionOrderId = ref<number | null>(null);
const actionKind = ref<'delete' | null>(null);

const statusOptions = [
  { label: 'All Orders', val: 'all' },
  { label: 'Submitted', val: 'submitted' },
  { label: 'Confirmed', val: 'confirmed' },
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
      status: null,
      search: searchQuery.value.trim() || null,
    });
    orders.value = res.success && res.data ? res.data : [];
    if (!res.success && res.error) {
      showErrorNotification(res.error);
    }
  } catch (err) {
    console.error('Failed to load dropship orders:', err);
    showErrorNotification('Failed to load dropship orders.');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadOrders();
});

const onSelectStatus = (status: string) => {
  selectedStatus.value = status;
};

const onSearchChange = () => {
  void loadOrders();
};

const filteredOrders = computed(() => {
  if (selectedStatus.value === 'all') return orders.value;
  return orders.value.filter((c) => c.status === selectedStatus.value);
});

const getCountForStatus = (val: string) => {
  if (val === 'all') return orders.value.length;
  return orders.value.filter((c) => c.status === val).length;
};

const goToOrderDetail = (id: number) => {
  void router.push({ name: 'app-shop-dropship-order-detail-page', params: { id } });
};

const deleteOrderFromList = async (c: ShopOrder) => {
  const confirmed = await requestConfirmation(
    `Are you sure you want to delete order #${c.order_no}? This will permanently remove the order.`,
    'Delete Order',
  );
  if (!confirmed) return;

  actionOrderId.value = c.id;
  actionKind.value = 'delete';
  try {
    const { error } = await supabase.rpc('delete_shop_order', {
      p_order_id: c.id,
    });
    if (error) throw error;
    showSuccessNotification(`Order #${c.order_no} deleted successfully.`);
    await loadOrders();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to delete order.');
  } finally {
    actionOrderId.value = null;
    actionKind.value = null;
  }
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

const formatDate = (isoStr: string) => new Date(isoStr).toLocaleDateString();

const formatAmount = (n: number | null | undefined) =>
  Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
</script>
