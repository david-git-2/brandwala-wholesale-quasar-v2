<template>
  <q-page class="tf-page reports-overview-page q-pa-md">
    <div class="reports-hub">
      <app-page-header
        title="Reports"
        subtitle="Cash, dues, sales, and profit."
        eyebrow="FINANCE"
      />

      <hub-link-list :groups="reportGroups" @select="onSelect" />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import HubLinkList, { type HubLinkGroup, type HubLinkItem } from 'src/components/ui/HubLinkList.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());

const base = computed(() => `/${tenantSlug.value || 'tenant'}/app/finance/reports`);

const reportGroups: HubLinkGroup[] = [
  {
    key: 'shipments',
    title: 'Shipments',
    items: [
      {
        key: 'shipment-report',
        title: 'Shipment report',
        caption: 'All batches — open one for details.',
        icon: 'ph ph-package',
        iconTone: 'buy',
      },
    ],
  },
  {
    key: 'cash-and-dues',
    title: 'Cash and dues',
    items: [
      {
        key: 'customer-dues',
        title: 'Customer dues',
        caption: 'Who owes, how old, credit limit.',
        icon: 'ph ph-timer',
        iconTone: 'cod',
      },
      {
        key: 'cash-in',
        title: 'Cash in',
        caption: 'What hit the till — cash, bank, remit.',
        icon: 'ph ph-bank',
        iconTone: 'primary',
      },
    ],
  },
  {
    key: 'sales',
    title: 'Sales',
    items: [
      {
        key: 'invoice-book',
        title: 'Invoice book',
        caption: 'Issued, paid, due, returned.',
        icon: 'ph ph-receipt',
        iconTone: 'primary',
      },
    ],
  },
  {
    key: 'owner-snapshot',
    title: 'Owner snapshot',
    items: [
      {
        key: 'month-snapshot',
        title: 'Money position',
        caption: 'What we have, owe, and will get — plus this month.',
        icon: 'ph ph-chart-pie',
        iconTone: 'neutral',
      },
    ],
  },
];

const pathByKey: Record<string, string> = {
  'customer-dues': 'customer-dues',
  'cash-in': 'cash-in',
  'invoice-book': 'invoice-book',
  'shipment-report': 'shipment-report',
  'month-snapshot': 'month-snapshot',
};

function onSelect(item: HubLinkItem) {
  const path = pathByKey[item.key];
  if (!path) {
    return;
  }
  void router.push(`${base.value}/${path}`);
}
</script>

<style scoped>
.reports-overview-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 55px);
  overflow-y: auto;
  scrollbar-gutter: stable;
}

.reports-hub {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  flex: 0 0 auto;
  max-width: 720px;
  margin: 0 auto;
  width: 100%;
}

@media (max-width: 899px) {
  .reports-overview-page {
    height: auto;
    overflow: visible;
  }
}
</style>
