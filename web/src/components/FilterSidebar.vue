<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    :default-width="defaultWidthPx"
    :min-width="280"
    :max-width="960"
    :storage-key="storageKey"
    :z-index="zIndex"
    :aria-label="title"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div class="filter-sidebar__inner column full-height no-wrap overflow-hidden">
      <div class="filter-sidebar__header row items-center justify-between no-wrap shrink-0">
        <div class="text-subtitle1 text-weight-bold">{{ title }}</div>
        <q-btn flat round dense icon="ph ph-x" :aria-label="`Close ${title}`" @click="close" />
      </div>

      <div class="filter-sidebar__body col min-height-0">
        <slot />
      </div>

      <div v-if="$slots.footer" class="filter-sidebar__footer shrink-0">
        <slot name="footer" />
      </div>
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    title?: string | undefined;
    /** @deprecated inset is aligned with workspace shell via AppResizableOverlayPanel */
    topOffset?: number | undefined;
    /** @deprecated */
    bottomOffset?: number | undefined;
    width?: string | undefined;
    zIndex?: number | undefined;
    /** Persist panel width in localStorage when set */
    storageKey?: string | undefined;
  }>(),
  {
    title: 'Filters',
    width: 'min(320px, 92vw)',
    zIndex: 6000,
  },
);

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
}>();

const close = () => {
  emit('update:modelValue', false);
};

function parseWidthPx(width: string): number {
  const match = width.match(/(\d+)\s*px/);
  return match ? Number.parseInt(match[1], 10) : 320;
}

const defaultWidthPx = computed(() => parseWidthPx(props.width ?? 'min(320px, 92vw)'));
</script>

<style scoped>
.filter-sidebar__inner {
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 0;
  background: var(--bw-theme-surface, #fff);
}

.filter-sidebar__header {
  padding: 14px 16px 10px;
  border-bottom: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.filter-sidebar__body {
  overflow-x: hidden;
  overflow-y: auto;
  padding: 12px 16px 16px;
  display: flex;
  flex-direction: column;
}

.filter-sidebar__footer {
  padding: 12px 16px 16px;
  border-top: 1px solid var(--bw-neutral-border, #e2e8f0);
  background: var(--bw-neutral-surface, #ffffff);
}
</style>
