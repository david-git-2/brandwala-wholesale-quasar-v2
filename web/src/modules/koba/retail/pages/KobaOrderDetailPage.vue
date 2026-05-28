<template>
  <q-page class="bw-page q-pa-md">
    <!-- Header -->
    <div class="detail-header q-mb-md">
      <div class="row items-center justify-between no-wrap w-full">
        <div class="row items-center q-gutter-sm">
          <q-btn flat round icon="arrow_back" color="grey-8" :to="{ name: ordersRouteName }" />
          <div>
            <div class="text-h5 text-weight-bold text-grey-9">Order details #{{ orderId }}</div>
            <div class="text-caption text-grey-7">Placed on {{ formatDate(order?.created_at) }}</div>
          </div>
        </div>

        <div class="row items-center q-gutter-sm">
          <!-- Status badge (non-admin) -->
          <q-chip
            v-if="order && !isAdmin"
            :color="statusColor"
            text-color="white"
            square
            class="text-uppercase text-weight-bold q-px-md q-py-sm"
          >
            {{ order.status }}
          </q-chip>

          <!-- Status dropdown (admin) -->
          <q-select
            v-if="order && isAdmin"
            v-model="pendingStatusChange"
            :options="statusOptions"
            outlined
            dense
            emit-value
            map-options
            label="Status"
            style="min-width: 160px"
            class="soft-input"
            :loading="savingStatus"
            :disable="savingStatus || isDeliveredLocked"
            @update:model-value="onStatusSelectChange"
          >
            <template #prepend>
              <q-icon :name="statusIcon(pendingStatusChange)" size="18px" />
            </template>
          </q-select>

          <!-- Refresh button (admin) -->
          <q-btn
            v-if="isAdmin"
            flat
            round
            icon="refresh"
            color="primary"
            :loading="loading"
            @click="onRefresh"
          />

          <!-- Soft delete button (admin) -->
          <q-btn
            v-if="isAdmin && canSoftDelete"
            flat
            round
            icon="delete_outline"
            color="negative"
            :loading="savingDelete"
            @click="deleteDialogOpen = true"
          />
        </div>
      </div>
    </div>

    <!-- Loading Indicator -->
    <div v-if="loading && !order" class="flex flex-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-negative text-center q-pa-md empty-state-card">
      <q-icon name="error_outline" size="48px" color="negative" class="q-mb-sm" />
      <div class="text-h6">{{ error }}</div>
      <q-btn label="Back to Orders" color="primary" flat :to="{ name: ordersRouteName }" class="q-mt-sm" />
    </div>


    <div v-if="order" class="row q-col-gutter-md">
      <!-- Left Column: Items -->
      <div class="col-12 col-md-8">
        <!-- Shipping Card -->
        <q-card flat class="detail-card q-mb-md">
          <q-card-section class="q-pb-none">
            <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center justify-between">
              <div class="row items-center">
                <q-icon name="local_shipping" color="primary" size="20px" class="q-mr-xs" />
                Shipping Information
              </div>
              <!-- Copy all button (admin) -->
              <q-btn
                v-if="isAdmin"
                flat
                dense
                no-caps
                icon="copy_all"
                label="Copy all"
                color="primary"
                size="sm"
                @click="copyAllShipping"
              />
            </div>
          </q-card-section>

          <q-card-section>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Recipient Name</div>
                  <div class="info-val text-weight-medium row items-center q-gutter-xs">
                    <span>{{ order.shipping_name || '—' }}</span>
                    <q-btn
                      v-if="isAdmin && order.shipping_name"
                      flat dense round icon="content_copy" size="xs" color="grey-6"
                      @click="copyToClipboard(order.shipping_name!, 'Name copied')"
                    />
                  </div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Phone Number</div>
                  <div class="info-val text-weight-medium row items-center q-gutter-xs">
                    <span>{{ order.shipping_phone || '—' }}</span>
                    <q-btn
                      v-if="isAdmin && order.shipping_phone"
                      flat dense round icon="content_copy" size="xs" color="grey-6"
                      @click="copyToClipboard(order.shipping_phone!, 'Phone copied')"
                    />
                  </div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">District / Thana</div>
                  <div class="info-val text-weight-medium row items-center q-gutter-xs">
                    <span>{{ order.shipping_district || '—' }} / {{ order.shipping_thana || '—' }}</span>
                    <q-btn
                      v-if="isAdmin && order.shipping_district"
                      flat dense round icon="content_copy" size="xs" color="grey-6"
                      @click="copyToClipboard((order.shipping_district ?? '') + ' / ' + (order.shipping_thana ?? ''), 'District copied')"
                    />
                  </div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Full Address</div>
                  <div class="info-val text-weight-medium row items-center q-gutter-xs">
                    <span>{{ order.shipping_address || '—' }}</span>
                    <q-btn
                      v-if="isAdmin && order.shipping_address"
                      flat dense round icon="content_copy" size="xs" color="grey-6"
                      @click="copyToClipboard(order.shipping_address!, 'Address copied')"
                    />
                  </div>
                </div>
              </div>
              <div class="col-12" v-if="order.free_delivery">
                <q-chip outline color="primary" icon="check_circle" dense>Free Delivery Requested</q-chip>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <!-- Items Card -->
      <q-card flat class="detail-card">
  <q-card-section class="q-pb-none">
    <div class="row items-center justify-between">
      <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center">
        <q-icon name="shopping_bag" color="primary" size="20px" class="q-mr-xs" />
        Order Items ({{ filteredItems.length }}<span v-if="isAdmin"> / {{ items.length }}</span> variant{{ items.length === 1 ? '' : 's' }})
      </div>

      <q-select
        v-if="isAdmin"
        v-model="confirmFilter"
        :options="itemFilterOptions"
        outlined
        dense
        emit-value
        map-options
        label="Filter"
        style="min-width: 150px"
        class="soft-input"
      />
    </div>
  </q-card-section>

  <q-card-section v-if="qtyError" class="q-pt-sm q-pb-none">
    <q-banner rounded dense class="bg-negative-soft text-negative text-caption">
      {{ qtyError }}
    </q-banner>
  </q-card-section>

  <q-card-section class="q-pa-none q-mt-sm">
    <q-table
      :rows="filteredItems"
      :columns="tableColumns"
      row-key="id"
      flat
      bordered
      wrap-cells
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      class="item-table"
    >
      <template #body="props">
        <q-tr :props="props">
          <q-td key="item" :props="props">
            <div class="row no-wrap items-center q-gutter-sm">
              <q-avatar square size="48px" class="bg-grey-2 item-avatar-frame">
                <img v-if="props.row.image_url" :src="toDirectGoogleImageUrl(props.row.image_url)" referrerpolicy="no-referrer" />
                <q-icon v-else name="image_not_supported" color="grey-5" />
              </q-avatar>
              <div>
                <div class="text-caption text-primary text-uppercase text-weight-bold" v-if="props.row.brand">{{ props.row.brand }}</div>
                <div class="text-subtitle2 text-weight-bold text-grey-9 item-name">{{ props.row.name }}</div>
                <div class="text-caption text-grey-6">Case Size: {{ props.row.case_size }}</div>
                <div class="text-caption text-positive text-weight-medium" v-if="props.row.commission">
                  Commission: ৳{{ Number(Math.max(0, (props.row.commission || 0) - gatewayChargeFlat)).toFixed(2) }} / unit
                </div>
              </div>
            </div>
          </q-td>

          <q-td key="price" :props="props" class="text-right">
            <div class="text-subtitle2 text-primary text-weight-bold">
              ৳{{ Number((props.row.custom_price_gbp || props.row.unit_price_gbp || 0) * props.row.quantity).toFixed(2) }}
            </div>
            <div class="text-caption text-grey-6">৳{{ Number(props.row.custom_price_gbp || props.row.unit_price_gbp || 0).toFixed(2) }} each</div>
            <div v-if="props.row.custom_price_gbp && props.row.custom_price_gbp > (props.row.unit_price_gbp || 0)" class="text-caption text-grey-5 text-strike">
              Orig: ৳{{ Number(props.row.unit_price_gbp || 0).toFixed(2) }}
            </div>
          </q-td>

          <q-td key="qty_ordered" :props="props" class="text-center">
            <span class="text-weight-bold">{{ props.row.quantity }}</span>
          </q-td>

          <q-td key="qty_confirmed" :props="props" class="text-center" :class="{ 'cursor-pointer editable-cell': isAdmin && showConfirmedInput }">
            <span class="text-weight-bold text-blue-9">{{ props.row.confirmed_quantity ?? '—' }}</span>
            <q-icon v-if="isAdmin && showConfirmedInput" name="edit" size="xs" color="blue-4" class="q-ml-xs show-on-hover" />
            
            <q-popup-edit
              v-if="isAdmin && showConfirmedInput"
              v-model.number="qtyDraft[props.row.id].confirmed"
              auto-save
              v-slot="scope"
              @save="(val) => onSaveConfirmedQty(props.row, val)"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                min="0"
                dense
                autofocus
                counter
                @keyup.enter="scope.set"
                label="Confirmed Quantity"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="qty_delivered" :props="props" class="text-center" :class="{ 'cursor-pointer editable-cell': isAdmin && showDeliveredInput }">
            <span class="text-weight-bold text-teal-9">{{ props.row.delivered_quantity }}</span>
            <q-icon v-if="isAdmin && showDeliveredInput" name="edit" size="xs" color="teal-4" class="q-ml-xs show-on-hover" />

            <q-popup-edit
              v-if="isAdmin && showDeliveredInput"
              v-model.number="qtyDraft[props.row.id].delivered"
              auto-save
              v-slot="scope"
              @save="(val) => onSaveDeliveredQty(props.row, val)"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                min="0"
                :max="props.row.confirmed_quantity ?? props.row.quantity"
                dense
                autofocus
                counter
                @keyup.enter="scope.set"
                label="Delivered Quantity"
              />
            </q-popup-edit>
          </q-td>
        </q-tr>
      </template>
    </q-table>
  </q-card-section>
</q-card>
      </div>

      <!-- Right Column: Order Summary & Commission -->
      <div class="col-12 col-md-4">
        <!-- Summary Card -->
        <q-card flat class="detail-card q-pa-md q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md row items-center">
            <q-icon name="summarize" color="primary" size="20px" class="q-mr-xs" />
            Order Summary
          </div>

          <!-- Qty totals bar (admin) -->
          <div v-if="isAdmin" class="row q-gutter-sm q-mb-md">
            <div class="qty-stat-chip ordered">
              <div class="qty-stat-label">Ordered</div>
              <div class="qty-stat-value">{{ totalOrdered }}</div>
            </div>
            <div class="qty-stat-chip confirmed">
              <div class="qty-stat-label">Confirmed</div>
              <div class="qty-stat-value">{{ totalConfirmed }}</div>
            </div>
            <div class="qty-stat-chip delivered">
              <div class="qty-stat-label">Delivered</div>
              <div class="qty-stat-value">{{ totalDelivered }}</div>
            </div>
          </div>

          <div class="row justify-between q-py-xs text-grey-8">
            <div>Total units</div>
            <div class="text-weight-bold">{{ totalQuantity }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Subtotal</div>
            <div class="text-weight-bold">৳{{ Number(order.subtotal_gbp || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Delivery</div>
            <div class="text-weight-bold">৳{{ deliveryCharge.toFixed(2) }}</div>
          </div>

          <q-separator class="q-my-sm" />

          <div class="row justify-between q-py-xs text-h6 text-weight-bold text-grey-9">
            <div>Total Value</div>
            <div class="text-primary">৳{{ finalTotal.toFixed(2) }}</div>
          </div>

          <div v-if="order.note" class="q-mt-md">
            <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Order Note</div>
            <div class="note-box q-pa-sm q-mt-xs text-body2 text-grey-8">
              {{ order.note }}
            </div>
          </div>
        </q-card>

        <!-- Commission Card -->
        <q-card flat class="detail-card q-pa-md q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md row items-center">
            <q-icon name="payments" color="primary" size="20px" class="q-mr-xs" />
            Earnings & Fees
          </div>

          <div class="row justify-between q-py-xs text-grey-8">
            <div>Products Commission</div>
            <div class="text-weight-bold text-positive">৳{{ productsCommissionDisplay.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.extra_profit_user || order.extra_profit_company">
            <div>Extra Profit Share (You 90% | Company 10%)</div>
            <div class="text-weight-bold text-positive">+৳{{ Number(order.extra_profit_user || 0).toFixed(2) }} | +৳{{ Number(order.extra_profit_company || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.delivery_adjustment">
            <div>Delivery Adjustment</div>
            <div class="text-weight-bold text-positive">+৳{{ Number(order.delivery_adjustment || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.cod_charge">
            <div>COD Charge (1.00%)</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.cod_charge || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.packing_charge">
            <div>Packing Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.packing_charge || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.invoice_charge">
            <div>Invoice Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.invoice_charge || 0).toFixed(2) }}</div>
          </div>

          <q-separator class="q-my-sm" />

          <div class="row justify-between q-py-sm text-subtitle1 text-weight-bold text-positive q-mt-sm bg-positive-soft q-px-sm rounded-borders">
            <div class="row items-center">
              <q-icon name="monetization_on" class="q-mr-xs" size="20px" />
              Net Earnings
            </div>
            <div>৳{{ netOrderCommission.toFixed(2) }}</div>
          </div>
        </q-card>

        <!-- Admin CTAs -->
        <div v-if="isAdmin" class="column q-gutter-sm">
          <!-- Mark as Confirmed -->
          <q-btn
            v-if="order.status === 'pending'"
            unelevated
            color="blue-7"
            icon="check_circle"
            label="Mark as Confirmed"
            no-caps
            class="full-width cta-btn"
            :loading="savingStatus"
            @click="confirmStatusDialogTarget = 'confirmed'; statusDialogOpen = true"
          />

          <!-- Mark as Processing -->
          <q-btn
            v-if="order.status === 'confirmed'"
            unelevated
            color="indigo-7"
            icon="autorenew"
            label="Mark as Processing"
            no-caps
            class="full-width cta-btn"
            :loading="savingStatus"
            @click="confirmStatusDialogTarget = 'processing'; statusDialogOpen = true"
          />

          <!-- Mark as Shipped -->
          <q-btn
            v-if="order.status === 'processing'"
            unelevated
            color="deep-purple-7"
            icon="local_shipping"
            label="Mark as Shipped"
            no-caps
            class="full-width cta-btn"
            :loading="savingStatus"
            @click="confirmStatusDialogTarget = 'shipped'; statusDialogOpen = true"
          />

          <!-- Mark as Delivered -->
          <q-btn
            v-if="order.status === 'shipped' || order.status === 'confirmed' || order.status === 'processing'"
            unelevated
            color="positive"
            icon="task_alt"
            label="Mark as Delivered"
            no-caps
            class="full-width cta-btn"
            :loading="savingStatus"
            @click="confirmStatusDialogTarget = 'delivered'; statusDialogOpen = true"
          />

          <!-- Cancel -->
          <q-btn
            v-if="order.status !== 'delivered' && order.status !== 'cancelled'"
            flat
            color="negative"
            icon="cancel"
            label="Cancel Order"
            no-caps
            class="full-width"
            :loading="savingStatus"
            @click="confirmStatusDialogTarget = 'cancelled'; statusDialogOpen = true"
          />
        </div>
      </div>
    </div>

    <!-- ── Confirm Status Change Dialog ── -->
    <q-dialog v-model="statusDialogOpen" persistent>
      <q-card style="min-width: 320px" class="rounded-dialog">
        <q-card-section class="row items-center q-pb-none">
          <q-icon name="swap_horiz" color="primary" size="28px" class="q-mr-sm" />
          <span class="text-h6">Change Order Status</span>
        </q-card-section>
        <q-card-section class="text-grey-8">
          Are you sure you want to set this order to
          <span class="text-weight-bold text-grey-9">{{ confirmStatusDialogTarget }}</span>?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            unelevated
            no-caps
            color="primary"
            label="Confirm"
            :loading="savingStatus"
            @click="onConfirmStatusChange"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- ── Confirm Delete Dialog ── -->
    <q-dialog v-model="deleteDialogOpen" persistent>
      <q-card style="min-width: 320px" class="rounded-dialog">
        <q-card-section class="row items-center q-pb-none">
          <q-icon name="delete_outline" color="negative" size="28px" class="q-mr-sm" />
          <span class="text-h6">Delete Order</span>
        </q-card-section>
        <q-card-section class="text-grey-8">
          This will permanently delete this order. This action cannot be undone.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            unelevated
            no-caps
            color="negative"
            label="Delete"
            :loading="savingDelete"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- ── Copy snackbar ── -->
    <q-snackbar v-model="copySnackbar" :message="copyMessage" timeout="1500" color="dark" position="bottom" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { date, useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaOrderStore } from 'src/modules/koba/retail/stores/kobaOrderStore'
import { useKobaSettingsStore } from 'src/modules/koba/retail/stores/kobaSettingsStore'
import type { KobaOrderItem, KobaOrderStatus } from 'src/modules/koba/retail/repositories/kobaOrderRepository'

const $q = useQuasar()
const route = useRoute()
const authStore = useAuthStore()
const orderStore = useKobaOrderStore()
const settingsStore = useKobaSettingsStore()

const orderId = computed(() => Number(route.params.id))
const loading = ref(true)
const error = ref<string | null>(null)

const order = computed(() => orderStore.orderDetail?.order || null)
const items = computed(() => orderStore.orderDetail?.items || [])

// ─── Role / permission ──────────────────────────────────────────────────────

const ADMIN_ROLES: string[] = ['superadmin', 'admin', 'staff']
const isAdmin = computed(() =>
  ADMIN_ROLES.includes(authStore.matchedRole ?? '')
)

const ordersRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-orders-page' : 'app-koba-retail-orders-page'
})

const gatewayChargeFlat = computed(() => settingsStore.settings?.gateway_charge_flat ?? 20)

// ─── Status helpers ─────────────────────────────────────────────────────────

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Processing', value: 'processing' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
]

function statusIcon(s: string | null) {
  switch (s) {
    case 'pending': return 'hourglass_empty'
    case 'confirmed': return 'check_circle_outline'
    case 'processing': return 'autorenew'
    case 'shipped': return 'local_shipping'
    case 'delivered': return 'task_alt'
    case 'cancelled': return 'cancel'
    default: return 'fiber_manual_record'
  }
}

const statusColor = computed(() => {
  if (!order.value) return 'grey'
  switch (order.value.status) {
    case 'pending': return 'amber-8'
    case 'confirmed': return 'blue-7'
    case 'processing': return 'indigo-7'
    case 'shipped': return 'deep-purple-7'
    case 'delivered': return 'positive'
    case 'cancelled': return 'negative'
    default: return 'grey'
  }
})

const isDeliveredLocked = computed(() => order.value?.status === 'delivered')
const canSoftDelete = computed(() =>
  isAdmin.value &&
  order.value?.status === 'delivered'
)
const canEditQuantities = computed(() =>
  isAdmin.value && !isDeliveredLocked.value && order.value?.status !== 'cancelled'
)
const showConfirmedInput = computed(() =>
  canEditQuantities.value && order.value?.status === 'pending'
)
const showDeliveredInput = computed(() =>
  canEditQuantities.value && order.value?.status !== 'pending'
)

// ─── Status change (dropdown + dialog) ─────────────────────────────────────

const pendingStatusChange = ref<KobaOrderStatus | null>(null)
const savingStatus = ref(false)
const statusDialogOpen = ref(false)
const confirmStatusDialogTarget = ref<KobaOrderStatus | null>(null)

// Keep dropdown in sync with the order status
watch(
  () => order.value?.status,
  (s) => { pendingStatusChange.value = s ?? null },
  { immediate: true }
)

function onStatusSelectChange(newStatus: KobaOrderStatus) {
  if (!newStatus || newStatus === order.value?.status || savingStatus.value) {
    // revert
    pendingStatusChange.value = order.value?.status ?? null
    return
  }
  confirmStatusDialogTarget.value = newStatus
  statusDialogOpen.value = true
  // revert dropdown optimistically until confirmed
  pendingStatusChange.value = order.value?.status ?? null
}

async function onConfirmStatusChange() {
  if (!confirmStatusDialogTarget.value || !orderId.value) return
  savingStatus.value = true
  try {
    const result = await orderStore.updateOrderStatus(orderId.value, confirmStatusDialogTarget.value)
    if (result?.success) {
      $q.notify({ message: 'Order status updated', color: 'positive', icon: 'check_circle', timeout: 1500 })
    } else {
      $q.notify({ message: result?.error ?? 'Failed to update status', color: 'negative', icon: 'error', timeout: 2500 })
      pendingStatusChange.value = order.value?.status ?? null
    }
  } finally {
    savingStatus.value = false
    statusDialogOpen.value = false
    confirmStatusDialogTarget.value = null
  }
}

// ─── Soft delete ────────────────────────────────────────────────────────────

const savingDelete = ref(false)
const deleteDialogOpen = ref(false)

async function onConfirmDelete() {
  if (!orderId.value) return
  savingDelete.value = true
  try {
    const result = await orderStore.softDeleteOrder(orderId.value)
    if (result?.success) {
      $q.notify({ message: 'Order cancelled', color: 'dark', icon: 'cancel', timeout: 1500 })
    } else {
      $q.notify({ message: result?.error ?? 'Failed to delete order', color: 'negative', icon: 'error', timeout: 2500 })
    }
  } finally {
    savingDelete.value = false
    deleteDialogOpen.value = false
  }
}

// ─── Quantity draft state ───────────────────────────────────────────────────

interface QtyDraft {
  confirmed: number | null
  delivered: number | null
}

const qtyDraft = reactive<Record<number, QtyDraft>>({})
const qtyError = ref<string | null>(null)
const savingConfirmedId = ref<number | null>(null)
const savingDeliveredId = ref<number | null>(null)

function initDraftForItems(itemList: KobaOrderItem[]) {
  for (const item of itemList) {
    if (qtyDraft[item.id] === undefined) {
      qtyDraft[item.id] = {
        confirmed: item.confirmed_quantity ?? null,
        delivered: item.delivered_quantity ?? 0,
      }
    }
  }
}

watch(items, (newItems) => { initDraftForItems(newItems) }, { immediate: true })

function confirmedChanged(item: KobaOrderItem): boolean {
  const draft = qtyDraft[item.id]
  if (!draft) return false
  const current = item.confirmed_quantity ?? null
  const next = draft.confirmed !== null ? Number(draft.confirmed) : null
  return next !== null && next !== current && next >= 0
}

function deliveredChanged(item: KobaOrderItem): boolean {
  const draft = qtyDraft[item.id]
  if (!draft) return false
  const current = item.delivered_quantity ?? 0
  const next = draft.delivered !== null ? Number(draft.delivered) : null
  return next !== null && next !== current && next >= 0
}





// ─── Item filter ─────────────────────────────────────────────────────────────

const confirmFilter = ref<'all' | 'confirmed' | 'not_confirmed'>('all')

const itemFilterOptions = [
  { label: 'All Items', value: 'all' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Not Confirmed', value: 'not_confirmed' },
]

const filteredItems = computed(() => {
  if (!isAdmin.value || confirmFilter.value === 'all') return items.value
  if (confirmFilter.value === 'confirmed') {
    return items.value.filter((i) => (i.confirmed_quantity ?? 0) > 0)
  }
  return items.value.filter((i) => (i.confirmed_quantity ?? 0) === 0)
})

// ─── Totals ──────────────────────────────────────────────────────────────────

const totalQuantity = computed(() =>
  items.value.reduce((sum, item) => sum + (item.quantity || 0), 0)
)

const totalOrdered = computed(() =>
  items.value.reduce((sum, item) => sum + (item.quantity || 0), 0)
)

const totalConfirmed = computed(() =>
  items.value.reduce((sum, item) => sum + (item.confirmed_quantity || 0), 0)
)

const totalDelivered = computed(() =>
  items.value.reduce((sum, item) => sum + (item.delivered_quantity || 0), 0)
)

const productsCommissionDisplay = computed(() => {
  if (!order.value) return 0
  return Number(order.value.total_commission || 0) + Number(order.value.extra_profit_user || 0)
})

const deliveryCharge = computed(() => {
  if (!order.value || order.value.free_delivery || !order.value.shipping_district) return 0
  const rates = settingsStore.settings?.delivery_rates || { default: 110, Dhaka: 100 }
  return (rates as Record<string, number>)[order.value.shipping_district] ?? (rates as Record<string, number>)['default'] ?? 110
})

const finalTotal = computed(() => {
  if (!order.value) return 0
  return Number(order.value.subtotal_gbp || 0) + deliveryCharge.value
})

const netOrderCommission = computed(() => {
  if (!order.value) return 0
  if (order.value.net_order_commission) {
    return Number(order.value.net_order_commission)
  }
  return (
    productsCommissionDisplay.value +
    Number(order.value.delivery_adjustment || 0) -
    Number(order.value.cod_charge || 0) -
    Number(order.value.packing_charge || 0) -
    Number(order.value.invoice_charge || 0)
  )
})

// ─── Copy to clipboard ────────────────────────────────────────────────────────

const copySnackbar = ref(false)
const copyMessage = ref('')

async function copyToClipboard(text: string, successMsg = 'Copied') {
  const value = String(text || '').trim()
  if (!value) return
  try {
    if (navigator?.clipboard?.writeText) {
      await navigator.clipboard.writeText(value)
    } else {
      const area = document.createElement('textarea')
      area.value = value
      area.setAttribute('readonly', '')
      area.style.cssText = 'position:fixed;opacity:0;pointer-events:none'
      document.body.appendChild(area)
      area.focus()
      area.select()
      document.execCommand('copy')
      document.body.removeChild(area)
    }
    copyMessage.value = successMsg
    copySnackbar.value = true
  } catch {
    $q.notify({ message: 'Could not copy to clipboard', color: 'warning', timeout: 1500 })
  }
}

function copyAllShipping() {
  if (!order.value) return
  const lines = [
    order.value.shipping_name,
    order.value.shipping_phone,
    [order.value.shipping_district, order.value.shipping_thana].filter(Boolean).join(' / '),
    order.value.shipping_address,
  ]
    .filter(Boolean)
    .join('\n')
  void copyToClipboard(lines, 'Shipping info copied')
}

// ─── Refresh ─────────────────────────────────────────────────────────────────

async function onRefresh() {
  loading.value = true
  error.value = null
  try {
    await Promise.all([
      orderStore.fetchOrderDetails(orderId.value),
      settingsStore.fetchSettings(),
    ])
    initDraftForItems(items.value)
  } catch (err: unknown) {
    error.value = (err as Error)?.message || 'Failed to refresh order.'
  } finally {
    loading.value = false
  }
}

// ─── Mount ────────────────────────────────────────────────────────────────────

onMounted(async () => {
  loading.value = true
  try {
    await Promise.all([
      orderStore.fetchOrderDetails(orderId.value),
      settingsStore.fetchSettings(),
    ])
    initDraftForItems(items.value)
  } catch (err: unknown) {
    error.value = (err as Error)?.message || 'Failed to load order details'
  } finally {
    loading.value = false
  }
})

// ─── Utils ────────────────────────────────────────────────────────────────────

function formatDate(isoString: string | undefined) {
  if (!isoString) return '—'
  return date.formatDate(new Date(isoString), 'YYYY-MM-DD HH:mm')
}

function toDirectGoogleImageUrl(url: string | null) {
  if (!url) return ''
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  const fileId = m1?.[1] || m2?.[1]
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

// ─── Table Configuration ───────────────────────────────────────────────────
const tableColumns = [
  { name: 'item', label: 'Item Details', align: 'left' as const, field: 'name' },
  { name: 'price', label: 'Price Total', align: 'right' as const, field: 'unit_price_gbp' },
  { name: 'qty_ordered', label: 'Ordered', align: 'center' as const, field: 'quantity' },
  { name: 'qty_confirmed', label: 'Confirmed', align: 'center' as const, field: 'confirmed_quantity' },
  { name: 'qty_delivered', label: 'Delivered', align: 'center' as const, field: 'delivered_quantity' },
]

// ─── Quantity Updates via Popup Edit ─────────────────────────────────────────

async function onSaveConfirmedQty(item: KobaOrderItem, newValue: any) {
  const qty = Math.max(0, Math.round(Number(newValue)))
  savingConfirmedId.value = item.id
  qtyError.value = null
  try {
    const result = await orderStore.updateItemConfirmedQty(item.id, qty)
    if (result?.success) {
      $q.notify({ message: 'Confirmed qty saved', color: 'positive', icon: 'check', timeout: 1200 })
    } else {
      qtyError.value = result?.error ?? 'Failed to save confirmed quantity.'
      // Revert if API failed
      if (qtyDraft[item.id]) qtyDraft[item.id].confirmed = item.confirmed_quantity ?? null
    }
  } finally {
    savingConfirmedId.value = null
  }
}

async function onSaveDeliveredQty(item: KobaOrderItem, newValue: any) {
  const maxQty = item.confirmed_quantity ?? item.quantity
  const qty = Math.max(0, Math.min(maxQty, Math.round(Number(newValue))))
  savingDeliveredId.value = item.id
  qtyError.value = null
  try {
    const result = await orderStore.updateItemDeliveredQty(item.id, qty)
    if (result?.success) {
      $q.notify({ message: 'Delivered qty saved', color: 'teal', icon: 'check', timeout: 1200 })
    } else {
      qtyError.value = result?.error ?? 'Failed to save delivered quantity.'
      // Revert if API failed
      if (qtyDraft[item.id]) qtyDraft[item.id].delivered = item.delivered_quantity ?? 0
    }
  } finally {
    savingDeliveredId.value = null
  }
}
</script>

<style scoped>
.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.detail-card {
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(255, 255, 255, 0.95);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.01);
}

.empty-state-card {
  border-radius: 16px;
  border: 1px dashed rgba(0, 0, 0, 0.12);
  background: #fdfdfd;
  padding: 40px;
}

.info-item {
  display: flex;
  flex-direction: column;
}

.info-lbl {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.info-val {
  font-size: 14px;
  color: #1e293b;
}

.item-avatar-frame {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.item-list-container :deep(.q-item) {
  border-bottom: 1px solid rgba(0, 0, 0, 0.04);
}

.item-list-container :deep(.q-item):last-child {
  border-bottom: none;
}

.note-box {
  background: #f8fafc;
  border: 1px solid rgba(0, 0, 0, 0.03);
  border-radius: 8px;
  white-space: pre-line;
}

.bg-positive-soft {
  background-color: rgba(46, 204, 113, 0.1);
}

.rounded-borders {
  border-radius: 8px;
}

.w-full {
  width: 100%;
}

/* ── Qty stat chips ── */
.qty-stat-chip {
  flex: 1;
  border-radius: 8px;
  padding: 6px 10px;
  text-align: center;
}

.qty-stat-chip.ordered {
  background: rgba(96, 125, 139, 0.12);
}

.qty-stat-chip.confirmed {
  background: rgba(30, 136, 229, 0.12);
}

.qty-stat-chip.delivered {
  background: rgba(46, 125, 50, 0.12);
}

.qty-stat-label {
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #64748b;
}

.qty-stat-value {
  font-size: 18px;
  font-weight: 900;
  line-height: 1.1;
  color: #1e293b;
}

/* ── Admin qty inputs ── */
.admin-qty-block {
  background: rgba(0, 0, 0, 0.025);
  border-radius: 8px;
  padding: 6px 10px;
}

.qty-label-confirmed {
  color: #1565c0;
}

.qty-label-delivered {
  color: #00695c;
}

/* ── CTA buttons ── */
.cta-btn {
  height: 44px;
  font-size: 14px;
  font-weight: 600;
  border-radius: 10px;
}

/* ── Dialogs ── */
.rounded-dialog {
  border-radius: 16px !important;
}

/* ── Negative soft banner ── */
.bg-negative-soft {
  background: rgba(229, 57, 53, 0.08);
}

.item-table :deep(th) {
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.5px;
}

.editable-cell {
  position: relative;
  transition: background 0.2s ease;
}

.editable-cell:hover {
  background: rgba(30, 136, 229, 0.05) !important;
}

.show-on-hover {
  opacity: 0;
  transition: opacity 0.2s ease;
}

.editable-cell:hover .show-on-hover {
  opacity: 1;
}
</style>
