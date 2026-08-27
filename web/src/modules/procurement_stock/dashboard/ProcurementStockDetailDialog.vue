<template>
  <q-dialog
    v-model="isOpen"
    position="right"
    full-height
    transition-show="slide-left"
    transition-hide="slide-right"
    class="stock-slide-dialog"
    @show="isReady = true"
    @before-hide="isReady = false"
  >
    <div class="stock-drawer">
      <!-- Direct on-paper ledger content (Deep Pigment Ink Aesthetics) -->
      <div class="stock-drawer__body">
        <!-- 1. Availability Breakdown Section -->
        <section class="paper-section">
          <div class="paper-section__head">
            <span class="paper-section__title">Availability Condition</span>
            <span class="paper-section__meta">16,550 Pcs</span>
          </div>

          <!-- Side-by-Side Donut & Written Ledger Rows -->
          <div class="availability-row">
            <div class="donut-wrap">
              <transition name="chart-fade">
                <Doughnut v-if="isReady" :data="availabilityChartData" :options="chartOptions" />
              </transition>
              <div class="donut-center">
                <span class="donut-center__val">86.3%</span>
                <span class="donut-center__sub">Sellable</span>
              </div>
            </div>

            <!-- Inscribed Legend Lines with Deep Ink Dots -->
            <div class="legend-list">
              <div class="legend-row">
                <div class="legend-row__left">
                  <span class="ink-dot ink-dot--sellable" />
                  <span class="legend-row__label">Sellable Stock</span>
                </div>
                <div class="legend-row__right">
                  <span class="legend-row__val">14,280</span>
                  <span class="legend-row__pct">86%</span>
                </div>
              </div>

              <div class="legend-row">
                <div class="legend-row__left">
                  <span class="ink-dot ink-dot--held" />
                  <span class="legend-row__label">Held / Reserved</span>
                </div>
                <div class="legend-row__right">
                  <span class="legend-row__val">1,650</span>
                  <span class="legend-row__pct">10%</span>
                </div>
              </div>

              <div class="legend-row">
                <div class="legend-row__left">
                  <span class="ink-dot ink-dot--damaged" />
                  <span class="legend-row__label">Damaged</span>
                </div>
                <div class="legend-row__right">
                  <span class="legend-row__val">620</span>
                  <span class="legend-row__pct">4%</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Subtle drafted pencil rule -->
        <div class="paper-rule" />

        <!-- 2. Quality Grade Distribution Section -->
        <section class="paper-section">
          <div class="paper-section__head">
            <span class="paper-section__title">Quality Grade Distribution</span>
            <span class="paper-section__meta">Physical Stock</span>
          </div>

          <!-- Deep Pigment Bar Chart on Paper -->
          <div class="bar-chart-wrap">
            <transition name="chart-fade">
              <Bar v-if="isReady" :data="gradeChartData" :options="barChartOptions" />
            </transition>
          </div>

          <!-- Drafted Grade Notes with Deep Ink Tags -->
          <div class="grade-list">
            <div class="grade-row">
              <div class="grade-row__left">
                <span class="grade-ink grade-ink--a">Grade A</span>
                <span class="grade-row__desc">Brand New · Mint Condition</span>
              </div>
              <span class="grade-row__val">10,400 Pcs</span>
            </div>

            <div class="grade-row">
              <div class="grade-row__left">
                <span class="grade-ink grade-ink--b">Grade B</span>
                <span class="grade-row__desc">Minor Box Blemish</span>
              </div>
              <span class="grade-row__val">4,200 Pcs</span>
            </div>

            <div class="grade-row">
              <div class="grade-row__left">
                <span class="grade-ink grade-ink--c">Grade C</span>
                <span class="grade-row__desc">Open Box / Clearance</span>
              </div>
              <span class="grade-row__val">1,950 Pcs</span>
            </div>
          </div>
        </section>
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { Doughnut, Bar } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';

import { ensureProcurementChartsRegistered } from './procurementChartSetup';

ensureProcurementChartsRegistered();

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

/* --- CHART 1: AVAILABILITY (Doughnut - Deep Pigment Ink) --- */
const availabilityChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Sellable', 'Held / Reserved', 'Damaged / Unsellable'],
  datasets: [
    {
      data: [14280, 1650, 620],
      backgroundColor: ['#059669', '#d97706', '#dc2626'],
      borderWidth: 0,
      hoverOffset: 3,
    },
  ],
}));

const chartOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1c1917',
      padding: 8,
      cornerRadius: 6,
    },
  },
};

/* --- CHART 2: GRADE (Bar - Deep Pigment Ink) --- */
const gradeChartData = computed<ChartData<'bar'>>(() => ({
  labels: ['Grade A', 'Grade B', 'Grade C'],
  datasets: [
    {
      label: 'Quantity (Pcs)',
      data: [10400, 4200, 1950],
      backgroundColor: ['#1d4ed8', '#0284c7', '#475569'],
      borderRadius: 4,
      borderSkipped: false,
    },
  ],
}));

const barChartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1c1917',
      padding: 6,
      cornerRadius: 6,
    },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: '#57534e', font: { size: 10, weight: 700 } },
      border: { display: false },
    },
    y: {
      grid: { color: 'rgba(214, 204, 188, 0.45)' },
      ticks: { color: '#78716c', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
  },
};
</script>

<style scoped>
/* --- ARTISANAL WATERCOLOR / JOURNAL PAPER --- */
.stock-drawer {
  width: 400px;
  max-width: 95vw;
  height: 100%;
  background: #fbf9f4;
  background-image: linear-gradient(180deg, #fdfbf7 0%, #f7f3eb 100%);
  border-left: 1px solid #e5dec9;
  box-shadow: -8px 0 32px rgba(68, 55, 33, 0.08);
  display: flex;
  flex-direction: column;
  justify-content: center;
  color: #1c1917;
  will-change: transform;
  overflow: hidden;
  position: relative;
}

/* Tactile paper texture */
.stock-drawer::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: radial-gradient(#ebe1d0 0.75px, transparent 0.75px);
  background-size: 16px 16px;
  opacity: 0.45;
  pointer-events: none;
}

.stock-drawer__body {
  position: relative;
  z-index: 1;
  padding: 1.35rem 1.45rem;
  display: flex;
  flex-direction: column;
  gap: 1.15rem;
  overflow: hidden;
}

/* --- WRITTEN SECTIONS (ZERO CARD BOXES) --- */
.paper-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.paper-section__head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid #e8e0ce;
}

.paper-section__title {
  font-size: 0.76rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #292524;
}

.paper-section__meta {
  font-size: 0.72rem;
  font-weight: 700;
  color: #78716c;
}

/* --- SUBTLE PENCIL DIVIDER --- */
.paper-rule {
  width: 100%;
  height: 1px;
  background: repeating-linear-gradient(
    90deg,
    #e2dac7 0px,
    #e2dac7 4px,
    transparent 4px,
    transparent 8px
  );
  opacity: 0.85;
}

/* --- AVAILABILITY ROW --- */
.availability-row {
  display: flex;
  align-items: center;
  gap: 1.15rem;
}

.donut-wrap {
  position: relative;
  width: 95px;
  height: 95px;
  flex-shrink: 0;
}

.donut-center {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
}

.donut-center__val {
  font-size: 0.98rem;
  font-weight: 800;
  color: #1c1917;
  line-height: 1;
}

.donut-center__sub {
  font-size: 0.6rem;
  font-weight: 700;
  color: #57534e;
  margin-top: 0.1rem;
}

/* --- INSCRIBED LEDGER ROWS WITH DEEP INK --- */
.legend-list {
  display: grid;
  gap: 0.4rem;
  flex: 1 1 auto;
}

.legend-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.75rem;
  padding: 0.15rem 0;
  border-bottom: 1px dashed #ede5d5;
}

.legend-row__left {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.ink-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}

.ink-dot--sellable {
  background: #059669;
}

.ink-dot--held {
  background: #d97706;
}

.ink-dot--damaged {
  background: #dc2626;
}

.legend-row__label {
  font-weight: 600;
  color: #44403c;
}

.legend-row__right {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
}

.legend-row__val {
  font-weight: 800;
  color: #1c1917;
}

.legend-row__pct {
  font-size: 0.68rem;
  font-weight: 700;
  color: #78716c;
}

/* --- BAR CHART --- */
.bar-chart-wrap {
  height: 95px;
  position: relative;
}

/* --- INK GRADE ROWS --- */
.grade-list {
  display: grid;
  gap: 0.35rem;
}

.grade-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.2rem 0;
  border-bottom: 1px dashed #ede5d5;
  font-size: 0.74rem;
}

.grade-row__left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.grade-ink {
  font-weight: 800;
  font-size: 0.68rem;
  padding: 0.05rem 0.35rem;
  border-radius: 3px;
}

.grade-ink--a {
  background: rgba(29, 78, 216, 0.12);
  color: #1d4ed8;
}

.grade-ink--b {
  background: rgba(2, 132, 199, 0.12);
  color: #0284c7;
}

.grade-ink--c {
  background: rgba(71, 85, 105, 0.14);
  color: #334155;
}

.grade-row__desc {
  font-size: 0.68rem;
  color: #57534e;
  font-weight: 500;
}

.grade-row__val {
  font-weight: 800;
  color: #1c1917;
}

/* --- FADE ANIMATION --- */
.chart-fade-enter-active,
.chart-fade-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.chart-fade-enter-from,
.chart-fade-leave-to {
  opacity: 0;
  transform: scale(0.96);
}
</style>
