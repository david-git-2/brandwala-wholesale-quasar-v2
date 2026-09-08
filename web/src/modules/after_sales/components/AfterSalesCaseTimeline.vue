<template>
  <q-timeline color="primary" layout="dense">
    <q-timeline-entry
      v-for="event in events"
      :key="event.id"
      :title="event.label"
      :subtitle="formatWhen(event.occurred_at)"
      :icon="iconFor(event.event_type)"
    >
      <div v-if="event.actor_name" class="text-caption text-grey-7">By {{ event.actor_name }}</div>
    </q-timeline-entry>
  </q-timeline>
</template>

<script setup lang="ts">
import type { AfterSalesCaseEvent } from '../types/afterSales.types';

defineProps<{
  events: AfterSalesCaseEvent[];
}>();

const formatWhen = (iso: string) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
};

const iconFor = (type: string) => {
  if (type.includes('reject')) return 'ph ph-x-circle';
  if (type.includes('approv')) return 'ph ph-check-circle';
  if (type.includes('closed')) return 'ph ph-lock';
  if (type.includes('received')) return 'ph ph-package';
  return 'ph ph-clock';
};
</script>
