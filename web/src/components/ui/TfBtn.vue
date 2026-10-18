<template>
  <q-btn
    v-bind="forwardedAttrs"
    :label="label"
    :icon="icon"
    :no-caps="true"
    :unelevated="true"
    :outline="outline"
    :flat="flat"
    :ripple="false"
    :dense="dense"
    :color="color ?? resolvedColor"
    :size="resolvedSize"
    :loading="loading"
    :disable="disable"
    :padding="padding"
    :class="btnClass"
  >
    <slot />
  </q-btn>
</template>

<script setup lang="ts">
import { computed, useAttrs } from 'vue';

export type TfBtnVariant =
  | 'primary'
  | 'secondary'
  | 'tertiary'
  | 'danger'
  | 'danger-trigger'
  | 'success'
  | 'icon'
  | 'link'
  | 'fab';

const props = withDefaults(
  defineProps<{
    variant?: TfBtnVariant;
    label?: string;
    icon?: string;
    /** Overrides variant color when set (e.g. `negative` on icon actions). */
    color?: string;
    loading?: boolean;
    disable?: boolean;
    size?: 'sm' | 'md' | 'lg';
    shopCta?: boolean;
  }>(),
  {
    variant: 'primary',
    loading: false,
    disable: false,
    size: 'sm',
    shopCta: false,
  },
);

const attrs = useAttrs();

const outline = computed(() => props.variant === 'secondary' || props.variant === 'danger-trigger');
const flat = computed(
  () =>
    props.variant === 'tertiary' ||
    props.variant === 'danger-trigger' ||
    props.variant === 'icon' ||
    props.variant === 'link',
);
const dense = computed(() => props.variant === 'icon' || props.variant === 'link' || props.size === 'sm');

const resolvedColor = computed(() => {
  switch (props.variant) {
    case 'primary':
    case 'secondary':
    case 'link':
    case 'fab':
      return 'primary';
    case 'tertiary':
      return 'neutral';
    case 'danger':
    case 'danger-trigger':
      return 'negative';
    case 'success':
      return 'positive';
    case 'icon':
      return 'neutral';
    default:
      return 'primary';
  }
});

const resolvedSize = computed(() => {
  if (props.variant === 'icon') return 'sm';
  return props.size;
});

const padding = computed(() => (props.variant === 'link' ? 'none' : undefined));

const btnClass = computed(() => {
  const c: string[] = ['tf-btn'];
  if (props.variant === 'icon') c.push('tf-btn--icon');
  if (props.shopCta && (props.variant === 'primary' || props.variant === 'secondary')) {
    c.push('tf-btn--shop-pill');
  }
  return c.join(' ');
});

const forwardedAttrs = computed(() => {
  const { class: _c, style: _s, ...rest } = attrs;
  return rest;
});
</script>

<style scoped>
.tf-btn {
  border-radius: var(--tf-radius-sm);
  transition: background-color var(--tf-dur-fast) var(--tf-ease), border-color var(--tf-dur-fast) var(--tf-ease);
}
.tf-btn--icon {
  width: 28px;
  height: 28px;
}
.tf-btn--shop-pill {
  border-radius: var(--tf-radius-pill) !important;
}
</style>
