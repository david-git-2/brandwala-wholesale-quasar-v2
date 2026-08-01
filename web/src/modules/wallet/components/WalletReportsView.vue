<template>
  <div class="wallet-reports-view q-gutter-y-md">
    <!-- Platform Financial Summary Header -->
    <q-card flat bordered class="q-pa-md shadow-1 rounded-borders">
      <div class="row items-center justify-between">
        <div>
          <div class="text-subtitle1 text-weight-bold text-ink">Platform Financial Inflow &amp; Holdings Summary</div>
          <div class="text-caption text-grey-7">
            Real-time aggregated view across Platform Bank Cash, Courier Remittance Holdings, Merchant Margins, and Supplier Payables
          </div>
        </div>
        <q-btn
          flat
          dense
          color="primary"
          icon="ph ph-arrows-clockwise"
          label="Refresh Aggregates"
          no-caps
          class="q-px-sm text-weight-bold text-caption rounded-borders"
          :loading="isDashboardLoading"
          @click="() => void refetchDashboard()"
        />
      </div>
    </q-card>

    <!-- Summary Metrics Cards Grid -->
    <div class="row q-col-gutter-md">
      <!-- 1. Platform Cash -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-blue-1 border-blue">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-primary">Platform Bank Cash</span>
            <q-icon name="ph ph-bank" color="primary" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-primary q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.tenant_cash_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Actual bank cash received from courier remittances</div>
        </q-card>
      </div>

      <!-- 2. Courier COD Holding -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-amber-1 border-amber">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-warning">Courier COD Holdings</span>
            <q-icon name="ph ph-truck" color="warning" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-warning q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.courier_cod_holding_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Cash collected by delivery partners awaiting remittance</div>
        </q-card>
      </div>

      <!-- 3. Merchant Pending Margins -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-purple-1 border-purple">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-deep-purple">Merchant Pending Margins</span>
            <q-icon name="ph ph-clock" color="deep-purple" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-deep-purple q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.merchant_pending_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Accrued profits on delivered orders awaiting cash settlement</div>
        </q-card>
      </div>

      <!-- 4. Merchant Available Balance -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-green-1 border-green">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-positive">Merchant Available Balance</span>
            <q-icon name="ph ph-currency-circle-dollar" color="positive" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-positive q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.merchant_available_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Withdrawable merchant profit available for payout</div>
        </q-card>
      </div>

      <!-- 5. Vendor Payables -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-teal-1 border-teal">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-teal">Vendor Payables</span>
            <q-icon name="ph ph-storefront" color="teal" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-teal q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.vendor_payables_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Total payables owed to stock procurement suppliers</div>
        </q-card>
      </div>

      <!-- 6. Customer Prepayments -->
      <div class="col-xs-12 col-sm-6 col-md-4">
        <q-card flat bordered class="metric-card q-pa-md bg-indigo-1 border-indigo">
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-indigo">Customer Prepayments</span>
            <q-icon name="ph ph-receipt" color="indigo" size="20px" />
          </div>
          <div class="text-h5 text-weight-bolder font-mono text-indigo q-my-xs">
            ৳{{ formatCurrency(dashboardSummary?.customer_deposits_total || 0) }}
          </div>
          <div class="text-caption text-grey-7">Store credits and customer deposit balances</div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useWalletAccounts } from '../composables/useWalletAccounts';

const { dashboardSummary, isDashboardLoading, refetchDashboard } = useWalletAccounts();

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(val || 0);
}
</script>

<style scoped>
.metric-card {
  border-radius: 12px;
  transition: all 0.2s ease;
}

.metric-card:hover {
  transform: translateY(-2px);
}

.border-blue { border-color: rgba(59, 130, 246, 0.2); }
.border-amber { border-color: rgba(245, 158, 11, 0.2); }
.border-purple { border-color: rgba(147, 51, 234, 0.2); }
.border-green { border-color: rgba(34, 197, 94, 0.2); }
.border-teal { border-color: rgba(20, 184, 166, 0.2); }
.border-indigo { border-color: rgba(99, 102, 241, 0.2); }

.text-ink {
  color: var(--bw-theme-ink, #1e293b);
}
</style>
