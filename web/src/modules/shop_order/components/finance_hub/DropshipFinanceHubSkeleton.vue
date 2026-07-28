<template>
  <div class="q-gutter-y-md">
    <!-- KPI Skeleton -->
    <div class="row q-col-gutter-md">
      <div v-for="i in 3" :key="i" class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="60%" />
          <q-skeleton type="rect" height="32px" class="q-mt-sm" />
          <q-skeleton type="text" width="40%" class="q-mt-xs" />
        </q-card>
      </div>
    </div>

    <!-- Queue Skeleton -->
    <q-card flat bordered class="q-pa-md">
      <div class="row justify-between items-center q-mb-md">
        <q-skeleton type="rect" width="200px" height="24px" />
        <q-skeleton type="rect" width="300px" height="32px" />
      </div>
      <q-skeleton type="rect" height="200px" />
    </q-card>

    <!-- Active Step Skeleton -->
    <q-card flat bordered class="q-pa-md">
      <q-skeleton type="rect" width="250px" height="24px" class="q-mb-md" />
      <div class="row q-col-gutter-sm">
        <div class="col-6"><q-skeleton type="rect" height="40px" /></div>
        <div class="col-6"><q-skeleton type="rect" height="40px" /></div>
      </div>
      <q-skeleton type="rect" height="40px" class="q-mt-md" />
    </q-card>
  </div>
</template>

<script setup lang="ts">
</script>
