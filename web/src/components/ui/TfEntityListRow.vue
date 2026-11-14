<template>
  <div
    v-if="skeleton"
    class="tf-entity-list-item tf-entity-list-item--skeleton"
    role="presentation"
  >
    <q-skeleton type="rect" width="40px" height="40px" class="tf-entity-list-item__avatar-skel" />
    <div class="tf-entity-list-item__main">
      <q-skeleton type="text" width="180px" height="18px" />
      <q-skeleton type="text" width="280px" height="14px" class="q-mt-xs" />
    </div>
  </div>
  <div
    v-else
    v-bind="$attrs"
    class="tf-entity-list-item"
    :class="{ 'tf-entity-list-item--active': active }"
    :role="clickable ? 'button' : undefined"
    :tabindex="clickable ? 0 : undefined"
    @click="onClick"
    @keydown.enter.prevent="onClick"
    @keydown.space.prevent="onClick"
  >
    <div v-if="$slots.avatar" class="tf-entity-list-item__avatar">
      <slot name="avatar" />
    </div>
    <div class="tf-entity-list-item__main">
      <div v-if="$slots.title" class="tf-entity-list-item__title-row">
        <slot name="title" />
      </div>
      <div v-if="$slots.meta" class="tf-entity-list-item__meta">
        <slot name="meta" />
      </div>
    </div>
    <div v-if="$slots.aside || showChevron" class="tf-entity-list-item__aside">
      <slot name="aside" />
      <q-icon
        v-if="showChevron"
        name="ph ph-caret-right"
        size="16px"
        class="tf-entity-list-item__chevron"
        aria-hidden="true"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
defineOptions({ inheritAttrs: false });

const props = withDefaults(
  defineProps<{
    active?: boolean;
    clickable?: boolean;
    showChevron?: boolean;
    skeleton?: boolean;
  }>(),
  {
    active: false,
    clickable: true,
    showChevron: true,
    skeleton: false,
  },
);

const emit = defineEmits<{
  click: [];
}>();

const onClick = () => {
  if (!props.clickable || props.skeleton) return;
  emit('click');
};
</script>

<style scoped lang="scss">
@import 'src/css/tf-entity-list.scss';

.tf-entity-list-item__avatar-skel :deep(.q-skeleton) {
  border-radius: var(--tf-radius-sm, 8px);
}
</style>