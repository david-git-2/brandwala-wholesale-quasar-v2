<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" size="32px" flat />
          <div>
            <q-skeleton type="text" width="120px" height="14px" class="q-mb-xs" />
            <q-skeleton type="text" width="200px" height="28px" />
            <q-skeleton type="text" width="240px" height="14px" class="q-mt-xs" />
          </div>
        </div>
      </div>
    </section>

    <!-- Workflow Strip Skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-gutter-xs">
        <q-skeleton v-for="n in 5" :key="n" type="QBtn" width="90px" height="28px" />
      </div>
    </q-card>

    <!-- Detail Cards Skeleton -->
    <div class="row q-col-gutter-lg">
      <div class="col-xs-12 col-md-8">
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="160px" height="24px" class="q-mb-md" />
          <q-skeleton type="rect" height="180px" />
        </q-card>
      </div>
      <div class="col-xs-12 col-md-4">
        <div class="column q-gutter-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="140px" height="20px" class="q-mb-sm" />
            <q-skeleton v-for="n in 4" :key="n" type="text" width="100%" class="q-my-xs" />
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// CustomerOrderDetailSkeleton component
</script>
