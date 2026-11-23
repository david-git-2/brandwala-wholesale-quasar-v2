<template>
  <q-icon :name="name" class="bill-dialog-field-icon" />
</template>

<script setup lang="ts">
defineProps<{
  name: string;
}>();
</script>

<style scoped lang="scss">
.bill-dialog-field-icon {
  font-size: 18px;
  color: var(--tf-neutral-muted, #736a61);
}
</style>
