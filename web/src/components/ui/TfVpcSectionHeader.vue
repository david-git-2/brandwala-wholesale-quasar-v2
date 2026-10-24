<template>
  <div class="tf-vpc-section-header" :class="`tf-vpc-section-header--${align}`">
    <q-icon :name="icon" size="14px" class="tf-vpc-section-header__icon" />
    <span class="tf-vpc-section-header__label">{{ label }}</span>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    icon: string;
    label: string;
    align?: 'start' | 'center';
  }>(),
  { align: 'center' },
);
</script>

<style scoped>
.tf-vpc-section-header {
  display: flex;
  align-items: center;
  gap: 5px;
  flex-shrink: 0;
}

.tf-vpc-section-header--center {
  justify-content: center;
}

.tf-vpc-section-header--start {
  justify-content: flex-start;
}

.tf-vpc-section-header__icon {
  color: var(--tf-neutral-muted);
  flex-shrink: 0;
}

.tf-vpc-section-header__label {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
  line-height: 1.1;
  white-space: nowrap;
}
</style>
