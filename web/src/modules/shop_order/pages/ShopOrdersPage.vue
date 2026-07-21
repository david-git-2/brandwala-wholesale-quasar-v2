<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 q-my-none">{{ $t('shop_admin.shop_orders_title') }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.shop_orders_subtitle') }}
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            icon="local_shipping"
            label="Dropship Ops Desk"
            no-caps
            :to="{ name: 'app-shop-dropship-orders-page' }"
          />
        </div>
      </section>

      <!-- Shops Filter Button Group -->
      <div v-if="orderStore.shops.length > 0" class="row items-center q-mb-xs">
        <div class="col-12">
          <q-btn-toggle
            v-model="selectedShopId"
            dense
            unelevated
            no-caps
            toggle-color="primary"
            color="white"
            text-color="primary"
            class="soft-btn-toggle border-all-1"
            :options="shopToggleOptions"
            @update:model-value="onFilterChange"
          />
        </div>
      </div>

      <!-- Filters Toolbar -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            debounce="350"
            dense
            outlined
            :placeholder="$t('shop_admin.search_orders_placeholder')"
            @update:model-value="onFilterChange"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
          </q-input>
        </div>
        <div class="col-auto">
          <q-select
            v-model="statusFilter"
            dense
            outlined
            emit-value
            map-options
            :label="$t('shop_admin.filter_by_status')"
            :options="statusOptions"
            style="min-width: 150px"
            @update:model-value="onFilterChange"
          />
        </div>
      </section>

      <!-- Main Content -->
      <div v-if="orderStore.loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_orders') }}</div>
      </div>

      <div
        v-else-if="orderStore.orders.length === 0"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="receipt_long" size="80px" color="grey-3" class="q-mb-md" />
        <div class="text-h6 text-grey-6">{{ $t('shop_admin.no_orders_found') }}</div>
        <p class="text-body2 text-grey-5 q-mt-sm">
          {{ $t('shop_admin.no_orders_match') }}
        </p>
      </div>

      <div v-else class="column q-gutter-md">
        <q-card flat bordered class="order-table-card">
          <q-list separator>
            <q-item v-for="order in orderStore.orders" :key="order.id" class="q-py-md">
              <q-item-section>
                <div class="row items-center justify-between q-col-gutter-sm">
                  <!-- Order Identifiers -->
                  <div class="col-xs-12 col-sm-3 column">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                      order.order_no
                    }}</span>
                    <span class="text-caption text-grey-6">
                      {{ formatDate(order.created_at) }}
                    </span>
                  </div>

                  <!-- Shop & Group Context -->
                  <div class="col-xs-12 col-sm-3 column">
                    <span class="text-body2 text-weight-medium text-grey-9"
                      >{{ $t('shop_admin.shop_label') }} {{ order.shop_name }}</span
                    >
                    <span class="text-caption text-grey-6">
                      {{ $t('shop_admin.group_label') }} {{ order.customer_group_name }}
                    </span>
                  </div>

                  <!-- Item Stats -->
                  <div class="col-xs-12 col-sm-3 row items-center q-gutter-x-lg">
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.items_label') }}</span>
                      <span class="text-body2 text-weight-bold text-grey-8">{{
                        order.item_count
                      }}</span>
                    </div>
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.total_value') }}</span>
                      <span class="text-body2 text-weight-bold text-primary">
                        £{{ Number(order.total_amount || 0).toFixed(2) }}
                      </span>
                    </div>
                  </div>

                  <!-- Status badge & Actions -->
                  <div class="col-xs-12 col-sm-3 row items-center justify-end q-gutter-x-md">
                    <q-badge
                      :color="getStatusColor(order.status)"
                      text-color="white"
                      class="status-badge text-weight-bold q-py-xs q-px-sm"
                    >
                      {{ order.status.toUpperCase() }}
                    </q-badge>
                    <q-btn
                      v-if="order.shop_type_snapshot === 'dropship' && order.status === 'confirmed'"
                      unelevated
                      color="primary"
                      no-caps
                      dense
                      icon="local_shipping"
                      :label="$t('shop_admin.add_to_dropship_desk')"
                      class="q-px-md pill-btn text-weight-bold"
                      :loading="orderStore.saving"
                      @click="addToDropshipDesk(order.id)"
                    />
                    <q-btn
                      unelevated
                      color="secondary"
                      outline
                      no-caps
                      dense
                      :label="$t('shop_admin.manage')"
                      class="q-px-md pill-btn"
                      @click="goToOrderDetails(order.id)"
                    />
                  </div>
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { date } from 'quasar';

const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();
const orderStore = useShopOrderStore();

const search = ref('');
const statusFilter = ref(null);
const selectedShopId = ref<number | null>(null);

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const statusOptions = computed(() => [
  { label: t('shop_admin.all_statuses'), value: null },
  { label: t('shop_admin.status_submitted'), value: 'submitted' },
  { label: t('shop_admin.status_processing'), value: 'processing' },
  { label: t('shop_admin.status_shipped'), value: 'shipped' },
  { label: t('shop_admin.status_delivered'), value: 'delivered' },
  { label: t('shop_admin.status_payment_received'), value: 'payment_received' },
  { label: t('shop_admin.status_negotiating'), value: 'negotiating' },
  { label: t('shop_admin.status_priced'), value: 'priced' },
  { label: t('shop_admin.status_confirmed'), value: 'confirmed' },
  { label: t('shop_admin.status_placed'), value: 'placed' },
  { label: t('shop_admin.status_fulfilled'), value: 'fulfilled' },
  { label: t('shop_admin.status_cancelled'), value: 'cancelled' },
]);

const shopToggleOptions = computed(() => {
  const options: Array<{ label: string; value: number | null }> = [{ label: t('shop_admin.all_shops'), value: null }];
  orderStore.shops.forEach((shop) => {
    options.push({ label: shop.name, value: shop.id });
  });
  return options;
});

const loadOrders = async () => {
  if (tenantId.value) {
    await orderStore.fetchStaffOrders(tenantId.value, {
      search: search.value || null,
      status: statusFilter.value || null,
      shopId: selectedShopId.value,
    });
  }
};

onMounted(async () => {
  if (tenantId.value) {
    void orderStore.fetchShopsByTenant(tenantId.value);
  }
  await loadOrders();
});

const onFilterChange = () => {
  void loadOrders();
};

const goToOrderDetails = (orderId: number) => {
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders/${orderId}`);
};

const addToDropshipDesk = async (orderId: number) => {
  const res = await orderStore.processDropshipOrder(orderId);
  if (res.success) {
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push(`${slug}/app/shop/dropship/orders/${orderId}`);
  }
};


const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'ShopOrdersPage',
};
</script>

<style scoped>
.order-table-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.pill-btn {
  border-radius: 30px;
}

.status-badge {
  border-radius: 8px;
}

.empty-state {
  min-height: 350px;
}
</style>
