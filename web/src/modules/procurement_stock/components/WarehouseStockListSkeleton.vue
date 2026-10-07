<template>
  <div class="warehouse-list-card col column no-wrap">
    <WarehouseStockListHeaderRow :read-only="readOnly" />
    <div class="warehouse-list-scroll col">
      <div
        v-for="n in rowCount"
        :key="n"
        class="warehouse-list-item warehouse-list-item--skeleton"
      >
        <q-skeleton type="text" width="18px" height="14px" class="warehouse-list-sl shrink-0" />
        <q-skeleton type="rect" width="1in" height="1in" class="warehouse-list-thumb shrink-0" />
        <div class="warehouse-list-info">
          <q-skeleton type="text" width="72%" height="16px" />
          <q-skeleton type="text" width="88%" height="13px" />
          <q-skeleton type="text" width="80%" height="12px" />
        </div>
        <div class="warehouse-list-aside shrink-0">
          <div class="warehouse-metric warehouse-metric--cost column items-center">
            <q-skeleton type="text" width="48px" height="12px" />
            <q-skeleton type="text" width="40px" height="10px" class="q-mt-xs" />
          </div>
          <q-skeleton type="text" width="44px" height="16px" class="warehouse-metric warehouse-metric--qty" />
          <div v-if="!readOnly" class="warehouse-list-actions row items-center no-wrap q-gutter-x-xs">
            <q-skeleton v-for="a in 3" :key="a" type="circle" size="28px" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import WarehouseStockListHeaderRow from './WarehouseStockListHeaderRow.vue';

withDefaults(
  defineProps<{
    readOnly?: boolean;
    rowCount?: number;
  }>(),
  {
    readOnly: false,
    rowCount: 8,
  },
);
</script>

<style scoped>
.shrink-0 {
  flex-shrink: 0;
}

.warehouse-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--bw-neutral-surface, #ffffff);
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
  border-radius: var(--bw-radius-sm, 8px);
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.warehouse-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

.warehouse-list-item {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.55rem 1rem;
  border-bottom: 1px solid var(--bw-neutral-border, #f1f5f9);
  min-height: calc(1in + 8px);
}

.warehouse-list-item--skeleton {
  cursor: default;
}

.warehouse-list-sl {
  width: 28px;
  text-align: center;
}

.warehouse-list-thumb {
  border-radius: 6px;
}

.warehouse-list-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
  flex: 1 1 auto;
}

.warehouse-list-aside {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.warehouse-metric--cost {
  min-width: 52px;
}

.warehouse-metric--qty {
  min-width: 1in;
  text-align: center;
}

.warehouse-list-actions {
  min-width: 96px;
  justify-content: center;
}
</style>
