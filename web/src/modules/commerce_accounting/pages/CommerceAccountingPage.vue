<template>
  <q-page class="q-pa-xs q-sm-pa-md commerce-accounting-dashboard">
    <!-- ── Hero Header ──────────────────────────────────────── -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-md">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-subtitle1 text-weight-bold text-primary flex items-center">
              <q-icon name="account_balance" class="q-mr-sm" size="24px" />
              Commerce Accounting Dashboard
            </div>
            <div class="text-caption text-grey-8 q-mt-xs">
              Manage unified ledger entries, shipments, and inventory summaries for e-commerce.
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- ── Dashboard Navigation Grid ────────────────────────── -->
    <div class="row q-col-gutter-md">
      <!-- Invoice Accounting Card -->
      <div class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          class="dashboard-card cursor-pointer floating-surface shadow-1 hover-scale"
          @click="navigateTo('app-commerce-accounting-invoice-page')"
        >
          <q-card-section class="column justify-between full-height q-pa-lg">
            <div class="column q-gutter-y-sm">
              <div class="card-icon-wrapper bg-indigo-1 text-indigo">
                <q-icon name="receipt_long" size="28px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 q-mt-md">Invoice Accounting</div>
              <div class="text-caption text-grey-7">
                Track payments, cost of goods sold (COGS), total revenues, and profit margins on e-commerce invoices.
              </div>
            </div>
            <div class="row items-center justify-between q-mt-lg text-primary text-weight-medium text-caption">
              <span>View Invoices</span>
              <q-icon name="arrow_forward" size="16px" class="arrow-icon" />
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Shipment Accounting Card -->
      <div class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          class="dashboard-card cursor-pointer floating-surface shadow-1 hover-scale"
          @click="navigateTo('app-commerce-accounting-shipment-page')"
        >
          <q-card-section class="column justify-between full-height q-pa-lg">
            <div class="column q-gutter-y-sm">
              <div class="card-icon-wrapper bg-teal-1 text-teal">
                <q-icon name="local_shipping" size="28px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 q-mt-md">Shipment Accounting</div>
              <div class="text-caption text-grey-7">
                Analyze landed costs, sales revenues, realized gross profit margins, usable inventory, and losses per shipment.
              </div>
            </div>
            <div class="row items-center justify-between q-mt-lg text-primary text-weight-medium text-caption">
              <span>View Shipments</span>
              <q-icon name="arrow_forward" size="16px" class="arrow-icon" />
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Inventory Shipment Summary Card -->
      <div class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          class="dashboard-card cursor-pointer floating-surface shadow-1 hover-scale"
          @click="navigateTo('app-commerce-accounting-inventory-shipment-page')"
        >
          <q-card-section class="column justify-between full-height q-pa-lg">
            <div class="column q-gutter-y-sm">
              <div class="card-icon-wrapper bg-amber-1 text-amber-9">
                <q-icon name="inventory_2" size="28px" />
              </div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 q-mt-md">Stock Shipment Summary</div>
              <div class="text-caption text-grey-7">
                Review batch-wise inventory tracking, usable quantities, cost totals, and losses (damaged/stolen/expired) across shipments.
              </div>
            </div>
            <div class="row items-center justify-between q-mt-lg text-primary text-weight-medium text-caption">
              <span>View Stock Summary</span>
              <q-icon name="arrow_forward" size="16px" class="arrow-icon" />
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'

const router = useRouter()
const route = useRoute()

const navigateTo = (routeName: string) => {
  void router.push({
    name: routeName,
    params: {
      tenantSlug: route.params.tenantSlug
    }
  })
}
</script>

<style scoped>
.commerce-accounting-dashboard {
  background: transparent;
}

/* ── Floating surface ── */
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

/* ── Dashboard Cards ── */
.dashboard-card {
  min-height: 250px;
  display: flex;
  flex-direction: column;
  transition: transform 0.25s cubic-bezier(0.2, 0.8, 0.2, 1), box-shadow 0.25s ease;
}

.dashboard-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(34, 56, 101, 0.12) !important;
}

.dashboard-card:hover .arrow-icon {
  transform: translateX(4px);
}

.arrow-icon {
  transition: transform 0.2s ease;
}

.card-icon-wrapper {
  width: 52px;
  height: 52px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
