<template>
  <q-card flat bordered class="q-pa-md bg-white rounded-borders">
    <div class="q-gutter-y-md">
      <!-- Header Skeleton -->
      <div class="row items-center justify-between">
        <q-skeleton type="rect" width="220px" height="32px" style="border-radius: 8px" />
        <div class="row q-gutter-x-sm">
          <q-skeleton type="rect" width="120px" height="36px" style="border-radius: 8px" />
          <q-skeleton type="rect" width="120px" height="36px" style="border-radius: 8px" />
        </div>
      </div>

      <!-- Status Workflow Strip Skeleton -->
      <q-card flat bordered class="q-pa-sm bg-grey-1">
        <div class="row items-center justify-between">
          <q-skeleton type="rect" width="180px" height="24px" />
          <q-skeleton type="rect" width="300px" height="32px" style="border-radius: 20px" />
        </div>
      </q-card>

      <!-- Main Layout Skeleton -->
      <div class="row q-col-gutter-lg">
        <!-- Left Side Cards -->
        <div class="col-xs-12 col-md-8 q-gutter-y-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="40%" class="text-subtitle1 q-mb-md" />
            <div class="row q-col-gutter-md">
              <div class="col-6"><q-skeleton type="QInput" /></div>
              <div class="col-6"><q-skeleton type="QInput" /></div>
              <div class="col-12"><q-skeleton type="QInput" /></div>
            </div>
          </q-card>

          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="30%" class="text-subtitle1 q-mb-md" />
            <q-skeleton type="rect" height="120px" />
          </q-card>
        </div>

        <!-- Right Side Cards -->
        <div class="col-xs-12 col-md-4 q-gutter-y-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="50%" class="text-subtitle1 q-mb-md" />
            <q-skeleton type="rect" height="180px" />
          </q-card>
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
</script>
