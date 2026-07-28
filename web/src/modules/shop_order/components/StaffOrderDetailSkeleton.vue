<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" width="32px" height="32px" flat />
          <div>
            <q-skeleton type="text" width="100px" height="16px" />
            <q-skeleton type="text" width="200px" height="32px" />
            <q-skeleton type="text" width="160px" height="18px" class="q-mt-xs" />
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <q-skeleton type="QBtn" width="140px" height="36px" />
      </div>
    </section>

    <!-- Workflow Strip Skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-gutter-xs">
        <template v-for="n in 5" :key="n">
          <q-skeleton type="QBtn" width="100px" height="28px" />
          <q-icon v-if="n < 5" name="ph ph-caret-right" color="grey-3" size="18px" />
        </template>
      </div>
    </q-card>

    <!-- Main Columns Skeleton -->
    <div class="row q-col-gutter-lg">
      <!-- Left Column (8 cols) -->
      <div class="col-xs-12 col-md-8">
        <q-card flat bordered class="details-card">
          <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
            <q-skeleton type="text" width="160px" height="24px" />
          </q-card-section>
          <q-list separator>
            <q-item v-for="i in 3" :key="i" class="q-py-md q-px-lg">
              <q-item-section avatar>
                <q-skeleton type="QAvatar" size="50px" rounded />
              </q-item-section>
              <q-item-section>
                <q-skeleton type="text" width="60%" height="20px" />
                <q-skeleton type="text" width="40%" height="16px" class="q-mt-xs" />
              </q-item-section>
              <q-item-section side class="column items-end justify-center">
                <q-skeleton type="text" width="70px" height="16px" />
                <q-skeleton type="text" width="90px" height="20px" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- Right Column Sidebar (4 cols) -->
      <div class="col-xs-12 col-md-4">
        <div class="column q-gutter-md">
          <!-- Summary Card Skeleton -->
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom">
              <q-skeleton type="text" width="130px" height="24px" />
            </q-card-section>
            <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
              <div v-for="i in 4" :key="i" class="row justify-between">
                <q-skeleton type="text" width="40%" height="20px" />
                <q-skeleton type="text" width="30%" height="20px" />
              </div>
              <q-separator class="q-my-sm" />
              <div class="row justify-between items-baseline q-mb-xs">
                <q-skeleton type="text" width="50%" height="24px" />
                <q-skeleton type="text" width="30%" height="28px" />
              </div>
            </q-card-section>
          </q-card>

          <!-- Shipping Card Skeleton -->
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom">
              <q-skeleton type="text" width="140px" height="24px" />
            </q-card-section>
            <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
              <q-skeleton type="text" width="80%" height="20px" />
              <q-skeleton type="text" width="100%" height="20px" />
              <q-skeleton type="text" width="60%" height="20px" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// StaffOrderDetailSkeleton component
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}
</style>
