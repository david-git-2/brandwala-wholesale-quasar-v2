<template>
  <div class="q-gutter-y-md">
    <!-- Top Summary Card Skeleton -->
    <div class="row q-col-gutter-md">
      <div v-for="i in 3" :key="i" class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md bg-surface border-base">
          <div class="row items-center justify-between no-wrap q-mb-sm">
            <q-skeleton type="text" width="120px" class="text-caption" />
            <q-skeleton type="QAvatar" size="32px" />
          </div>
          <q-skeleton type="text" width="140px" class="text-h5 text-weight-bold" />
          <q-skeleton type="text" width="90px" class="text-caption q-mt-xs" />
        </q-card>
      </div>
    </div>

    <!-- Toolbar Skeleton -->
    <q-card flat bordered class="q-pa-sm bg-surface border-base">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-6 row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" width="90px" height="32px" />
          <q-skeleton type="QBtn" width="90px" height="32px" />
          <q-skeleton type="QBtn" width="90px" height="32px" />
        </div>
        <div class="col-12 col-sm-4 row items-center justify-end q-gutter-x-sm">
          <q-skeleton type="QInput" class="col-grow" height="36px" />
        </div>
      </div>
    </q-card>

    <!-- Table Skeleton -->
    <q-card flat bordered class="bg-surface border-base">
      <q-card-section class="q-pa-none">
        <div class="q-pa-md row items-center justify-between border-bottom">
          <q-skeleton type="text" width="150px" class="text-subtitle1 text-weight-bold" />
          <q-skeleton type="QBtn" width="180px" height="36px" />
        </div>
        <div class="q-pa-md">
          <div v-for="row in 5" :key="row" class="row items-center q-py-sm border-bottom-subtle">
            <div class="col-3"><q-skeleton type="text" width="80%" /></div>
            <div class="col-2"><q-skeleton type="text" width="60%" /></div>
            <div class="col-2"><q-skeleton type="text" width="70%" /></div>
            <div class="col-2"><q-skeleton type="text" width="50%" /></div>
            <div class="col-3 text-right"><q-skeleton type="QBtn" width="100px" height="28px" /></div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// Presentational skeleton component for Courier Holdings Page
</script>

<style scoped>
.border-base {
  border: 1px solid var(--q-border-color, #e0e0e0);
}
.border-bottom {
  border-bottom: 1px solid var(--q-border-color, #e0e0e0);
}
.border-bottom-subtle {
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}
</style>
