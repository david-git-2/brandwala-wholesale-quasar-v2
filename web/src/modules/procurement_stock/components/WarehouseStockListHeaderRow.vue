<template>
  <div class="warehouse-list-header row items-center no-wrap">
    <div class="warehouse-list-header__sl">#</div>
    <div class="warehouse-list-header__thumb" />
    <div class="warehouse-list-header__product col">Product</div>
    <div class="warehouse-list-header__cost">Cost</div>
    <div class="warehouse-list-header__qty">Qty</div>
    <div v-if="!readOnly" class="warehouse-list-header__actions">Actions</div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ readOnly?: boolean }>();
</script>

<style scoped>
.warehouse-list-header {
  position: sticky;
  top: 0;
  z-index: 2;
  padding: 0.4rem 1rem;
  gap: 0.65rem;
  background: var(--bw-neutral-surface, #ffffff);
  border-bottom: 1px solid var(--bw-neutral-border, #e2e8f0);
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--bw-neutral-chrome, #64748b);
}

.warehouse-list-header__sl {
  width: 28px;
  text-align: center;
  flex-shrink: 0;
}

.warehouse-list-header__thumb {
  width: 1in;
  flex-shrink: 0;
}

.warehouse-list-header__cost,
.warehouse-list-header__qty {
  width: 56px;
  text-align: center;
  flex-shrink: 0;
}

.warehouse-list-header__actions {
  min-width: 96px;
  text-align: center;
  flex-shrink: 0;
}
</style>
