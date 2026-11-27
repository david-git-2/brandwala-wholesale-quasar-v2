<template>
  <div class="pp-supplier-order-line-table column no-wrap col min-h-0">
    <div class="pp-supplier-order-line-table__card column col min-h-0 no-wrap overflow-hidden">
      <div
        ref="tableScrollRef"
        class="pp-supplier-order-line-table__scroll col min-h-0 hide-native-scrollbar"
      >
        <div class="pp-supplier-order-line-table__sheet">
          <div class="pp-supplier-order-line-table__head pp-supplier-order-line-table__grid" aria-hidden="true">
            <span class="pp-supplier-order-line-table__head-product">Product</span>
            <span class="pp-supplier-order-line-table__head-text">Description</span>
            <span class="text-center">Store</span>
            <span class="text-center">Quantity</span>
            <span class="text-center">Price</span>
            <span class="text-center">Tracking</span>
            <span class="text-center">Fulfillment</span>
          </div>
          <template v-for="block in lineBlocks" :key="block.key">
            <div class="pp-supplier-order-line-table__group-head">
              {{ block.label }}
            </div>
            <div
              v-for="line in block.lines"
              :key="line.id"
              class="pp-supplier-order-line-table__body-row"
            >
              <PpSupplierOrderLineRow
                :line="line"
                :updating="updatingLineId === line.id"
                @patch="emit('patch', $event)"
              />
            </div>
          </template>
        </div>
      </div>
      <ExcelTableScrollFooter
        ref="scrollFooterRef"
        class="pp-supplier-order-line-table__scroll-footer shrink-0"
        :get-scroll-container="getTableScrollContainer"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import '../../styles/ppOrderLinePlacementTones.css';
import ExcelTableScrollFooter from 'src/components/ui/ExcelTableScrollFooter.vue';
import type { PpOrderLine, PpSupplierOrderLineUpdatePayload } from '../../types/ppPurchaseRequest';
import { groupPpOrderLinesByStoreHost } from '../../utils/ppOrderLineGrouping';
import PpSupplierOrderLineRow from './PpSupplierOrderLineRow.vue';

const props = defineProps<{
  lines: PpOrderLine[];
  updatingLineId?: number | null;
}>();

const emit = defineEmits<{
  patch: [payload: PpSupplierOrderLineUpdatePayload];
}>();

const lineBlocks = computed(() => groupPpOrderLinesByStoreHost(props.lines));

const tableScrollRef = ref<HTMLElement | null>(null);
const scrollFooterRef = ref<InstanceType<typeof ExcelTableScrollFooter> | null>(null);

const getTableScrollContainer = () => tableScrollRef.value;

watch(
  () => props.lines.map((line) => line.id).join(','),
  () => {
    requestAnimationFrame(() => scrollFooterRef.value?.updateThumb?.());
  },
);
</script>

<style scoped>
.pp-supplier-order-line-table {
  min-width: 0;
}

.pp-supplier-order-line-table__scroll {
  width: 100%;
  max-width: 100%;
  overflow-x: auto;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}

.pp-supplier-order-line-table__card {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 10px;
  background: var(--tf-neutral-surface);
}

.pp-supplier-order-line-table__sheet {
  min-width: 1180px;
}

.pp-supplier-order-line-table__scroll-footer {
  border-top: 1px solid var(--tf-neutral-border);
  border-radius: 0 0 10px 10px;
}

.pp-supplier-order-line-table__grid {
  display: grid;
  grid-template-columns:
    minmax(15rem, 2.4fr)
    minmax(11rem, 1.2fr)
    minmax(6.5rem, 0.65fr)
    minmax(11rem, 1.25fr)
    4.25rem
    minmax(8.5rem, 0.85fr)
    minmax(6.75rem, 0.75fr);
  align-items: stretch;
}

.pp-supplier-order-line-table__head {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--tf-disabled-bg);
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
}

.pp-supplier-order-line-table__head > span {
  padding: 0.5rem;
  border-right: 1px solid var(--tf-neutral-border);
  text-align: center;
}

.pp-supplier-order-line-table__head-product,
.pp-supplier-order-line-table__head-text {
  text-align: left;
}

.pp-supplier-order-line-table__head > span:last-child {
  border-right: none;
}

.pp-supplier-order-line-table__group-head {
  position: sticky;
  top: 2.25rem;
  z-index: 1;
  padding: 0.4rem 0.75rem;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
  background: color-mix(in srgb, var(--tf-disabled-bg) 92%, var(--tf-neutral-surface));
  border-bottom: 1px solid var(--tf-neutral-border);
}

.pp-supplier-order-line-table__body-row {
  border-bottom: 1px solid var(--tf-neutral-border);
  background: transparent;
}

.pp-supplier-order-line-table__body-row:last-child {
  border-bottom: none;
}

.pp-supplier-order-line-table__body-row:hover :deep(.pp-supplier-order-line-row) {
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--tf-neutral-ink) 18%, transparent);
}
</style>