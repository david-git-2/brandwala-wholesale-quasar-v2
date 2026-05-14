<template>
  <transition name="filter-sidebar-fade">
    <div
      v-if="modelValue"
      class="filter-sidebar__backdrop"
      @click="close"
    />
  </transition>

  <transition name="filter-sidebar-slide">
    <div
      v-if="modelValue"
      class="filter-sidebar"
      :style="panelStyle"
      @click.stop
    >
      <div class="filter-sidebar__inner q-pa-md">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-subtitle1 text-weight-bold">{{ title }}</div>
          <q-btn
            flat
            round
            dense
            icon="close"
            :aria-label="`Close ${title}`"
            @click="close"
          />
        </div>

        <slot />
      </div>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'

const props = withDefaults(
  defineProps<{
    modelValue: boolean
    title?: string
    topOffset?: number
    bottomOffset?: number
    width?: string
  }>(),
  {
    title: 'Filters',
    topOffset: 76,
    bottomOffset: 12,
    width: 'min(320px, 92vw)',
  },
)

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void
}>()

const close = () => {
  emit('update:modelValue', false)
}

const onWindowKeyDown = (event: KeyboardEvent) => {
  if (event.key === 'Escape' && props.modelValue) {
    close()
  }
}

onMounted(() => {
  window.addEventListener('keydown', onWindowKeyDown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeyDown)
})

const panelStyle = computed(() => ({
  top: `${props.topOffset}px`,
  bottom: `${props.bottomOffset}px`,
  width: props.width,
}))
</script>

<style scoped>
.filter-sidebar__backdrop {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.12);
  backdrop-filter: blur(6px) saturate(120%);
  z-index: 2998;
}

.filter-sidebar {
  position: fixed;
  right: 0;
  padding: 12px;
  box-sizing: border-box;
  z-index: 2999;
}

.filter-sidebar__inner {
  position: relative;
  overflow: hidden;
  width: 100%;
  height: 100%;
  background: linear-gradient(
    160deg,
    rgba(255, 255, 255, 0.62),
    rgba(255, 255, 255, 0.38)
  );
  border: 1px solid rgba(255, 255, 255, 0.58);
  border-radius: 16px;
  backdrop-filter: blur(18px) saturate(135%);
  box-shadow:
    0 14px 34px rgba(15, 23, 42, 0.18),
    inset 0 1px 0 rgba(255, 255, 255, 0.55);
}

.filter-sidebar__inner::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: linear-gradient(
    140deg,
    rgba(255, 255, 255, 0.45) 0%,
    rgba(255, 255, 255, 0.08) 40%,
    rgba(255, 255, 255, 0.03) 100%
  );
}

.filter-sidebar-fade-enter-active,
.filter-sidebar-fade-leave-active {
  transition: opacity 0.2s ease;
}

.filter-sidebar-fade-enter-from,
.filter-sidebar-fade-leave-to {
  opacity: 0;
}

.filter-sidebar-slide-enter-active,
.filter-sidebar-slide-leave-active {
  transition: transform 0.22s ease, opacity 0.22s ease;
}

.filter-sidebar-slide-enter-from,
.filter-sidebar-slide-leave-to {
  transform: translateX(18px);
  opacity: 0;
}
</style>
