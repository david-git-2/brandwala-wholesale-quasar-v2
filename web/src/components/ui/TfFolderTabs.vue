<template>
  <div class="tf-folder-tabs" :class="{ 'tf-folder-tabs--inset': inset }">
    <div class="tf-folder-tabs__header">
      <div class="tf-folder-tabs__header-row">
        <div
          class="tf-folder-tabs__bar"
          role="tablist"
          :aria-label="ariaLabel"
          @keydown="onTabListKeydown"
        >
        <button
          v-for="tab in tabs"
          :id="tabId(tab.name)"
          :key="String(tab.name)"
          type="button"
          role="tab"
          class="tf-folder-tabs__tab"
          :class="{ 'tf-folder-tabs__tab--active': model === tab.name }"
          :aria-selected="model === tab.name"
          :aria-controls="panelId"
          :tabindex="model === tab.name ? 0 : -1"
          @click="selectTab(tab.name)"
        >
          {{ tab.label }}
        </button>
        </div>
        <div v-if="$slots['header-trailing']" class="tf-folder-tabs__header-trailing">
          <slot name="header-trailing" />
        </div>
      </div>
    </div>
    <div
      :id="panelId"
      class="tf-folder-tabs__panel"
      role="tabpanel"
      :aria-labelledby="activeTabId"
      tabindex="0"
    >
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, useId } from 'vue';

export interface TfFolderTabItem {
  name: string | number;
  label: string;
}

const props = withDefaults(
  defineProps<{
    tabs: readonly TfFolderTabItem[];
    ariaLabel: string;
    /** Flat chrome inside overlays (no card border / viewport min-height). */
    inset?: boolean;
  }>(),
  { inset: false },
);

const model = defineModel<string | number>({ required: true });

const uid = useId();
const panelId = computed(() => `tf-folder-tabs-panel-${uid}`);

const tabId = (name: string | number) => `tf-folder-tab-${uid}-${String(name)}`;

const activeTabId = computed(() => tabId(model.value));

const tabNames = computed(() => props.tabs.map((t) => t.name));

const selectTab = (name: string | number) => {
  model.value = name;
};

const focusTabByOffset = (offset: number) => {
  const names = tabNames.value;
  const idx = names.indexOf(model.value);
  if (idx < 0) return;
  const next = names[(idx + offset + names.length) % names.length];
  if (next === undefined) return;
  model.value = next;
  const el = document.getElementById(tabId(next));
  el?.focus();
};

const onTabListKeydown = (e: KeyboardEvent) => {
  if (e.key === 'ArrowRight') {
    e.preventDefault();
    focusTabByOffset(1);
    return;
  }
  if (e.key === 'ArrowLeft') {
    e.preventDefault();
    focusTabByOffset(-1);
    return;
  }
  if (e.key === 'Home') {
    e.preventDefault();
    const first = tabNames.value[0];
    if (first !== undefined) {
      model.value = first;
      document.getElementById(tabId(first))?.focus();
    }
    return;
  }
  if (e.key === 'End') {
    e.preventDefault();
    const names = tabNames.value;
    const last = names[names.length - 1];
    if (last !== undefined) {
      model.value = last;
      document.getElementById(tabId(last))?.focus();
    }
  }
};
</script>

<style scoped>
.tf-folder-tabs {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  min-width: 0;
  min-height: var(--tf-folder-tabs-min-height, calc(100dvh - 8rem));
  overflow: hidden;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-md);
  background: var(--tf-neutral-surface);
}

.tf-folder-tabs__header {
  padding: 8px 12px 0;
  background: color-mix(in srgb, var(--tf-neutral-muted) 5%, var(--tf-neutral-canvas));
  border-bottom: 1px solid var(--tf-neutral-border);
}

.tf-folder-tabs__header-row {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  min-width: 0;
}

.tf-folder-tabs__header-trailing {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  align-self: center;
  margin-left: auto;
}

.tf-folder-tabs__bar {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 2px;
  min-height: 36px;
}

.tf-folder-tabs__tab {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  height: 34px;
  margin: 0 0 -1px;
  padding: 0 14px;
  border: 1px solid transparent;
  border-top-width: 2px;
  border-top-color: transparent;
  border-bottom: 1px solid transparent;
  border-radius: 6px 6px 0 0;
  background: transparent;
  color: var(--tf-neutral-muted);
  font-size: 13px;
  font-weight: 500;
  line-height: 1;
  white-space: nowrap;
  cursor: pointer;
  transition:
    background-color 0.12s ease,
    border-color 0.12s ease,
    color 0.12s ease;
}

.tf-folder-tabs__tab:hover:not(.tf-folder-tabs__tab--active) {
  color: var(--tf-neutral-ink);
  background: color-mix(in srgb, var(--tf-neutral-muted) 10%, var(--tf-neutral-surface));
}

.tf-folder-tabs__tab:focus-visible {
  outline: 2px solid var(--tf-theme-primary);
  outline-offset: 1px;
  z-index: 2;
}

.tf-folder-tabs__tab--active {
  height: 35px;
  padding-bottom: 1px;
  border-color: var(--tf-neutral-border);
  border-top-color: var(--tf-theme-primary);
  border-bottom-color: var(--tf-neutral-surface);
  background: var(--tf-neutral-surface);
  color: var(--tf-neutral-ink);
  font-weight: 600;
  z-index: 1;
}

.tf-folder-tabs__panel {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 16px;
  min-height: var(--tf-folder-tabs-panel-min-height, calc(100dvh - 11.5rem));
  background: var(--tf-neutral-surface);
  padding: 12px 16px 16px;
}

.tf-folder-tabs__panel:focus {
  outline: none;
}

.tf-folder-tabs__panel:focus-visible {
  box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--tf-theme-primary) 35%, transparent);
}

.tf-folder-tabs--inset {
  --tf-folder-tabs-min-height: 0;
  --tf-folder-tabs-panel-min-height: 0;
  min-height: 0;
  border: none;
  border-radius: 0;
  box-shadow: none;
}

.tf-folder-tabs--inset .tf-folder-tabs__panel {
  flex: 1 1 auto;
  min-height: 0;
  overflow: auto;
}

.tf-folder-tabs--inset .tf-folder-tabs__header {
  padding: 0 8px 0 0;
}

.tf-folder-tabs--inset .tf-folder-tabs__bar {
  min-height: 32px;
}
</style>
