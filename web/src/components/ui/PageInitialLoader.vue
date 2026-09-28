<template>
  <div
    class="page-initial-loader column items-center justify-center"
    :class="{ 'page-initial-loader--compact': compact }"
  >
    <q-spinner-dots color="primary" :size="compact ? '36px' : '40px'" />
    <p v-if="message" class="page-initial-loader__message">{{ message }}</p>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    message?: string;
    compact?: boolean;
  }>(),
  {
    compact: false,
  },
);
</script>

<style scoped>
.page-initial-loader {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  min-height: min(50vh, 20rem);
  gap: 0.75rem;
  padding: 1rem;
}

.page-initial-loader--compact {
  min-height: 10rem;
}

.page-initial-loader__message {
  margin: 0;
  color: var(--bw-theme-muted, #736a61);
  font-size: 0.9rem;
  text-align: center;
  line-height: 1.45;
  max-width: 18rem;
}
</style>
