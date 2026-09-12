<template>
  <q-page class="bw-page theme-app">
    <div class="bw-page__stack">
      <AppPageHeader title="Home" subtitle="What needs work today" />

      <DashboardAttentionList v-if="attentionItems.length" :items="attentionItems" />

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

      <DashboardGroup
        v-for="group in groups"
        v-else
        :key="group.parentGroupKey"
        :title="group.title"
        :icon="group.icon"
        :slots="group.slots"
        v-bind="tenantSlug ? { tenantSlug } : {}"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import DashboardAttentionList from '../components/DashboardAttentionList.vue';
import DashboardGroup from '../components/DashboardGroup.vue';
import { useDashboardAttention } from '../composables/useDashboardAttention';
import { useDashboardSlots } from '../composables/useDashboardSlots';

const { groups, isEmpty, tenantSlug } = useDashboardSlots();
const { items: attentionItems } = useDashboardAttention();
</script>
