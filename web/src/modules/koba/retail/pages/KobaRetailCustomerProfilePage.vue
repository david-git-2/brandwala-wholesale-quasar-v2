<template>
  <q-page class="q-pa-md bw-page">
    <!-- Header -->
    <div class="row items-center q-mb-md justify-between">
      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          round
          icon="arrow_back"
          color="grey-8"
          :to="{ name: 'app-koba-retail-customers-page' }"
        />
        <div>
          <div class="text-h5 text-weight-bold text-grey-9">Customer Profile</div>
          <div class="text-caption text-grey-7">Detailed analysis for +{{ phone }}</div>
        </div>
      </div>
      <q-btn
        color="primary"
        outline
        icon="people"
        label="Back to Customer List"
        no-caps
        :to="{ name: 'app-koba-retail-customers-page' }"
      />
    </div>

    <!-- Loading Indicator -->
    <div v-if="loading && !profile" class="flex flex-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-negative text-center q-pa-md">
      {{ error }}
    </div>

    <div v-else-if="profile" class="q-gutter-y-md">
      <!-- Top Overview Panel: Customer info and high level statistics -->
      <div class="row q-col-gutter-md">
        <!-- Contact & Location Card -->
        <div class="col-12 col-md-6">
          <q-card flat bordered class="profile-card info-card full-height">
            <q-card-section>
              <div class="row items-center q-mb-md">
                <q-avatar size="48px" color="primary" text-color="white" class="text-weight-bold">
                  {{ profile.name ? profile.name.charAt(0).toUpperCase() : 'C' }}
                </q-avatar>
                <div class="q-ml-md">
                  <div class="text-h6 text-weight-bold text-grey-9">{{ profile.name || 'Walk-in Customer' }}</div>
                  <div class="text-subtitle2 text-grey-6">{{ profile.phone }}</div>
                </div>
              </div>

              <q-separator class="q-my-sm" />

              <div class="q-mt-md q-gutter-y-sm">
                <div class="row items-center">
                  <q-icon name="place" color="grey-6" size="sm" class="q-mr-sm" />
                  <div>
                    <span class="text-weight-bold text-grey-8">District:</span> {{ profile.district || '—' }}
                  </div>
                </div>
                <div class="row items-center">
                  <q-icon name="location_city" color="grey-6" size="sm" class="q-mr-sm" />
                  <div>
                    <span class="text-weight-bold text-grey-8">Thana:</span> {{ profile.thana || '—' }}
                  </div>
                </div>
                <div class="row items-start">
                  <q-icon name="home" color="grey-6" size="sm" class="q-mr-sm q-mt-xs" />
                  <div class="col">
                    <span class="text-weight-bold text-grey-8">Delivery Address:</span>
                    <div class="text-grey-8">{{ profile.address || '—' }}</div>
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Metrics Dashboard Summary -->
        <div class="col-12 col-md-6">
          <div class="row q-col-gutter-sm full-height">
            <!-- Total Orders -->
            <div class="col-6">
              <q-card flat bordered class="profile-card stat-card flex flex-center full-height">
                <q-card-section class="text-center">
                  <q-icon name="shopping_cart" size="md" color="primary" class="q-mb-xs" />
                  <div class="text-h4 text-weight-bold text-grey-9">{{ profile.total_orders }}</div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Total Orders</div>
                </q-card-section>
              </q-card>
            </div>

            <!-- Total Spent -->
            <div class="col-6">
              <q-card flat bordered class="profile-card stat-card flex flex-center full-height">
                <q-card-section class="text-center">
                  <q-icon name="payments" size="md" color="positive" class="q-mb-xs" />
                  <div class="text-h5 text-weight-bold text-positive">৳{{ Number(profile.total_spent).toFixed(2) }}</div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Total Spending</div>
                </q-card-section>
              </q-card>
            </div>

            <!-- Frequency & Timeline -->
            <div class="col-12 q-mt-sm">
              <q-card flat bordered class="profile-card stat-card q-pa-sm">
                <q-card-section>
                  <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm">Order Frequency</div>
                  <div class="row items-center justify-between">
                    <div>
                      <div class="text-weight-medium text-grey-9">
                        <span v-if="profile.avg_days_between_orders">Every {{ Number(profile.avg_days_between_orders).toFixed(1) }} days</span>
                        <span v-else>Single Purchase Only</span>
                      </div>
                      <div class="text-caption text-grey-6">
                        Active from {{ formatDate(profile.first_order_date, 'YYYY-MM-DD') }} to {{ formatDate(profile.last_order_date, 'YYYY-MM-DD') }}
                      </div>
                    </div>
                    <q-chip
                      :color="profile.avg_days_between_orders && profile.avg_days_between_orders < 15 ? 'positive' : 'blue-7'"
                      text-color="white"
                      dense
                      class="text-weight-bold"
                    >
                      {{ profile.avg_days_between_orders && profile.avg_days_between_orders < 15 ? 'Frequent Buyer' : 'Casual Buyer' }}
                    </q-chip>
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>
        </div>
      </div>

      <!-- Mid Section: Demand Analytics -->
      <div class="row q-col-gutter-md">
        <!-- Brand Demand Breakdown -->
        <div class="col-12 col-md-6">
          <q-card flat bordered class="profile-card full-height">
            <q-card-section>
              <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Top Brands Demand</div>
              <div v-if="profile.brand_demand.length === 0" class="text-grey-5 text-center q-py-xl">
                No brand data found
              </div>
              <div v-else class="q-gutter-y-md">
                <div v-for="b in profile.brand_demand" :key="b.brand">
                  <div class="row justify-between items-center q-mb-xs">
                    <span class="text-weight-medium text-grey-8">{{ b.brand }}</span>
                    <span class="text-caption text-grey-6">{{ b.order_count }} orders ({{ b.item_count }} units)</span>
                  </div>
                  <q-linear-progress
                    :value="b.order_count / profile.total_orders"
                    color="primary"
                    rounded
                    size="8px"
                  />
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Top Products Breakdown -->
        <div class="col-12 col-md-6">
          <q-card flat bordered class="profile-card full-height">
            <q-card-section>
              <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Top Products Purchased</div>
              <div v-if="profile.top_products.length === 0" class="text-grey-5 text-center q-py-xl">
                No product data found
              </div>
              <q-list v-else separator class="q-px-none">
                <q-item v-for="p in profile.top_products" :key="p.product_id" class="q-px-none q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-grey-9">{{ p.name }}</q-item-label>
                    <q-item-label caption v-if="p.brand" class="text-uppercase text-grey-6">{{ p.brand }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-chip outline color="primary" text-color="primary" class="text-weight-bold">
                      {{ p.total_quantity }} units
                    </q-chip>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- Bottom Section: Order History Timeline -->
      <q-card flat bordered class="profile-card q-mb-xl">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Order Timeline</div>
          <q-table
            :rows="profile.order_history"
            :columns="historyColumns"
            row-key="order_id"
            flat
            binary-state-sort
            class="bw-table"
            :pagination="{ rowsPerPage: 10 }"
          >
            <template #body="sp">
              <q-tr :props="sp" class="order-row cursor-pointer" @click="viewOrderDetails(sp.row.order_id)">
                <q-td key="order_id" :props="sp">
                  <span class="text-weight-bold text-primary">#{{ sp.row.order_id }}</span>
                </q-td>
                <q-td key="created_at" :props="sp" class="text-grey-8">
                  {{ formatDate(sp.row.created_at, 'YYYY-MM-DD HH:mm') }}
                </q-td>
                <q-td key="status" :props="sp">
                  <q-chip
                    :color="getStatusColor(sp.row.status)"
                    text-color="white"
                    dense
                    square
                    class="text-uppercase text-weight-bold text-caption"
                  >
                    {{ sp.row.status }}
                  </q-chip>
                </q-td>
                <q-td key="subtotal_gbp" :props="sp" class="text-weight-bold text-grey-9">
                  ৳{{ Number(sp.row.subtotal_gbp || 0).toFixed(2) }}
                </q-td>
                <q-td key="net_order_commission" :props="sp" class="text-weight-bold text-positive">
                  ৳{{ Number(sp.row.net_order_commission || 0).toFixed(2) }}
                </q-td>
                <q-td key="actions" :props="sp" align="right">
                  <q-btn
                    flat
                    round
                    color="primary"
                    icon="visibility"
                    size="sm"
                    @click.stop="viewOrderDetails(sp.row.order_id)"
                  >
                    <q-tooltip>View Order Details</q-tooltip>
                  </q-btn>
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </q-card-section>
      </q-card>
    </div>

    <!-- Order Detail Dialog -->
    <KobaOrderDetailDialog
      v-model="detailOpen"
      :order="orderStore.orderDetail?.order || null"
      :items="orderStore.orderDetail?.items || []"
      :loading="orderStore.loading"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { date } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaOrderStore } from 'src/modules/koba/retail/stores/kobaOrderStore'
import KobaOrderDetailDialog from 'src/modules/koba/retail/components/KobaOrderDetailDialog.vue'

interface BrandDemand {
  brand: string
  order_count: number
  item_count: number
}

interface TopProduct {
  product_id: string
  name: string
  brand: string
  total_quantity: number
}

interface OrderHistory {
  order_id: number
  subtotal_gbp: number
  net_order_commission: number
  status: string
  created_at: string
}

interface CustomerProfile {
  phone: string
  name: string
  district: string
  thana: string
  address: string
  total_orders: number
  total_spent: number
  first_order_date: string
  last_order_date: string
  avg_days_between_orders: number | null
  brand_demand: BrandDemand[]
  top_products: TopProduct[]
  order_history: OrderHistory[]
}

const props = defineProps<{
  phone: string
}>()

const authStore = useAuthStore()
const orderStore = useKobaOrderStore()

const loading = ref(false)
const error = ref<string | null>(null)
const profile = ref<CustomerProfile | null>(null)
const detailOpen = ref(false)

const tenantId = computed(() => authStore.tenantId)

const historyColumns = [
  { name: 'order_id', label: 'Order ID', align: 'left', field: 'order_id' },
  { name: 'created_at', label: 'Date Placed', align: 'left', field: 'created_at' },
  { name: 'status', label: 'Status', align: 'left', field: 'status' },
  { name: 'subtotal_gbp', label: 'Order Value', align: 'left', field: 'subtotal_gbp' },
  { name: 'net_order_commission', label: 'Commission Eearned', align: 'left', field: 'net_order_commission' },
  { name: 'actions', label: 'View', align: 'right', field: 'actions' }
] as const

async function fetchProfile() {
  if (!tenantId.value || !props.phone) return
  loading.value = true
  error.value = null
  try {
    const { data, error: rpcError } = await supabase.rpc('get_koba_customer_profile', {
      p_tenant_id: tenantId.value,
      p_phone: props.phone
    })

    if (rpcError) {
      error.value = rpcError.message || 'Failed to load customer profile'
      return
    }

    if (!data) {
      error.value = 'No customer profile found for the specified phone number.'
      return
    }

    profile.value = data as CustomerProfile
  } catch (err: unknown) {
    const exception = err as Error
    error.value = exception.message || 'Unexpected error occurred loading profile'
  } finally {
    loading.value = false
  }
}

async function viewOrderDetails(orderId: number) {
  detailOpen.value = true
  await orderStore.fetchOrderDetails(orderId)
}

function formatDate(val: string | null, formatStr: string) {
  if (!val) return '—'
  return date.formatDate(new Date(val), formatStr)
}

function getStatusColor(status: string) {
  switch (status) {
    case 'pending': return 'amber-8'
    case 'confirmed': return 'blue-7'
    case 'processing': return 'indigo-7'
    case 'shipped': return 'deep-purple-7'
    case 'delivered': return 'positive'
    case 'cancelled': return 'negative'
    default: return 'grey'
  }
}

onMounted(() => {
  void fetchProfile()
})
</script>

<style scoped>
.bw-page {
  background: #f8fafc;
}
.profile-card {
  border-radius: 12px;
  background: white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
.info-card {
  border-left: 4px solid var(--q-primary);
}
.stat-card {
  background: #ffffff;
}
.order-row {
  transition: background-color 0.15s ease;
}
.order-row:hover {
  background: rgba(37, 99, 235, 0.03);
}
.bw-table :deep(th) {
  font-weight: 700;
  color: var(--q-grey-9);
  background: #f1f5f9;
}
</style>
