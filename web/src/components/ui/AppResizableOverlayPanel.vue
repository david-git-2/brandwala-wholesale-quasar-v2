<template>
  <Teleport to="body">
    <Transition name="app-resizable-overlay-panel">
      <div
        v-if="modelValue"
        class="app-resizable-overlay-panel"
        :class="`app-resizable-overlay-panel--${side}`"
        :style="rootStyle"
        role="presentation"
      >
        <div
          class="app-resizable-overlay-panel__backdrop"
          aria-hidden="true"
          @click="close"
        />
        <aside
          ref="panelRef"
          class="app-resizable-overlay-panel__panel bg-white"
          :style="panelStyle"
          :aria-label="ariaLabel"
          tabindex="-1"
          @keydown.escape="close"
        >
          <div
            class="app-resizable-overlay-panel__resize"
            role="separator"
            aria-orientation="vertical"
            aria-label="Resize panel"
            @mousedown.prevent="onResizePointerDown"
          >
            <span class="app-resizable-overlay-panel__anchor" aria-hidden="true">
              <span class="app-resizable-overlay-panel__anchor-grip" />
            </span>
          </div>
          <div class="app-resizable-overlay-panel__body column full-height no-wrap overflow-hidden">
            <slot />
          </div>
        </aside>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { computed, onUnmounted, ref, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    side?: 'left' | 'right';
    minWidth?: number;
    maxWidth?: number;
    defaultWidth?: number;
    /** Persist width in localStorage when set */
    storageKey?: string;
    ariaLabel?: string;
    zIndex?: number;
  }>(),
  {
    side: 'right',
    minWidth: 320,
    maxWidth: 1200,
    defaultWidth: 680,
    ariaLabel: 'Side panel',
    zIndex: 6000,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const panelRef = ref<HTMLElement | null>(null);
const panelWidth = ref(loadInitialWidth());

function loadInitialWidth(): number {
  if (props.storageKey) {
    try {
      const raw = localStorage.getItem(props.storageKey);
      const n = raw ? Number.parseInt(raw, 10) : NaN;
      if (Number.isFinite(n)) {
        return clampWidth(n);
      }
    } catch {
      /* ignore */
    }
  }
  return clampWidth(props.defaultWidth);
}

function clampWidth(w: number): number {
  const max = Math.min(props.maxWidth, Math.floor(window.innerWidth * 0.96));
  return Math.min(max, Math.max(props.minWidth, w));
}

const panelStyle = computed(() => ({
  width: `${panelWidth.value}px`,
}));

const rootStyle = computed(() => ({
  zIndex: props.zIndex,
}));

function close() {
  emit('update:modelValue', false);
}

let resizing = false;
let startX = 0;
let startWidth = 0;

function onResizePointerDown(ev: MouseEvent) {
  resizing = true;
  startX = ev.clientX;
  startWidth = panelWidth.value;
  document.body.style.cursor = 'col-resize';
  document.body.style.userSelect = 'none';
  document.addEventListener('mousemove', onResizeMove);
  document.addEventListener('mouseup', onResizeEnd);
}

function onResizeMove(ev: MouseEvent) {
  if (!resizing) return;
  const delta = props.side === 'right' ? startX - ev.clientX : ev.clientX - startX;
  panelWidth.value = clampWidth(startWidth + delta);
}

function onResizeEnd() {
  if (!resizing) return;
  resizing = false;
  document.body.style.cursor = '';
  document.body.style.userSelect = '';
  document.removeEventListener('mousemove', onResizeMove);
  document.removeEventListener('mouseup', onResizeEnd);
  if (props.storageKey) {
    try {
      localStorage.setItem(props.storageKey, String(panelWidth.value));
    } catch {
      /* ignore */
    }
  }
}

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      panelWidth.value = clampWidth(panelWidth.value);
      requestAnimationFrame(() => panelRef.value?.focus());
    }
  },
);

onUnmounted(() => {
  onResizeEnd();
});
</script>

<style scoped>
.app-resizable-overlay-panel {
  position: fixed;
  inset: 0;
  z-index: 6000;
  pointer-events: none;
}

.app-resizable-overlay-panel__backdrop {
  position: absolute;
  top: var(--workspace-header-offset, 44px);
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(15, 23, 42, 0.28);
  pointer-events: auto;
}

.app-resizable-overlay-panel__panel {
  position: absolute;
  top: var(--workspace-header-offset, 44px);
  bottom: 0;
  display: flex;
  flex-direction: row;
  max-width: 96vw;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  box-shadow: -8px 0 32px rgba(15, 23, 42, 0.12);
  pointer-events: auto;
  outline: none;
}

.app-resizable-overlay-panel--right .app-resizable-overlay-panel__panel {
  right: 0;
  border-right: none;
  border-radius: var(--bw-radius-md, 12px) 0 0 var(--bw-radius-md, 12px);
}

.app-resizable-overlay-panel--left .app-resizable-overlay-panel__panel {
  left: 0;
  border-left: none;
  border-radius: 0 var(--bw-radius-md, 12px) var(--bw-radius-md, 12px) 0;
  box-shadow: 8px 0 32px rgba(15, 23, 42, 0.12);
}

.app-resizable-overlay-panel__resize {
  flex: 0 0 10px;
  width: 10px;
  cursor: col-resize;
  touch-action: none;
  background: transparent;
  position: relative;
  z-index: 1;
}

.app-resizable-overlay-panel__resize::after {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: 4px;
  width: 2px;
  border-radius: 2px;
  background: color-mix(in srgb, var(--bw-theme-border, #e2e8f0) 70%, transparent);
  transition: background-color 0.15s ease;
}

.app-resizable-overlay-panel__resize:hover::after,
.app-resizable-overlay-panel__resize:active::after {
  background: var(--q-primary, #059669);
}

.app-resizable-overlay-panel__anchor {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  align-items: center;
  justify-content: center;
  width: 14px;
  height: 40px;
  border-radius: var(--bw-radius-pill, 999px);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-theme-surface, #fff);
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.1);
  pointer-events: none;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
}

.app-resizable-overlay-panel__anchor-grip {
  width: 4px;
  height: 18px;
  border-radius: 2px;
  background: repeating-linear-gradient(
    to bottom,
    var(--bw-theme-muted, #94a3b8) 0,
    var(--bw-theme-muted, #94a3b8) 2px,
    transparent 2px,
    transparent 5px
  );
}

.app-resizable-overlay-panel__resize:hover .app-resizable-overlay-panel__anchor,
.app-resizable-overlay-panel__resize:active .app-resizable-overlay-panel__anchor {
  border-color: color-mix(in srgb, var(--q-primary, #059669) 45%, var(--bw-theme-border, #e2e8f0));
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.14);
}

.app-resizable-overlay-panel__resize:hover .app-resizable-overlay-panel__anchor-grip,
.app-resizable-overlay-panel__resize:active .app-resizable-overlay-panel__anchor-grip {
  background: repeating-linear-gradient(
    to bottom,
    var(--q-primary, #059669) 0,
    var(--q-primary, #059669) 2px,
    transparent 2px,
    transparent 5px
  );
}

.app-resizable-overlay-panel--right .app-resizable-overlay-panel__resize {
  order: -1;
}

.app-resizable-overlay-panel__body {
  flex: 1 1 auto;
  min-width: 0;
  min-height: 0;
}

.app-resizable-overlay-panel-enter-active,
.app-resizable-overlay-panel-leave-active {
  transition: opacity 0.2s ease;
}

.app-resizable-overlay-panel-enter-active .app-resizable-overlay-panel__panel,
.app-resizable-overlay-panel-leave-active .app-resizable-overlay-panel__panel {
  transition: transform 0.22s ease;
}

.app-resizable-overlay-panel-enter-from,
.app-resizable-overlay-panel-leave-to {
  opacity: 0;
}

.app-resizable-overlay-panel--right.app-resizable-overlay-panel-enter-from .app-resizable-overlay-panel__panel,
.app-resizable-overlay-panel--right.app-resizable-overlay-panel-leave-to .app-resizable-overlay-panel__panel {
  transform: translateX(100%);
}

.app-resizable-overlay-panel--left.app-resizable-overlay-panel-enter-from .app-resizable-overlay-panel__panel,
.app-resizable-overlay-panel--left.app-resizable-overlay-panel-leave-to .app-resizable-overlay-panel__panel {
  transform: translateX(-100%);
}
</style>
