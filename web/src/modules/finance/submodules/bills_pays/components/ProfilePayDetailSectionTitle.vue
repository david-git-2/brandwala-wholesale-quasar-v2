<template>
  <div class="q-mb-xs">
    <div class="text-caption text-weight-bold text-grey-9 text-uppercase" style="letter-spacing: 0.06em">
      {{ title }}
    </div>
    <div v-if="caption" class="text-caption text-grey-7 q-mt-xs">{{ caption }}</div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string;
  caption?: string;
}>();
</script>