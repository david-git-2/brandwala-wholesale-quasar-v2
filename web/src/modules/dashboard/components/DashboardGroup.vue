<template>
  <section class="dashboard-group">
    <div class="dashboard-group__head">
      <div class="text-overline text-primary">{{ title }}</div>
    </div>

    <div v-if="blockSlots.length" class="dashboard-group__blocks">
      <DashboardSlotHost
        v-for="slot in blockSlots"
        :key="slot.id"
        :item="slot"
        :tenant-slug="tenantSlug"
      />
    </div>

    <div v-if="tileSlots.length" class="dashboard-group__stack">
      <DashboardSlotHost
        v-for="slot in tileSlots"
        :key="slot.id"
        :item="slot"
        :tenant-slug="tenantSlug"
      />
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import type { DashboardSlot } from '../types/dashboardSlot';
import { isDashboardBlockKind, isDashboardTileKind } from '../types/dashboardSlot';
import DashboardSlotHost from './DashboardSlotHost.vue';

const props = defineProps<{
  title: string;
  icon: string;
  slots: DashboardSlot[];
  tenantSlug?: string;
}>();

const blockSlots = computed(() => props.slots.filter((s) => isDashboardBlockKind(s.kind)));
const tileSlots = computed(() => props.slots.filter((s) => isDashboardTileKind(s.kind)));
</script>

<style scoped>
.dashboard-group {
  display: grid;
  gap: 0.85rem;
}

.dashboard-group__head {
  margin-bottom: 0.15rem;
}

.dashboard-group__blocks {
  display: grid;
  gap: 0.85rem;
}

.dashboard-group__stack {
  display: grid;
  gap: 0.65rem;
}
</style>
