<template>
  <q-badge
    :color="badgeColor"
    text-color="white"
    class="settlement-badge text-weight-bold q-py-xs q-px-sm"
  >
    <q-icon :name="badgeIcon" class="q-mr-xs" size="14px" />
    {{ badgeLabel }}
  </q-badge>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    status?: string | null;
  }>(),
  {
    status: 'unpaid',
  },
);

const normalizedStatus = computed(() => (props.status || 'unpaid').toLowerCase());

const badgeLabel = computed(() => {
  switch (normalizedStatus.value) {
    case 'paid':
      return 'SETTLED (PAID)';
    case 'partial':
      return 'PARTIAL SETTLEMENT';
    case 'unpaid':
    default:
      return 'UNPAID SETTLEMENT';
  }
});

const badgeColor = computed(() => {
  switch (normalizedStatus.value) {
    case 'paid':
      return 'green-8';
    case 'partial':
      return 'amber-9';
    case 'unpaid':
    default:
      return 'grey-7';
  }
});

const badgeIcon = computed(() => {
  switch (normalizedStatus.value) {
    case 'paid':
      return 'ph ph-check-circle';
    case 'partial':
      return 'ph ph-clock';
    case 'unpaid':
    default:
      return 'ph ph-circle';
  }
});
</script>

<style scoped>
.settlement-badge {
  border-radius: 8px;
  letter-spacing: 0.5px;
  font-size: 11px;
}
</style>
