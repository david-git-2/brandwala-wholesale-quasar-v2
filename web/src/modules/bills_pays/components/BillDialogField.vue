<template>
  <div class="bill-dialog-field">
    <div v-if="label" class="bill-dialog-field__label text-body2 text-weight-bold">
      {{ label }}
    </div>
    <div v-if="hint" class="bill-dialog-field__hint text-caption text-grey-7 q-mb-xs">
      {{ hint }}
    </div>
    <slot />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  label?: string;
  hint?: string;
}>();
</script>

<style scoped lang="scss">
.bill-dialog-field__label {
  margin-bottom: 4px;
  color: var(--tf-neutral-ink, #171412);
}

.bill-dialog-field__hint {
  margin-top: -2px;
}

.bill-dialog-field :deep(.q-field__prepend) {
  padding-right: 4px;
}
</style>
