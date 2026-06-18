<template>
  <div
    class="page-initial-loader"
    :class="{
      'page-initial-loader--compact': compact,
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
    message?: string
    compact?: boolean
    overlay?: boolean
  }>(),
  {
    message: '',
    compact: false,
    overlay: false,
  },
)
</script>

<style scoped>
.page-initial-loader {
  min-height: 50vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.page-initial-loader--compact {
  min-height: 160px;
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
