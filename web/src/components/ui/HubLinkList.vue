<template>
  <div class="hub-link-list">
    <section
      v-for="group in normalizedGroups"
      :key="group.key"
      class="hub-link-list__section"
    >
      <h2 v-if="group.title" class="hub-link-list__heading">{{ group.title }}</h2>
      <div class="portal-stack">
        <button
          v-for="item in group.items"
          :key="item.key"
          type="button"
          class="portal-card"
          :data-test="item.dataTest"
          @click="emit('select', item)"
        >
          <span
            class="portal-card__icon"
            :class="item.iconTone ? `portal-card__icon--${item.iconTone}` : 'portal-card__icon--primary'"
            aria-hidden="true"
          >
            <q-icon :name="item.icon" size="22px" />
          </span>
          <span class="portal-card__body">
            <span class="portal-card__title">{{ item.title }}</span>
            <span v-if="item.caption" class="portal-card__caption">{{ item.caption }}</span>
          </span>
          <q-icon
            name="ph ph-caret-right"
            class="portal-card__chevron"
            size="22px"
            aria-hidden="true"
          />
        </button>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

export type HubLinkItem = {
  key: string;
  title: string;
  caption?: string;
  icon: string;
  iconTone?: 'primary' | 'cod' | 'buy' | 'neutral';
  dataTest?: string;
};

export type HubLinkGroup = {
  key: string;
  title?: string;
  items: HubLinkItem[];
};

const props = defineProps<{
  items?: HubLinkItem[];
  groups?: HubLinkGroup[];
}>();

const emit = defineEmits<{
  select: [item: HubLinkItem];
}>();

const normalizedGroups = computed<HubLinkGroup[]>(() => {
  if (props.groups?.length) {
    return props.groups;
  }

  if (props.items?.length) {
    return [{ key: 'default', items: props.items }];
  }

  return [];
});
</script>

<style scoped>
.hub-link-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.hub-link-list__heading {
  margin: 0 0 0.4rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.portal-stack {
  display: grid;
  gap: 0.75rem;
}

.portal-card {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  width: 100%;
  padding: 1rem;
  min-height: 72px;
  text-align: left;
  border: 1px solid var(--bw-theme-border);
  border-radius: var(--bw-radius-md, 12px);
  background: var(--bw-theme-surface);
  color: inherit;
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease,
    transform 0.12s ease;
}

.portal-card:hover {
  border-color: color-mix(in srgb, var(--bw-theme-primary) 45%, var(--bw-theme-border));
  box-shadow: var(--bw-theme-shadow, 0 8px 24px rgb(0 0 0 / 0.06));
}

.portal-card:active {
  transform: scale(0.99);
}

.portal-card:focus-visible {
  outline: 2px solid var(--bw-theme-primary);
  outline-offset: 2px;
}

.portal-card__icon {
  flex: 0 0 auto;
  width: 44px;
  height: 44px;
  border-radius: var(--bw-radius-sm, 8px);
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.portal-card__icon--primary {
  background: var(--bw-theme-primary-soft, rgb(var(--bw-theme-primary-rgb, 52 211 153) / 0.15));
  color: var(--bw-theme-primary);
}

.portal-card__icon--cod {
  background: rgba(245, 158, 11, 0.14);
  color: #b45309;
}

.portal-card__icon--buy {
  background: rgba(55, 65, 81, 0.1);
  color: #374151;
}

.portal-card__icon--neutral {
  background: color-mix(in srgb, var(--bw-theme-muted) 14%, transparent);
  color: var(--bw-theme-ink);
}

.portal-card__body {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.portal-card__title {
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.3;
  color: var(--bw-theme-ink);
}

.portal-card__caption {
  font-size: 0.875rem;
  line-height: 1.35;
  color: var(--bw-theme-muted);
}

.portal-card__chevron {
  flex: 0 0 auto;
  color: var(--bw-theme-muted);
  opacity: 0.55;
}
</style>
