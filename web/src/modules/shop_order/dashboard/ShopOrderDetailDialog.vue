<template>
  <q-dialog
    v-model="isOpen"
    position="right"
    full-height
    transition-show="slide-left"
    transition-hide="slide-right"
    class="shop-slide-dialog"
    @show="isReady = true"
    @before-hide="isReady = false"
  >
    <div class="pos-drawer">
      <div class="pos-drawer__body">
        <!-- 1. Storefront Receipt Header -->
        <div class="receipt-header">
          <div class="receipt-header__brand">
            <span class="receipt-header__store">STOREFRONT & DROPSHIP AUDIT</span>
            <span class="receipt-header__date">TODAY · LIVE ORDERS</span>
          </div>
          <div class="receipt-header__total">
            <span class="receipt-header__amount">৳384,500</span>
            <span class="receipt-header__count">86 INVOICES</span>
          </div>
        </div>

        <!-- 2. Visual 1: Hourly Sales & Order Velocity Flow (Area Line Chart) -->
        <section class="receipt-section">
          <div class="section-heading">
            <span class="section-heading__title">Hourly Sales Flow</span>
            <span class="section-heading__badge">Peak: 2:00 PM - 5:00 PM</span>
          </div>

          <div class="line-chart-wrap">
            <transition name="fade">
              <Line v-if="isReady" :data="hourlySalesData" :options="lineChartOptions" />
            </transition>
          </div>
        </section>

        <!-- Perforated Receipt Tear Line -->
        <div class="perforated-line" />

        <!-- 3. Visual 2: Courier & Delivery Dispatch Fleet -->
        <section class="receipt-section">
          <div class="section-heading">
            <span class="section-heading__title">Courier Dispatch Fleet</span>
            <span class="section-heading__badge">32 Parcels Out</span>
          </div>

          <div class="courier-grid">
            <div class="courier-item">
              <div class="courier-item__top">
                <div class="courier-item__badge courier-item__badge--steadfast">Steadfast</div>
                <span class="courier-item__count">18 Parcels</span>
              </div>
              <div class="courier-bar">
                <div class="courier-bar__fill courier-bar__fill--steadfast" style="width: 75%" />
              </div>
              <span class="courier-item__meta">14 Dispatched · 4 In Delivery</span>
            </div>

            <div class="courier-item">
              <div class="courier-item__top">
                <div class="courier-item__badge courier-item__badge--pathao">Pathao</div>
                <span class="courier-item__count">10 Parcels</span>
              </div>
              <div class="courier-bar">
                <div class="courier-bar__fill courier-bar__fill--pathao" style="width: 60%" />
              </div>
              <span class="courier-item__meta">6 On Road · 4 Assigned</span>
            </div>

            <div class="courier-item">
              <div class="courier-item__top">
                <div class="courier-item__badge courier-item__badge--pickup">Store Pickup</div>
                <span class="courier-item__count">14 Orders</span>
              </div>
              <div class="courier-bar">
                <div class="courier-bar__fill courier-bar__fill--pickup" style="width: 85%" />
              </div>
              <span class="courier-item__meta">12 Ready · 2 Packing</span>
            </div>
          </div>
        </section>

        <!-- Perforated Receipt Tear Line -->
        <div class="perforated-line" />

        <!-- 4. Visual 3: Payment Settlement & Settlement Ratio -->
        <section class="receipt-section">
          <div class="section-heading">
            <span class="section-heading__title">Payment Settlement</span>
            <span class="section-heading__badge">৳384.5K Total</span>
          </div>

          <!-- Multi-segment Progress Bar -->
          <div class="settlement-meter">
            <div class="settlement-meter__bar settlement-meter__bar--cod" style="width: 58%" title="Courier COD" />
            <div class="settlement-meter__bar settlement-meter__bar--digital" style="width: 28%" title="Bank / MFS" />
            <div class="settlement-meter__bar settlement-meter__bar--cash" style="width: 14%" title="POS Cash" />
          </div>

          <div class="settlement-breakdown">
            <div class="settlement-row">
              <span class="tag-pill tag-pill--cod">Courier COD</span>
              <span class="settlement-row__val">৳223,000 (58%)</span>
            </div>
            <div class="settlement-row">
              <span class="tag-pill tag-pill--digital">Online / bKash</span>
              <span class="settlement-row__val">৳107,600 (28%)</span>
            </div>
            <div class="settlement-row">
              <span class="tag-pill tag-pill--cash">POS Cash Counter</span>
              <span class="settlement-row__val">৳53,900 (14%)</span>
            </div>
          </div>
        </section>
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { Line } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';

import { ensureShopOrderChartsRegistered } from './shopOrderChartSetup';

ensureShopOrderChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const isReady = ref(false);

/* --- HOURLY SALES AREA/LINE CHART --- */
const hourlySalesData = computed<ChartData<'line'>>(() => ({
  labels: ['9 AM', '11 AM', '1 PM', '3 PM', '5 PM', '7 PM', '9 PM'],
  datasets: [
    {
      label: 'Sales (৳ BDT)',
      data: [28000, 64000, 112000, 96000, 52000, 24000, 8500],
      borderColor: '#0284c7',
      backgroundColor: 'rgba(2, 132, 199, 0.12)',
      borderWidth: 2.5,
      tension: 0.4,
      fill: true,
      pointBackgroundColor: '#0284c7',
      pointBorderColor: '#ffffff',
      pointBorderWidth: 2,
      pointRadius: 4,
      pointHoverRadius: 6,
    },
  ],
}));

const lineChartOptions: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#0f172a',
      padding: 8,
      cornerRadius: 6,
      callbacks: {
        label: (item) => ` ৳${Number(item.raw).toLocaleString()} BDT`,
      },
    },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: '#64748b', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
    y: {
      grid: { color: 'rgba(226, 232, 240, 0.6)' },
      ticks: {
        color: '#94a3b8',
        font: { size: 10 },
        callback: (val) => `৳${Number(val) / 1000}k`,
      },
      border: { display: false },
    },
  },
};
</script>

<style scoped>
/* --- POS RECEIPT & COCKPIT DRAWER --- */
.pos-drawer {
  width: 410px;
  max-width: 95vw;
  height: 100%;
  background: #ffffff;
  border-left: 1px solid var(--bw-theme-border, #e2e8f0);
  box-shadow: -8px 0 32px rgba(15, 23, 42, 0.08);
  display: flex;
  flex-direction: column;
  justify-content: center;
  color: #0f172a;
  will-change: transform;
  overflow: hidden;
}

.pos-drawer__body {
  padding: 1.25rem 1.4rem;
  display: flex;
  flex-direction: column;
  gap: 0.95rem;
  overflow: hidden;
}

/* --- RECEIPT HEADER --- */
.receipt-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  padding-bottom: 0.65rem;
  border-bottom: 2px solid #0f172a;
}

.receipt-header__brand {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.receipt-header__store {
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: #0f172a;
}

.receipt-header__date {
  font-size: 0.64rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: #64748b;
}

.receipt-header__total {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}

.receipt-header__amount {
  font-size: 1.25rem;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -0.02em;
  line-height: 1.1;
}

.receipt-header__count {
  font-size: 0.65rem;
  font-weight: 700;
  color: #0284c7;
}

/* --- SECTIONS --- */
.receipt-section {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.section-heading {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}

.section-heading__title {
  font-size: 0.74rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #334155;
}

.section-heading__badge {
  font-size: 0.66rem;
  font-weight: 600;
  color: #64748b;
}

/* --- HOURLY LINE CHART --- */
.line-chart-wrap {
  height: 95px;
  position: relative;
}

/* --- PERFORATED RECEIPT TEAR LINE --- */
.perforated-line {
  width: 100%;
  height: 1px;
  background: repeating-linear-gradient(
    90deg,
    #cbd5e1 0px,
    #cbd5e1 4px,
    transparent 4px,
    transparent 8px
  );
  opacity: 0.9;
}

/* --- COURIER DISPATCH METERS --- */
.courier-grid {
  display: grid;
  gap: 0.5rem;
}

.courier-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.45rem 0.65rem;
  border-radius: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
}

.courier-item__top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.courier-item__badge {
  font-size: 0.68rem;
  font-weight: 800;
  padding: 0.08rem 0.4rem;
  border-radius: 4px;
}

.courier-item__badge--steadfast {
  background: rgba(16, 185, 129, 0.12);
  color: #059669;
}

.courier-item__badge--pathao {
  background: rgba(239, 68, 68, 0.12);
  color: #dc2626;
}

.courier-item__badge--pickup {
  background: rgba(2, 132, 199, 0.12);
  color: #0284c7;
}

.courier-item__count {
  font-size: 0.76rem;
  font-weight: 800;
  color: #0f172a;
}

.courier-bar {
  width: 100%;
  height: 4px;
  border-radius: 2px;
  background: #e2e8f0;
  overflow: hidden;
}

.courier-bar__fill {
  height: 100%;
  border-radius: 2px;
}

.courier-bar__fill--steadfast {
  background: #10b981;
}

.courier-bar__fill--pathao {
  background: #ef4444;
}

.courier-bar__fill--pickup {
  background: #0284c7;
}

.courier-item__meta {
  font-size: 0.65rem;
  color: #64748b;
  font-weight: 500;
}

/* --- PAYMENT SETTLEMENT METER --- */
.settlement-meter {
  display: flex;
  height: 8px;
  border-radius: 4px;
  overflow: hidden;
  gap: 2px;
  background: #e2e8f0;
}

.settlement-meter__bar--cod {
  background: #0284c7;
}

.settlement-meter__bar--digital {
  background: #10b981;
}

.settlement-meter__bar--cash {
  background: #f59e0b;
}

.settlement-breakdown {
  display: grid;
  gap: 0.35rem;
  margin-top: 0.35rem;
}

.settlement-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.72rem;
}

.tag-pill {
  font-size: 0.66rem;
  font-weight: 700;
  padding: 0.05rem 0.35rem;
  border-radius: 3px;
}

.tag-pill--cod {
  background: rgba(2, 132, 199, 0.1);
  color: #0284c7;
}

.tag-pill--digital {
  background: rgba(16, 185, 129, 0.1);
  color: #059669;
}

.tag-pill--cash {
  background: rgba(245, 158, 11, 0.1);
  color: #d97706;
}

.settlement-row__val {
  font-weight: 700;
  color: #0f172a;
}

/* --- FADE ANIMATION --- */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
