<template>
  <div class="dropship-wizard-nav" :class="`dropship-wizard-nav--${layout}`">
    <template v-if="layout === 'rail'">
      <header class="dropship-wizard-nav__head q-mb-md">
        <div class="text-caption text-weight-bold text-uppercase dropship-wizard-nav__title">
          {{ $t('shop.dropship_place_order_title') }}
        </div>
      </header>

      <ol class="dropship-stepper" aria-label="Order steps">
        <li
          v-for="(step, idx) in steps"
          :key="step.id"
          class="dropship-stepper__item"
          :class="stepItemClass(idx)"
        >
          <div class="dropship-stepper__track" aria-hidden="true">
            <span class="dropship-stepper__dot">
              <q-icon v-if="idx < currentIndex" name="ph ph-check" size="14px" />
              <span v-else class="dropship-stepper__num">{{ idx + 1 }}</span>
            </span>
            <span
              v-if="idx < steps.length - 1"
              class="dropship-stepper__line"
              :class="{ 'dropship-stepper__line--done': idx < currentIndex }"
            />
          </div>

          <button
            type="button"
            class="dropship-stepper__body"
            :disabled="idx > maxReachableIndex"
            @click="idx <= maxReachableIndex && $emit('select', idx)"
          >
            <span class="dropship-stepper__title">{{ $t(step.labelKey) }}</span>
            <span class="dropship-stepper__subtitle">{{ $t(step.shortLabelKey) }}</span>
          </button>
        </li>
      </ol>
    </template>

    <template v-else>
      <q-card flat bordered class="dropship-wizard-nav__compact">
        <q-card-section class="q-pa-sm column q-gutter-y-xs">
          <div class="row items-center justify-between q-gutter-x-sm">
            <div class="col min-width-0">
              <div class="text-caption text-grey-7">
                {{
                  $t('shop.dropship_step_progress', {
                    current: currentIndex + 1,
                    total: steps.length,
                  })
                }}
              </div>
              <div class="text-subtitle2 text-weight-bold ellipsis">
                {{ $t(steps[currentIndex]?.labelKey ?? '') }}
              </div>
            </div>
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              icon-right="ph ph-list"
              :label="$t('shop.dropship_step_list')"
              @click="stepsSheetOpen = true"
            />
          </div>
          <div class="row q-gutter-xs dropship-wizard-nav__segments">
            <div
              v-for="(_, idx) in steps"
              :key="idx"
              class="dropship-wizard-nav__segment col"
              :class="{
                'dropship-wizard-nav__segment--done': idx < currentIndex,
                'dropship-wizard-nav__segment--current': idx === currentIndex,
              }"
            />
          </div>
        </q-card-section>
      </q-card>

      <q-dialog v-model="stepsSheetOpen" position="bottom">
        <q-card class="dropship-wizard-nav__sheet">
          <q-card-section class="q-pa-sm row items-center justify-between">
            <div class="text-subtitle2 text-weight-bold">{{ $t('shop.dropship_step_list') }}</div>
            <q-btn flat round dense icon="ph ph-x" v-close-popup />
          </q-card-section>
          <q-separator />
          <ol class="dropship-stepper q-pa-sm">
            <li
              v-for="(step, idx) in steps"
              :key="step.id"
              class="dropship-stepper__item"
              :class="stepItemClass(idx)"
            >
              <div class="dropship-stepper__track" aria-hidden="true">
                <span class="dropship-stepper__dot">
                  <q-icon v-if="idx < currentIndex" name="ph ph-check" size="14px" />
                  <span v-else class="dropship-stepper__num">{{ idx + 1 }}</span>
                </span>
                <span
                  v-if="idx < steps.length - 1"
                  class="dropship-stepper__line"
                  :class="{ 'dropship-stepper__line--done': idx < currentIndex }"
                />
              </div>
              <button
                type="button"
                class="dropship-stepper__body"
                :disabled="idx > maxReachableIndex"
                @click="onSheetSelect(idx)"
              >
                <span class="dropship-stepper__title">{{ $t(step.labelKey) }}</span>
                <span class="dropship-stepper__subtitle">{{ $t(step.shortLabelKey) }}</span>
              </button>
            </li>
          </ol>
        </q-card>
      </q-dialog>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { DropshipPlaceOrderStepDef } from '../../constants/dropshipPlaceOrderSteps';

const props = defineProps<{
  steps: DropshipPlaceOrderStepDef[];
  currentIndex: number;
  maxReachableIndex: number;
  layout: 'rail' | 'compact';
}>();

const emit = defineEmits<{
  (e: 'select', index: number): void;
}>();

const stepsSheetOpen = ref(false);

const stepItemClass = (idx: number) => ({
  'dropship-stepper__item--done': idx < props.currentIndex,
  'dropship-stepper__item--current': idx === props.currentIndex,
  'dropship-stepper__item--future': idx > props.currentIndex,
  'dropship-stepper__item--disabled': idx > props.maxReachableIndex,
});

const onSheetSelect = (idx: number) => {
  stepsSheetOpen.value = false;
  emit('select', idx);
};
</script>

<style scoped>
.dropship-wizard-nav__title {
  letter-spacing: 0.04em;
  color: var(--tf-neutral-chrome-text);
}

.dropship-stepper {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
}

.dropship-stepper__item {
  display: flex;
  flex-direction: row;
  align-items: stretch;
  gap: 0.75rem;
  min-height: 0;
}

.dropship-stepper__track {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 2rem;
  flex-shrink: 0;
}

.dropship-stepper__dot {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  flex-shrink: 0;
  font-size: 0.8125rem;
  font-weight: 600;
  line-height: 1;
  background: var(--tf-neutral-border);
  color: var(--tf-neutral-muted);
}

.dropship-stepper__item--done .dropship-stepper__dot {
  background: var(--tf-theme-primary);
  color: var(--tf-theme-on-primary, #fff);
}

.dropship-stepper__item--current .dropship-stepper__dot {
  background: var(--tf-theme-primary);
  color: var(--tf-theme-on-primary, #fff);
}

.dropship-stepper__line {
  flex: 1 1 auto;
  width: 2px;
  min-height: 1.35rem;
  margin: 0.2rem 0;
  background: var(--tf-neutral-border);
  border-radius: 1px;
}

.dropship-stepper__line--done {
  background: var(--tf-theme-primary);
}

.dropship-stepper__body {
  flex: 1 1 auto;
  min-width: 0;
  margin: 0 0 0.85rem;
  padding: 0.15rem 0.35rem 0.15rem 0;
  border: 0;
  background: transparent;
  text-align: left;
  cursor: pointer;
  border-radius: var(--tf-radius-sm);
}

.dropship-stepper__item:last-child .dropship-stepper__body {
  margin-bottom: 0;
}

.dropship-stepper__body:hover:not(:disabled) {
  background: var(--tf-theme-primary-soft);
}

.dropship-stepper__body:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.dropship-stepper__title {
  display: block;
  font-size: 0.9375rem;
  font-weight: 600;
  line-height: 1.3;
  color: var(--tf-neutral-ink);
}

.dropship-stepper__item--current .dropship-stepper__title {
  color: var(--tf-neutral-ink);
}

.dropship-stepper__item--future .dropship-stepper__title,
.dropship-stepper__item--disabled .dropship-stepper__title {
  font-weight: 500;
  color: var(--tf-neutral-muted);
}

.dropship-stepper__item--done .dropship-stepper__title {
  color: var(--tf-neutral-chrome-text);
}

.dropship-stepper__subtitle {
  display: block;
  margin-top: 0.15rem;
  font-size: 0.75rem;
  line-height: 1.3;
  color: var(--tf-neutral-muted);
}

.dropship-stepper__item--future .dropship-stepper__subtitle,
.dropship-stepper__item--disabled .dropship-stepper__subtitle {
  color: var(--tf-neutral-border-strong);
}

.dropship-wizard-nav--rail {
  height: 100%;
}

.dropship-wizard-nav__segment {
  height: 4px;
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-border);
}

.dropship-wizard-nav__segment--done,
.dropship-wizard-nav__segment--current {
  background: var(--tf-theme-primary);
}

.dropship-wizard-nav__sheet {
  width: 100%;
  max-width: 100%;
  border-radius: var(--tf-radius-md) var(--tf-radius-md) 0 0;
}

.dropship-wizard-nav--compact {
  position: sticky;
  top: 0;
  z-index: 2;
}
</style>