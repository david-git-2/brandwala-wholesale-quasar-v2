<template>
  <q-card flat bordered class="q-pa-md skeleton-card">
    <div class="q-gutter-y-md">
      <!-- Header Skeleton -->
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <q-skeleton type="text" width="120px" height="14px" />
          <q-skeleton type="text" width="260px" height="32px" class="q-mt-xs" />
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-skeleton type="QBtn" width="140px" height="36px" />
        </div>
      </div>

      <!-- Toolbar Skeleton -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-skeleton type="QInput" height="40px" />
          </div>
          <div class="col-12 col-sm-6 row q-gutter-xs justify-end">
            <q-skeleton v-for="n in 3" :key="n" type="QBadge" width="90px" height="30px" />
          </div>
        </div>
      </q-card>

      <!-- Table Skeleton -->
      <q-card flat bordered class="q-pa-md">
        <div class="q-gutter-y-sm">
          <div v-for="n in 5" :key="n" class="row items-center justify-between q-py-sm border-bottom">
            <q-skeleton type="text" width="140px" height="20px" />
            <q-skeleton type="text" width="100px" height="20px" />
            <q-skeleton type="text" width="120px" height="20px" />
            <q-skeleton type="text" width="80px" height="20px" />
            <q-skeleton type="QBtn" width="60px" height="28px" />
          </div>
        </div>
      </q-card>
    </div>
  </q-card>
</template>

<style scoped lang="scss">
.skeleton-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
}
.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border);
}
</style>
