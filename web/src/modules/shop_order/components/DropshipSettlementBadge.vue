<template>
  <span
    class="settlement-badge"
    :class="`settlement-${normalizedStatus}`"
  >
    <q-icon :name="badgeIcon" class="q-mr-xs" size="12px" />
    <span>{{ badgeLabel }}</span>
  </span>
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
      return 'Settled (Paid)';
    case 'partial':
      return 'Partial Settlement';
    case 'unpaid':
    default:
      return 'Unpaid Settlement';
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
      return 'ph ph-circle-dashed';
  }
});
</script>

<style scoped>
.settlement-badge {
  display: inline-flex;
  align-items: center;
  border-radius: 6px;
  font-weight: 700;
  letter-spacing: 0.02em;
  font-size: 11px;
  padding: 3px 8px;
  line-height: 1.2;
  white-space: nowrap;
}

.settlement-paid {
  background: #ecfdf5;
  color: #047857;
  border: 1px solid #a7f3d0;
}

.settlement-partial {
  background: #fffbeb;
  color: #b45309;
  border: 1px solid #fde68a;
}

.settlement-unpaid {
  background: #f8fafc;
  color: #475569;
  border: 1px solid #cbd5e1;
}

body.body--dark .settlement-paid {
  background: rgba(16, 185, 129, 0.14);
  color: #6ee7b7;
  border-color: rgba(16, 185, 129, 0.3);
}

body.body--dark .settlement-partial {
  background: rgba(245, 158, 11, 0.14);
  color: #fcd34d;
  border-color: rgba(245, 158, 11, 0.3);
}

body.body--dark .settlement-unpaid {
  background: rgba(148, 163, 184, 0.12);
  color: #cbd5e1;
  border-color: rgba(148, 163, 184, 0.25);
}
</style>
