<template>
  <div class="tf-drawer-section-tabs__scroll" :class="scrollClass">
    <div class="tf-drawer-section-tabs__track" role="tablist" :aria-label="ariaLabel">
      <button
        v-for="tab in tabs"
        :key="String(tab.name)"
        type="button"
        role="tab"
        class="tf-drawer-section-tabs__item"
        :class="{ 'tf-drawer-section-tabs__item--active': model === tab.name }"
        :aria-selected="model === tab.name"
        @click="model = tab.name"
      >
        <q-icon v-if="tab.icon" :name="tab.icon" size="15px" class="tf-drawer-section-tabs__icon" />
        <span>{{ tab.label }}</span>
        <span
          v-if="showCount(tab)"
          class="tf-drawer-section-tabs__count"
          :class="{ 'tf-drawer-section-tabs__count--active': model === tab.name }"
        >
          {{ tab.count }}
        </span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
export interface TfDrawerSectionTab {
  name: string | number;
  label: string;
  icon?: string;
  count?: number;
}

const props = withDefaults(
  defineProps<{
    tabs: TfDrawerSectionTab[];
    ariaLabel: string;
    /** When `positive`, count badge shows only if count &gt; 0. */
    countVisibility?: 'always' | 'positive';
    scrollClass?: string;
  }>(),
  {
    countVisibility: 'always',
    scrollClass: '',
  },
);

const model = defineModel<string | number>({ required: true });

function showCount(tab: TfDrawerSectionTab): boolean {
  if (tab.count === undefined) return false;
  if (props.countVisibility === 'positive') return tab.count > 0;
  return true;
}
</script>

<style scoped>
.tf-drawer-section-tabs__scroll {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}

.tf-drawer-section-tabs__scroll::-webkit-scrollbar {
  display: none;
}

.tf-drawer-section-tabs__track {
  display: inline-flex;
  gap: 4px;
  padding: 4px;
  border-radius: 10px;
  background: var(--tf-disabled-bg);
  min-width: min-content;
}

.tf-drawer-section-tabs__item {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 34px;
  border: none;
  background: transparent;
  color: var(--tf-neutral-muted);
  font-size: 12px;
  font-weight: 600;
  line-height: 1.2;
  padding: 6px 12px;
  border-radius: 8px;
  cursor: pointer;
  white-space: nowrap;
  transition:
    background-color 0.15s ease,
    color 0.15s ease,
    box-shadow 0.15s ease;
}

.tf-drawer-section-tabs__item:hover {
  color: var(--tf-neutral-ink);
}

.tf-drawer-section-tabs__item--active {
  background: var(--tf-neutral-surface);
  color: var(--q-primary);
  box-shadow: none;
  outline: 1px solid var(--tf-neutral-border);
}

.tf-drawer-section-tabs__item--active .tf-drawer-section-tabs__icon {
  color: var(--q-primary);
}

.tf-drawer-section-tabs__count {
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  padding: 2px 5px;
  border-radius: 999px;
  background: var(--tf-neutral-border);
  color: var(--tf-neutral-muted);
}

.tf-drawer-section-tabs__count--active {
  background: color-mix(in srgb, var(--q-primary) 12%, var(--tf-neutral-surface));
  color: var(--q-primary);
}
</style>
