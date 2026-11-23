<template>
  <div
    v-if="!hidden"
    class="excel-table-scroll-footer row items-center justify-end q-px-md q-py-xs"
  >
    <div class="excel-scrollbar-wrapper row items-center no-wrap">
      <button type="button" class="excel-scroll-arrow-btn" @click="scrollByStep(-150)">
        <q-icon name="ph ph-caret-left" size="13px" />
      </button>
      <div ref="scrollTrackRef" class="excel-scroll-track cursor-pointer" @click="onTrackClick">
        <div
          class="excel-scroll-thumb"
          :style="{ width: thumbWidth + '%', left: thumbLeft + '%' }"
          @mousedown="startThumbDrag"
        />
      </div>
      <button type="button" class="excel-scroll-arrow-btn" @click="scrollByStep(150)">
        <q-icon name="ph ph-caret-right" size="13px" />
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, ref, watchEffect } from 'vue';

const props = withDefaults(
  defineProps<{
    getScrollContainer: () => HTMLElement | null;
    hidden?: boolean;
  }>(),
  { hidden: false },
);

const scrollTrackRef = ref<HTMLElement | null>(null);
const thumbWidth = ref(30);
const thumbLeft = ref(0);
function getContainer(): HTMLElement | null {
  return props.getScrollContainer();
}

function updateThumb() {
  const el = getContainer();
  if (!el) {
    return;
  }
  const maxScrollLeft = el.scrollWidth - el.clientWidth;
  if (maxScrollLeft <= 0) {
    thumbWidth.value = 100;
    thumbLeft.value = 0;
    return;
  }
  const ratio = el.clientWidth / el.scrollWidth;
  thumbWidth.value = Math.max(15, Math.min(80, ratio * 100));
  thumbLeft.value = (el.scrollLeft / maxScrollLeft) * (100 - thumbWidth.value);
}

function scrollByStep(delta: number) {
  getContainer()?.scrollBy({ left: delta, behavior: 'smooth' });
}

function onTrackClick(e: MouseEvent) {
  const table = getContainer();
  const track = scrollTrackRef.value;
  if (!table || !track) return;
  const rect = track.getBoundingClientRect();
  const fraction = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
}

function startThumbDrag(e: MouseEvent) {
  e.preventDefault();
  e.stopPropagation();
  const table = getContainer();
  const track = scrollTrackRef.value;
  if (!table || !track) return;

  const startX = e.clientX;
  const startScrollLeft = table.scrollLeft;
  const trackRect = track.getBoundingClientRect();
  const availableTrackWidth = trackRect.width * (1 - thumbWidth.value / 100);
  const maxScrollLeft = table.scrollWidth - table.clientWidth;

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (availableTrackWidth <= 0) return;
    const deltaScroll = ((moveEvent.clientX - startX) / availableTrackWidth) * maxScrollLeft;
    table.scrollLeft = Math.max(0, Math.min(maxScrollLeft, startScrollLeft + deltaScroll));
    updateThumb();
  };

  const onMouseUp = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  };

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
}

function onContainerScroll() {
  updateThumb();
}

let observedEl: HTMLElement | null = null;
let resizeObserver: ResizeObserver | null = null;

function bindContainer(el: HTMLElement | null) {
  if (observedEl) {
    observedEl.removeEventListener('scroll', onContainerScroll);
  }
  observedEl = el;
  if (el) {
    el.addEventListener('scroll', onContainerScroll, { passive: true });
    updateThumb();
  }
}

watchEffect((onCleanup) => {
  const el = props.getScrollContainer();
  bindContainer(el);
  if (el && typeof ResizeObserver !== 'undefined') {
    resizeObserver?.disconnect();
    resizeObserver = new ResizeObserver(() => updateThumb());
    resizeObserver.observe(el);
    const table = el.querySelector('table');
    if (table) {
      resizeObserver.observe(table);
    } else if (el.firstElementChild) {
      resizeObserver.observe(el.firstElementChild);
    }
    onCleanup(() => resizeObserver?.disconnect());
  }
});

onMounted(() => {
  window.addEventListener('resize', updateThumb);
  requestAnimationFrame(updateThumb);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateThumb);
  resizeObserver?.disconnect();
  if (observedEl) {
    observedEl.removeEventListener('scroll', onContainerScroll);
  }
});

defineExpose({ updateThumb });
</script>

<style scoped>
.excel-table-scroll-footer {
  flex-shrink: 0;
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  background: var(--tf-neutral-surface, #fff);
}

.excel-scrollbar-wrapper {
  width: min(520px, 100%);
  gap: 4px;
  flex-shrink: 0;
}

.excel-scroll-track {
  position: relative;
  flex: 1;
  min-width: 140px;
  height: 10px;
  background: #e2e8f0;
  border-radius: 999px;
  overflow: hidden;
}

.excel-scroll-thumb {
  position: absolute;
  top: 0;
  height: 100%;
  background: #64748b;
  border-radius: 999px;
  cursor: grab;
}

.excel-scroll-arrow-btn {
  border: none;
  background: transparent;
  color: #64748b;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
}

.excel-scroll-arrow-btn:hover {
  background: var(--tf-hover-bg);
  color: #334155;
}
</style>