<template>
  <q-page class="bw-page theme-app">
    <div class="bw-page__stack">
      <AppPageHeader title="Home" subtitle="What needs work today" />

      <DashboardAttentionList :items="attentionItems" />

      <div
        v-if="isEmpty"
        class="column items-center justify-center q-pa-xl text-center empty-state-block floating-surface"
      >
        <q-icon name="ph ph-squares-four" size="56px" color="grey-4" class="q-mb-sm" />
        <div class="text-subtitle1 text-weight-bold">No dashboard widgets yet</div>
        <p class="text-body2 text-grey-6 q-mb-none">
          Turn on modules and permissions to see your workspace pulse here.
        </p>
      </div>

      <template v-else>
        <div v-if="actionSlots.length" class="dashboard-actions">
          <DashboardSlotHost
            v-for="slot in actionSlots"
            :key="slot.id"
            :item="slot"
            v-bind="tenantSlug ? { tenantSlug } : {}"
          />
        </div>

        <div class="dashboard-board">
          <DashboardSlotHost
            v-for="slot in stories"
            :key="slot.id"
            :item="slot"
            v-bind="tenantSlug ? { tenantSlug } : {}"
          />
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import DashboardAttentionList from '../components/DashboardAttentionList.vue';
import DashboardSlotHost from '../components/DashboardSlotHost.vue';
import { useDashboardAttention } from '../composables/useDashboardAttention';
import { useDashboardSlots } from '../composables/useDashboardSlots';

const { actionSlots, stories, isEmpty, tenantSlug } = useDashboardSlots();
const { items: attentionItems } = useDashboardAttention();
</script>

<style scoped>
.dashboard-actions {
  width: 100%;
}

.dashboard-board {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 28rem), 1fr));
  gap: 2.5rem 3rem;
}
</style>
