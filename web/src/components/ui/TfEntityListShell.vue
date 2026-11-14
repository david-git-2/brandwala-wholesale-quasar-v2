<template>
  <div class="tf-entity-list-card" :class="rootClass">
    <div v-if="$slots.header" class="tf-entity-list-header">
      <slot name="header" />
    </div>
    <div class="tf-entity-list-scroll" :class="scrollClass">
      <slot />
    </div>
    <div v-if="$slots.footer" class="tf-entity-list-footer">
      <slot name="footer" />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  rootClass?: string | string[] | Record<string, boolean>;
  scrollClass?: string | string[] | Record<string, boolean>;
}>();
</script>

<style scoped lang="scss">
@import 'src/css/tf-entity-list.scss';
</style>