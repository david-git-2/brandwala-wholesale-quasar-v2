<script setup lang="ts">
withDefaults(defineProps<{ rows?: number; cols?: number; height?: string }>(), {
  rows: 8,
  cols: 4,
  height: '14px',
})
</script>

<template>
  <div class="tf-skeleton-rows" aria-busy="true">
    <div v-for="r in rows" :key="r" class="row no-wrap items-center q-gutter-md q-py-sm">
      <q-skeleton v-for="c in cols" :key="c" type="rect" :height="height" class="col" />
    </div>
  </div>
</template>
