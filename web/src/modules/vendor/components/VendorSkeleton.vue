<template>
  <div class="q-gutter-y-md">
    <!-- Toolbar Card Skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
      </div>
    </q-card>

    <!-- Cards Skeleton Grid (6 Items) -->
    <div class="row q-col-gutter-md">
      <div v-for="n in 6" :key="n" class="col-12 col-sm-6 col-md-4">
        <q-card flat bordered class="q-pa-md">
          <div class="row items-center justify-between q-mb-sm">
            <q-skeleton type="text" width="60%" height="20px" />
            <q-skeleton type="QBadge" width="50px" height="20px" />
          </div>
          <q-skeleton type="text" width="40%" class="q-mb-sm" />
          <q-skeleton type="text" width="70%" class="q-mb-sm" />
          <div class="row justify-between items-center q-mt-md">
            <q-skeleton type="text" width="50px" height="16px" />
            <q-skeleton type="QBtn" width="80px" height="28px" />
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>
