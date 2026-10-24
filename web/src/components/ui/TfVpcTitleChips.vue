<template>
  <ul class="tf-vpc-chips" :class="`tf-vpc-chips--${align}`">
    <li
      v-for="(item, i) in items"
      :key="i"
      class="tf-vpc-chips__item"
      :style="scatterStyle(i)"
    >
      <button
        type="button"
        class="tf-vpc-pin"
        :class="{ 'tf-vpc-pin--active': activeTitle === item.title }"
        :aria-pressed="activeTitle === item.title"
        :title="item.note ? 'Open note' : item.title"
        @click.stop="$emit('select', item, $event)"
      >
        <span class="tf-vpc-pin__head" aria-hidden="true" />
        <span class="tf-vpc-pin__title">{{ item.title }}</span>
      </button>
    </li>
  </ul>
</template>

<script setup lang="ts">
import type { ValuePropositionCanvasNote } from './valuePropositionCanvas.types';

withDefaults(
  defineProps<{
    items: ValuePropositionCanvasNote[];
    activeTitle?: string;
    align?: 'start' | 'center';
  }>(),
  { align: 'center' },
);

defineEmits<{
  select: [item: ValuePropositionCanvasNote, event: MouseEvent];
}>();

function scatterStyle(index: number) {
  const x = ((index * 53) % 21) - 10;
  const y = ((index * 37) % 15) - 7;
  const r = ((index * 29) % 17) - 8;
  return {
    '--scatter': `translate(${x}px, ${y}px) rotate(${r}deg)`,
    zIndex: String((index % 5) + 1),
  };
}
</script>

<style scoped>
.tf-vpc-chips {
  list-style: none;
  margin: 0;
  padding: 10px 4px 4px;
  display: flex;
  flex-wrap: wrap;
  gap: 2px 4px;
  width: 100%;
  min-width: 0;
}

.tf-vpc-chips--center {
  justify-content: center;
}

.tf-vpc-chips--start {
  justify-content: flex-start;
}

.tf-vpc-chips__item {
  transform: var(--scatter);
  transition: transform 0.15s ease;
}

.tf-vpc-chips__item:hover,
.tf-vpc-chips__item:focus-within {
  z-index: 8;
  transform: var(--scatter) translateY(-3px) scale(1.04);
}

.tf-vpc-pin {
  position: relative;
  display: block;
  width: max-content;
  max-width: 100%;
  margin: 0;
  padding: 7px 8px 5px;
  border: 0;
  background: color-mix(in srgb, #f6e27a 86%, var(--tf-neutral-surface));
  color: #1c1910;
  box-shadow:
    0 1px 0 color-mix(in srgb, #000 10%, transparent),
    0 3px 8px color-mix(in srgb, #000 12%, transparent);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: -0.01em;
  line-height: 1.2;
  text-align: left;
  cursor: pointer;
}

.body--dark .tf-vpc-pin {
  background: color-mix(in srgb, #c9ae3a 58%, var(--tf-neutral-surface));
  color: var(--tf-neutral-ink);
}

.tf-vpc-pin--active {
  outline: 1px solid color-mix(in srgb, #000 22%, transparent);
}

.tf-vpc-pin:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.tf-vpc-pin__head {
  position: absolute;
  top: -6px;
  left: 50%;
  width: 9px;
  height: 9px;
  transform: translateX(-50%);
  border-radius: 50%;
  background: color-mix(in srgb, #c23b3b 88%, #fff);
  box-shadow:
    0 0 0 1.5px color-mix(in srgb, #fff 55%, transparent),
    0 2px 2px color-mix(in srgb, #000 25%, transparent);
}

.tf-vpc-pin__title {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
