<template>
  <div v-if="isLoading" class="q-gutter-y-md">
    <div class="row items-center justify-between">
      <div>
        <q-skeleton type="text" width="120px" height="14px" />
        <q-skeleton type="text" width="220px" height="32px" />
      </div>
      <q-skeleton type="QBtn" width="110px" height="36px" />
    </div>
    <q-card v-for="n in 4" :key="n" flat bordered class="q-pa-md">
      <q-skeleton type="rect" height="88px" class="rounded-borders" />
    </q-card>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  isLoading?: boolean;
}>();
</script>
