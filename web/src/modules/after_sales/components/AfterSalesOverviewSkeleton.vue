<template>
  <div class="after-sales-overview-skeleton">
    <q-skeleton type="rect" height="320px" class="rounded-borders hub-summary-skeleton" />

    <div class="bw-inline-actions">
      <q-skeleton v-for="n in 3" :key="`action-${n}`" type="QBtn" width="160px" height="36px" />
    </div>

    <div class="after-sales-hub">
      <section v-for="group in 2" :key="group" class="hub-group">
        <q-skeleton type="text" width="120px" height="14px" class="q-mb-sm" />
        <div class="bw-entity-grid">
          <q-skeleton
            v-for="n in group === 1 ? 1 : 2"
            :key="`${group}-${n}`"
            type="rect"
            height="128px"
            class="rounded-borders"
          />
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts"></script>

<style scoped>
.after-sales-overview-skeleton {
  display: grid;
  gap: 1.25rem;
}

.hub-summary-skeleton {
  border-radius: 14px;
}

.after-sales-hub {
  display: grid;
  gap: 1rem;
}

.hub-group {
  min-width: 0;
}
</style>
