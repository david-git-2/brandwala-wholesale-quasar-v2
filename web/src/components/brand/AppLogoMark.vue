<template>
  <span class="app-logo-mark" aria-hidden="true" />
</template>

<script setup lang="ts">
defineProps<{
  onDark?: boolean;
  scope?: 'platform' | 'app' | 'shop' | 'investor';
}>();
</script>

<style scoped>
.app-logo-mark {
  display: block;
  width: 1em;
  height: 1em;
  flex-shrink: 0;
  background-color: var(--bw-theme-primary, var(--bw-neutral-ink));
  -webkit-mask: url('/brand/logo-mark-light.png') center / contain no-repeat;
  mask: url('/brand/logo-mark-light.png') center / contain no-repeat;
}
</style>
