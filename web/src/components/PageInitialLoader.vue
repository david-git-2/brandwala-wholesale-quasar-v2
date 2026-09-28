<template>
  <div
    class="page-initial-loader"
    :class="{
      'page-initial-loader--compact': compact,
      'page-initial-loader--embedded': embedded,
      'page-initial-loader--overlay': overlay,
    }"
  >
    <q-spinner-tail color="primary" :size="compact ? '48px' : '72px'" />
    <div v-if="message" class="page-initial-loader__message text-caption text-grey-7 q-mt-md">
      {{ message }}
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    message?: string;
    compact?: boolean;
    embedded?: boolean;
    overlay?: boolean;
  }>(),
  {
    message: '',
    compact: false,
    embedded: false,
    overlay: false,
  },
);
</script>

<style scoped>
.page-initial-loader {
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  min-height: 50vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.page-initial-loader--compact {
  min-height: 10rem;
}

.page-initial-loader--embedded {
  min-height: 9rem;
  padding: 1.25rem 0.5rem;
}

.page-initial-loader--overlay {
  position: fixed;
  inset: 0;
  z-index: 6000;
  min-height: 100%;
  background: rgba(255, 255, 255, 0.86);
  backdrop-filter: blur(2px);
}

.page-initial-loader__message {
  text-align: center;
  max-width: 260px;
}
</style>
