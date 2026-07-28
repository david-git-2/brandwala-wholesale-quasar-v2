<template>
  <div class="universal-wallet-skeleton q-gutter-y-md">
    <!-- Header Skeleton -->
    <div class="row items-center justify-between q-mb-sm">
      <div>
        <q-skeleton type="text" width="120px" height="16px" class="q-mb-xs" />
        <q-skeleton type="text" width="220px" height="28px" />
      </div>
      <q-skeleton type="QBtn" width="130px" height="36px" />
    </div>

    <!-- Toolbar Skeleton -->
    <q-card flat bordered class="q-pa-sm surface-card">
      <div class="row items-center q-col-gutter-sm">
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-xs-6 col-sm-3 col-md-2">
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-xs-6 col-sm-3 col-md-2">
          <q-skeleton type="QInput" height="40px" />
        </div>
      </div>
    </q-card>

    <!-- KPI Cards Skeleton -->
    <div class="row q-col-gutter-md">
      <div v-for="i in 3" :key="i" class="col-xs-12 col-sm-4">
        <q-card flat bordered class="stat-card">
          <q-card-section class="q-pa-md">
            <div class="row items-center justify-between q-mb-xs">
              <q-skeleton type="text" width="90px" height="14px" />
              <q-skeleton type="QAvatar" size="32px" />
            </div>
            <q-skeleton type="text" width="140px" height="32px" class="q-my-xs" />
            <q-skeleton type="text" width="110px" height="12px" />
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Table Skeleton -->
    <q-card flat bordered class="surface-card">
      <q-card-section class="q-pa-none">
        <div class="q-pa-md row items-center justify-between border-bottom">
          <q-skeleton type="text" width="150px" height="20px" />
          <q-skeleton type="text" width="80px" height="16px" />
        </div>
        <div v-for="row in 5" :key="row" class="q-pa-md row items-center justify-between border-bottom-subtle">
          <div class="col-3">
            <q-skeleton type="text" width="80%" height="16px" />
            <q-skeleton type="text" width="50%" height="12px" />
          </div>
          <div class="col-2">
            <q-skeleton type="text" width="70%" height="16px" />
          </div>
          <div class="col-3">
            <q-skeleton type="text" width="60%" height="16px" />
          </div>
          <div class="col-2 text-right">
            <q-skeleton type="text" width="80%" height="16px" />
          </div>
          <div class="col-2 text-right">
            <q-skeleton type="text" width="60%" height="16px" />
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// Skeleton component for Universal Wallet to ensure Zero CLS
</script>

<style scoped>
.surface-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.stat-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border);
}

.border-bottom-subtle {
  border-bottom: 1px dashed var(--bw-theme-border);
}
</style>
