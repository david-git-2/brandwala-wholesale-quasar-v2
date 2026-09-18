<template>
  <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
    <!-- Filters Skeleton -->
    <q-card flat bordered class="q-pa-xs flex-shrink-0">
      <div class="row items-center q-gutter-x-xs">
        <q-skeleton type="QInput" height="36px" style="min-width: 220px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="190px" height="36px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="160px" height="36px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="160px" height="36px" class="col-grow col-sm-auto" />
      </div>
    </q-card>

    <!-- Orders List Card Skeleton -->
    <div class="orders-skeleton-list-card col column no-wrap overflow-hidden">
      <!-- Top meta bar skeleton -->
      <div class="skeleton-meta-bar row items-center justify-between q-px-md q-py-xs flex-shrink-0">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="text" width="70px" height="18px" />
          <q-skeleton type="rect" width="90px" height="18px" class="rounded-borders" />
          <q-skeleton type="rect" width="80px" height="18px" class="rounded-borders" />
        </div>
        <q-skeleton type="text" width="140px" height="14px" />
      </div>

      <!-- List Rows Skeleton -->
      <div class="skeleton-rows-container col overflow-hidden">
        <div
          v-for="n in 7"
          :key="n"
          class="skeleton-row row items-center justify-between no-wrap q-px-md q-py-sm"
        >
          <div class="row items-center no-wrap q-gutter-x-md col">
            <div class="column q-mr-sm" style="min-width: 140px">
              <q-skeleton type="text" width="100px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="80px" height="12px" />
            </div>
            <div class="column col">
              <q-skeleton type="text" width="160px" height="16px" class="q-mb-xs" />
              <div class="row items-center q-gutter-x-xs">
                <q-skeleton type="rect" width="75px" height="20px" class="rounded-borders" />
                <q-skeleton type="rect" width="60px" height="20px" class="rounded-borders" />
                <q-skeleton type="rect" width="85px" height="20px" class="rounded-borders" />
              </div>
            </div>
          </div>

          <div class="row items-center no-wrap flex-shrink-0">
            <q-skeleton type="QBadge" width="90px" height="24px" class="rounded-borders" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Skeleton loader component for redesigned Shop Orders list page
</script>

<style scoped>
.orders-skeleton-list-card {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: 10px;
}

.skeleton-meta-bar {
  background: var(--bw-neutral-surface, #f8fafc);
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
  min-height: 34px;
}

.skeleton-row {
  border-bottom: 1px solid var(--bw-theme-border, #f1f5f9);
}

.skeleton-row:last-child {
  border-bottom: none;
}

body.body--dark .orders-skeleton-list-card {
  background: #1c1917;
  border-color: #2a2622;
}

body.body--dark .skeleton-meta-bar {
  background: #24201d;
  border-color: #2a2622;
}

body.body--dark .skeleton-row {
  border-color: #2a2622;
}
</style>
