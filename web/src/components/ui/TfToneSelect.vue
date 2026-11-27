<template>
  <div
    class="tf-tone-select"
    :class="{ 'tf-tone-select--disabled': disable && !readonly }"
  >
    <div
      v-if="readonly"
      class="tf-tone-select__trigger tf-tone-select__trigger--readonly"
      :class="toneClass"
      :aria-label="resolvedAriaLabel"
    >
      <span class="tf-tone-select__label">{{ selectedLabel }}</span>
    </div>
    <q-btn
      v-else
      flat
      dense
      no-caps
      unelevated
      :disable="disable"
      class="tf-tone-select__trigger"
      :class="toneClass"
      :aria-label="resolvedAriaLabel"
      :aria-haspopup="true"
      :aria-expanded="menuOpen ? 'true' : 'false'"
    >
      <span class="tf-tone-select__label">{{ selectedLabel }}</span>
      <q-menu
        v-model="menuOpen"
        anchor="bottom middle"
        self="top middle"
        :offset="[0, 2]"
        class="tf-tone-select__menu"
      >
        <q-list dense class="tf-tone-select__list">
          <q-item
            v-for="opt in options"
            :key="String(opt.value)"
            v-close-popup
            clickable
            class="tf-tone-select__item"
            :class="menuItemClass(opt.value)"
            @click="onPick(opt.value)"
          >
            <q-item-section>{{ opt.label }}</q-item-section>
          </q-item>
        </q-list>
      </q-menu>
    </q-btn>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';

export type TfToneSelectOption = {
  label: string;
  value: string | number | null;
};

const props = withDefaults(
  defineProps<{
    modelValue: string | number | null;
    options: TfToneSelectOption[];
    toneClass?: string;
    disable?: boolean;
    readonly?: boolean;
    ariaLabel?: string;
  }>(),
  {
    toneClass: '',
    disable: false,
    readonly: false,
    ariaLabel: undefined,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: string | number | null];
}>();

const menuOpen = ref(false);

const isSelected = (value: string | number | null) => {
  if (props.modelValue === value) return true;
  if (props.modelValue == null && value == null) return true;
  return false;
};

const selectedLabel = computed(() => {
  const match = props.options.find((opt) => isSelected(opt.value));
  if (match) return match.label;
  if (props.modelValue == null || props.modelValue === '') return '—';
  return String(props.modelValue);
});

const resolvedAriaLabel = computed(
  () => props.ariaLabel ?? `Selected: ${selectedLabel.value}`,
);

const onPick = (value: string | number | null) => {
  if (props.disable) return;
  if (isSelected(value)) return;
  emit('update:modelValue', value);
};

const menuItemClass = (value: string | number | null) => {
  if (!isSelected(value)) return undefined;
  return [props.toneClass, 'tf-tone-select__item--selected-tone'].filter(Boolean);
};
</script>

<style scoped>
.tf-tone-select {
  width: 100%;
  height: 100%;
  min-height: 2rem;
  display: flex;
  align-items: stretch;
}

.tf-tone-select__trigger {
  width: 100%;
  min-height: 2rem;
  flex: 1 1 auto;
  padding: 0.35rem 0.4rem;
  border-radius: 0;
  font-weight: 700;
  font-size: 11px;
  line-height: 1.3;
  text-align: center;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.tf-tone-select__trigger :deep(.q-btn__content) {
  width: 100%;
  justify-content: center;
  flex-wrap: wrap;
  gap: 0;
}

.tf-tone-select__trigger--readonly {
  display: flex;
  align-items: center;
  justify-content: center;
}

.tf-tone-select__label {
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  max-width: 100%;
}

.tf-tone-select--disabled .tf-tone-select__trigger {
  opacity: 0.65;
}
</style>

<style>
.tf-tone-select__menu {
  min-width: 10.5rem;
  border-radius: 8px;
  border: 1px solid var(--tf-neutral-border);
  box-shadow: 0 6px 20px color-mix(in srgb, var(--tf-neutral-ink) 10%, transparent);
}

.tf-tone-select__list {
  padding: 0.25rem 0;
}

.tf-tone-select__item {
  min-height: 2rem;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
}

.tf-tone-select__item--selected-tone {
  margin: 0 0.25rem;
  border-radius: 6px;
  font-weight: 700;
}

.tf-tone-select__item--selected-tone .q-item__section {
  color: inherit;
}

.tf-tone-select__item--selected-tone .q-focus-helper {
  opacity: 0 !important;
}
</style>