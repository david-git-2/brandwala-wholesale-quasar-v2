<template>
  <q-card
    flat
    bordered
    class="bw-entity-card"
    :class="{
      'bw-entity-card--interactive': clickable,
      'cursor-pointer': clickable,
    }"
    @click="handleCardClick"
  >
    <q-card-section class="bw-entity-card__top">
      <div class="bw-entity-card__eyebrow-row">
        <div v-if="eyebrow" class="bw-entity-card__eyebrow">{{ eyebrow }}</div>
        <q-badge
          v-if="statusLabel"
          rounded
          class="bw-entity-card__status"
          :class="`bw-entity-card__status--${statusTone}`"
        >
          {{ statusLabel }}
        </q-badge>
      </div>

      <div class="bw-entity-card__title">{{ title }}</div>

      <div v-if="meta" class="bw-entity-card__meta">{{ meta }}</div>

      <div v-if="description" class="bw-entity-card__description">
        {{ description }}
      </div>
    </q-card-section>

    <q-separator v-if="$slots.actions" />

    <q-card-actions v-if="$slots.actions" align="between" class="bw-entity-card__actions">
      <slot name="actions" />
    </q-card-actions>
  </q-card>
</template>

<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    title: string
    eyebrow?: string
    meta?: string
    description?: string
    statusLabel?: string
    statusTone?: 'positive' | 'neutral' | 'warning'
    clickable?: boolean
  }>(),
  {
    statusTone: 'neutral',
    clickable: false,
  },
)

const emit = defineEmits<{
  click: []
}>()

const handleCardClick = () => {
  if (!props.clickable) {
    return
  }

  emit('click')
}
</script>

<style scoped>
.bw-entity-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border-color: color-mix(in srgb, var(--bw-theme-border) 92%, transparent);
}

.bw-entity-card--interactive:hover {
  border-color: rgb(var(--bw-theme-primary-rgb) / 0.28);
}

.bw-entity-card__top {
  display: grid;
  gap: 0.72rem;
  min-height: 100%;
}

.bw-entity-card__eyebrow-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.bw-entity-card__eyebrow {
  min-width: 0;
  font-size: 0.74rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--bw-theme-primary);
}

.bw-entity-card__title {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 1.02rem;
  line-height: 1.3;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.bw-entity-card__meta {
  font-size: 0.88rem;
  line-height: 1.55;
  color: var(--bw-theme-muted);
}

.bw-entity-card__description {
  display: -webkit-box;
  min-height: 4.3rem;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.92rem;
  line-height: 1.6;
  color: color-mix(in srgb, var(--bw-theme-ink) 78%, var(--bw-theme-muted));
}

.bw-entity-card__actions {
  margin-top: auto;
  padding: 0.75rem 1rem;
}

.bw-entity-card__status {
  border: 1px solid transparent;
  font-weight: 600;
}

.bw-entity-card__status--positive {
  color: #1f6a48;
  background: rgb(47 125 87 / 0.12);
  border-color: rgb(47 125 87 / 0.14);
}

.bw-entity-card__status--neutral {
  color: var(--bw-theme-muted);
  background: color-mix(in srgb, var(--bw-theme-border) 88%, white 12%);
  border-color: color-mix(in srgb, var(--bw-theme-border) 96%, transparent);
}

.bw-entity-card__status--warning {
  color: #8a5412;
  background: rgb(242 192 55 / 0.18);
  border-color: rgb(242 192 55 / 0.18);
}
</style>
