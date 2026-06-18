<template>
  <div class="page-initial-loader column items-center justify-center">
    <q-spinner-dots color="primary" size="40px" />
    <p v-if="message" class="page-initial-loader__message">{{ message }}</p>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  message?: string
}>()
</script>

<style scoped>
.page-initial-loader {
  min-height: 240px;
  gap: 0.75rem;
}

.page-initial-loader__message {
  margin: 0;
  color: var(--bw-theme-muted, #736a61);
  font-size: 0.9rem;
}
</style>
