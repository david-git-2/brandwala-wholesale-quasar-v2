<template>
  <div class="q-gutter-y-md">
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <q-skeleton type="text" width="120px" height="14px" class="q-mb-xs" />
        <q-skeleton type="text" width="220px" height="32px" />
      </div>
      <div class="col-auto">
        <q-skeleton type="QBtn" width="110px" height="36px" />
      </div>
    </section>

    <div class="row q-col-gutter-md">
      <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="80px" height="14px" class="q-mb-sm" />
          <q-skeleton type="text" width="120px" height="28px" />
        </q-card>
      </div>
    </div>

    <q-card flat bordered class="q-pa-md">
      <q-skeleton type="text" width="160px" height="20px" class="q-mb-md" />
      <div v-for="n in 6" :key="n" class="q-mb-md">
        <q-skeleton type="text" width="100%" height="18px" />
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
</script>
