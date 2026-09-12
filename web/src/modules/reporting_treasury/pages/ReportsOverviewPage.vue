<template>
  <q-page class="bw-page reports-overview-page q-pa-md">
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
      {
        key: 'wallet',
        title: 'Wallet',
        caption: 'Credit in, applied out, still owed.',
        icon: 'ph ph-wallet',
        iconTone: 'neutral',
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
    key: 'profit',
    title: 'Profit',
    items: [
      {
        key: 'invoice-profit',
        title: 'Invoice profit',
        caption: 'Sell vs cost after returns, by SKU.',
        icon: 'ph ph-chart-line-up',
        iconTone: 'primary',
      },
      {
        key: 'shipment-profit',
        title: 'Shipment profit',
        caption: 'One batch: landed cost, sold, GP.',
        icon: 'ph ph-package',
        iconTone: 'buy',
      },
    ],
  },
  {
    key: 'courier',
    title: 'Courier',
    items: [
      {
        key: 'courier-cod',
        title: 'Courier COD',
        caption: 'Delivered vs remitted, short or over.',
        icon: 'ph ph-truck',
        iconTone: 'cod',
      },
    ],
  },
  {
    key: 'owner-snapshot',
    title: 'Owner snapshot',
    items: [
      {
        key: 'month-snapshot',
        title: 'Month snapshot',
        caption: 'Net sales, cash, AR, wallet, stock.',
        icon: 'ph ph-chart-pie',
        iconTone: 'neutral',
      },
    ],
  },
];

const pathByKey: Record<string, string> = {
  'customer-dues': 'customer-dues',
  'cash-in': 'cash-in',
  wallet: 'wallet',
  'invoice-book': 'invoice-book',
  'invoice-profit': 'invoice-profit',
  'shipment-profit': 'shipment-profit',
  'courier-cod': 'courier-cod',
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
  overflow: hidden;
}

.reports-hub {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  flex: 1;
  min-height: 0;
  max-width: 720px;
  margin: 0 auto;
  width: 100%;
  overflow-y: auto;
}

@media (max-width: 899px) {
  .reports-overview-page {
    height: auto;
    overflow: visible;
  }
}
</style>
