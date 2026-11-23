<template>
  <q-dialog
    v-model="isOpen"
    position="right"
    full-height
    transition-show="slide-left"
    transition-hide="slide-right"
    @show="emit('show')"
    @before-hide="emit('beforeHide')"
  >
    <div class="paper-drawer">
      <div class="paper-drawer__body">
        <slot />
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'show'): void;
  (e: 'beforeHide'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});
</script>

<style scoped>
.paper-drawer {
  width: 400px;
  max-width: 95vw;
  height: 100%;
  background: #fbf9f4;
  background-image: linear-gradient(180deg, #fdfbf7 0%, #f7f3eb 100%);
  border-left: 1px solid #e5dec9;
  box-shadow: -8px 0 32px rgba(68, 55, 33, 0.08);
  display: flex;
  flex-direction: column;
  justify-content: center;
  color: #1c1917;
  overflow: hidden;
  position: relative;
}

.paper-drawer::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: radial-gradient(#ebe1d0 0.75px, transparent 0.75px);
  background-size: 16px 16px;
  opacity: 0.45;
  pointer-events: none;
}

.paper-drawer__body {
  position: relative;
  z-index: 1;
  padding: 1.35rem 1.45rem;
  display: flex;
  flex-direction: column;
  gap: 1.15rem;
  overflow: hidden;
}

:slotted(.paper-section) {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

:slotted(.paper-section__head) {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid #e8e0ce;
}

:slotted(.paper-section__title) {
  font-size: 0.76rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #292524;
}

:slotted(.paper-section__meta) {
  font-size: 0.72rem;
  font-weight: 700;
  color: #78716c;
}

:slotted(.paper-rule) {
  width: 100%;
  height: 1px;
  background: repeating-linear-gradient(
    90deg,
    #e2dac7 0px,
    #e2dac7 4px,
    transparent 4px,
    transparent 8px
  );
  opacity: 0.85;
}

:slotted(.availability-row) {
  display: flex;
  align-items: center;
  gap: 1.15rem;
}

:slotted(.donut-wrap) {
  position: relative;
  width: 95px;
  height: 95px;
  flex-shrink: 0;
}

:slotted(.donut-center) {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
}

:slotted(.donut-center__val) {
  font-size: 0.98rem;
  font-weight: 800;
  color: #1c1917;
  line-height: 1;
}

:slotted(.donut-center__sub) {
  font-size: 0.6rem;
  font-weight: 700;
  color: #57534e;
  margin-top: 0.1rem;
}

:slotted(.legend-list),
:slotted(.grade-list) {
  display: grid;
  gap: 0.4rem;
  flex: 1 1 auto;
}

:slotted(.legend-row),
:slotted(.grade-row) {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.75rem;
  padding: 0.15rem 0;
  border-bottom: 1px dashed #ede5d5;
}

:slotted(.legend-row__left),
:slotted(.grade-row__left) {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

:slotted(.ink-dot) {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}

:slotted(.legend-row__label) {
  font-weight: 600;
  color: #44403c;
}

:slotted(.legend-row__right) {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
}

:slotted(.legend-row__val),
:slotted(.grade-row__val) {
  font-weight: 800;
  color: #1c1917;
}

:slotted(.legend-row__pct) {
  font-size: 0.68rem;
  font-weight: 700;
  color: #78716c;
}

:slotted(.grade-row__desc) {
  font-size: 0.68rem;
  color: #57534e;
  font-weight: 500;
}

:slotted(.bar-chart-wrap) {
  height: 95px;
  position: relative;
}

:slotted(.chart-fade-enter-active),
:slotted(.chart-fade-leave-active) {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

:slotted(.chart-fade-enter-from),
:slotted(.chart-fade-leave-to) {
  opacity: 0;
  transform: scale(0.96);
}
</style>
