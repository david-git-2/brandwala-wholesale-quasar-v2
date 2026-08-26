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
            />
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="form-card">
        <q-list separator>
          <q-item v-if="filteredOrders.length === 0" class="justify-center">
            <q-item-section class="text-center text-grey-6">
              No orders match your search or filter.
            </q-item-section>
          </q-item>

          <q-item
            v-for="order in filteredOrders"
            :key="order.id"
            v-ripple
            clickable
            @click="goToDetail(order.id)"
          >
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ order.name }}</q-item-label>
              <q-item-label caption>
                {{ order.merchant }} · {{ order.recipient }} · {{ order.courierName }}
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
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import {
  dropshipManagementDummyOrders,
  type DropshipManagementOrderStatus,
} from '../data/dropshipManagementDummyOrders';

const router = useRouter();

const searchQuery = ref('');
const statusFilter = ref<DropshipManagementOrderStatus | 'all'>('all');

const statusOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Pending', value: 'pending' },
  { label: 'Processing', value: 'processing' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
] as const;

const dummyOrders = dropshipManagementDummyOrders;

const filteredOrders = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();

  return dummyOrders.filter((order) => {
    const matchesStatus = statusFilter.value === 'all' || order.status === statusFilter.value;
    const matchesSearch =
      !query ||
      order.name.toLowerCase().includes(query) ||
      order.merchant.toLowerCase().includes(query) ||
      order.recipient.toLowerCase().includes(query);

    return matchesStatus && matchesSearch;
  });
});

function statusLabel(status: DropshipManagementOrderStatus): string {
  return status.charAt(0).toUpperCase() + status.slice(1);
}

function statusColor(status: DropshipManagementOrderStatus): string {
  const colors: Record<DropshipManagementOrderStatus, string> = {
    pending: 'grey-7',
    processing: 'primary',
    shipped: 'amber-9',
    delivered: 'positive',
  };
  return colors[status];
}

function goToDetail(id: string) {
  router.push({ name: 'app-shop-dropship-management-detail-page', params: { id } });
}
</script>

<script lang="ts">
export default {
  name: 'DropshipManagementPage',
};
</script>
