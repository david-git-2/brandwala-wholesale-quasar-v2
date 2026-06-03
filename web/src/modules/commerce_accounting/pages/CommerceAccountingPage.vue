<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold text-primary">Commerce Accounting</div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="row justify-center q-my-xl">
      <q-spinner-dots size="40px" color="primary" />
    </div>

    <!-- Empty State -->
    <div v-else-if="!records.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block">
      <q-icon name="account_balance" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Commerce Accounting Records Found</div>
      <div class="text-caption text-grey-5">Accounting entries will generate automatically upon invoice creation.</div>
    </div>

    <!-- Accounting Table -->
    <div v-else>
      <q-table
        flat
        bordered
        :rows="records"
        :columns="columns"
        row-key="id"
        class="floating-surface shadow-1 rounded-borders"
      >
        <template #body-cell-is_customer_group_paid="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="props.value ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold"
            >
              {{ props.value ? 'SETTLED' : 'PENDING' }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-order_payment_status="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="props.value ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold"
            >
              {{ props.value ? 'PAID' : 'UNPAID' }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-created_at="props">
          <q-td :props="props">
            {{ formatDate(props.value) }}
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" class="q-gutter-xs text-center">
            <q-btn
              flat
              round
              color="primary"
              :icon="props.row.is_customer_group_paid ? 'undo' : 'check_circle'"
              size="sm"
              @click="togglePaymentStatus(props.row)"
            >
              <q-tooltip>{{ props.row.is_customer_group_paid ? 'Mark Pending' : 'Mark Settled' }}</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar'
import { onMounted, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceAccountingService } from '../services/commerceAccountingService'
import type { CommerceAccounting } from '../types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

const authStore = useAuthStore()

// State
const loading = ref(true)
const records = ref<CommerceAccounting[]>([])

const columns: QTableColumn[] = [
  { name: 'id', label: 'Entry ID', field: 'id', align: 'left', sortable: true },
  { name: 'order_item_id', label: 'Order Item ID', field: 'order_item_id', align: 'left', sortable: true },
  { name: 'inventory_item_id', label: 'Inventory Item ID', field: 'inventory_item_id', align: 'left', sortable: true },
  { name: 'cost_bdt', label: 'Cost (BDT)', field: 'cost_bdt', align: 'left' },
  { name: 'sell_price_bdt', label: 'Sell Price (BDT)', field: 'sell_price_bdt', align: 'left' },
  { name: 'recipient_sell_price_bdt', label: 'Recipient Sell (BDT)', field: 'recipient_sell_price_bdt', align: 'left' },
  { name: 'customer_group_id', label: 'Customer Group ID', field: 'customer_group_id', align: 'left' },
  { name: 'order_payment_status', label: 'Order Payment', field: 'order_payment_status', align: 'left', sortable: true },
  { name: 'is_customer_group_paid', label: 'Settlement Status', field: 'is_customer_group_paid', align: 'left', sortable: true },
  { name: 'created_at', label: 'Created Date', field: 'created_at', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
]

const loadRecords = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceAccountingService.listCommerceAccounting(authStore.tenantId)
    if (res.success && res.data) {
      records.value = res.data
    } else {
      records.value = []
    }
  } finally {
    loading.value = false
  }
}

const togglePaymentStatus = async (record: CommerceAccounting) => {
  const newStatus = !record.is_customer_group_paid
  try {
    const res = await commerceAccountingService.updateAccountingPaymentStatus(record.id, newStatus)
    if (res.success) {
      showSuccessNotification(`Accounting entry status updated successfully.`)
      await loadRecords()
    } else {
      showWarningDialog(res.error || 'Failed to update accounting entry.')
    }
  } catch (err) {
    console.error(err)
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

onMounted(() => {
  void loadRecords()
})
</script>

<style scoped>
.empty-state-block {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid #e7e2d8;
  border-radius: 14px;
  backdrop-filter: blur(6px);
}
</style>
