<template>
  <div class="tf-empty column items-center justify-center text-center">
    <q-icon :name="icon" size="28px" class="tf-empty__icon" />
    <div class="tf-empty__title">{{ title }}</div>
    <div v-if="message" class="tf-empty__msg">{{ message }}</div>
    <div v-if="$slots.default" class="q-mt-sm"><slot /></div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ title: string; message?: string; icon?: string }>(), {
  icon: 'ph ph-tray',
});
</script>

<style scoped>
.tf-empty {
  padding: 32px 16px;
}
.tf-empty__icon {
  color: var(--tf-neutral-chrome);
}
.tf-empty__title {
  margin-top: 8px;
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
}
.tf-empty__msg {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}
</style>
