<template>
  <q-page class="bw-page reports-overview-page">
    <div class="reports-hub">
      <section
        v-for="group in groups"
        :key="group.title"
        class="report-group"
        :class="{ 'report-group--wide': group.wide }"
      >
        <h2 class="report-group__title">{{ group.title }}</h2>
        <div class="report-group__grid">
          <button
            v-for="card in group.cards"
            :key="card.path"
            type="button"
            class="report-tile"
            :class="`report-tile--${card.tone}`"
            @click="go(card.path)"
          >
            <span class="report-tile__icon" aria-hidden="true">
              <q-icon :name="card.icon" size="28px" />
            </span>
            <span class="report-tile__title">{{ card.title }}</span>
            <span class="report-tile__caption">{{ card.caption }}</span>
          </button>
        </div>
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());

const base = computed(() => `/${tenantSlug.value || 'tenant'}/app/finance/reports`);

const groups = [
  {
    title: 'Cash and dues',
    wide: true,
    cards: [
      {
        path: 'cash-in',
        title: 'Cash in',
        caption: 'What hit the till — cash, bank, remit.',
        icon: 'ph ph-bank',
        tone: 'cash',
      },
      {
        path: 'customer-dues',
        title: 'Customer dues',
        caption: 'Who owes, how old, credit limit.',
        icon: 'ph ph-timer',
        tone: 'dues',
      },
      {
        path: 'wallet',
        title: 'Wallet',
        caption: 'Credit in, applied out, still owed.',
        icon: 'ph ph-wallet',
        tone: 'wallet',
      },
    ],
  },
  {
    title: 'Sales',
    wide: false,
    cards: [
      {
        path: 'invoice-book',
        title: 'Invoice book',
        caption: 'Issued, paid, due, returned.',
        icon: 'ph ph-receipt',
        tone: 'sales',
      },
    ],
  },
  {
    title: 'Profit',
    wide: false,
    cards: [
      {
        path: 'invoice-profit',
        title: 'Invoice profit',
        caption: 'Sell vs cost after returns, by SKU.',
        icon: 'ph ph-chart-line-up',
        tone: 'profit',
      },
      {
        path: 'shipment-profit',
        title: 'Shipment profit',
        caption: 'One batch: landed cost, sold, GP.',
        icon: 'ph ph-package',
        tone: 'batch',
      },
    ],
  },
  {
    title: 'Courier',
    wide: false,
    cards: [
      {
        path: 'courier-cod',
        title: 'Courier COD',
        caption: 'Delivered vs remitted, short or over.',
        icon: 'ph ph-truck',
        tone: 'courier',
      },
    ],
  },
  {
    title: 'Owner snapshot',
    wide: false,
    cards: [
      {
        path: 'month-snapshot',
        title: 'Month snapshot',
        caption: 'Net sales, cash, AR, wallet, stock.',
        icon: 'ph ph-chart-pie',
        tone: 'owner',
      },
    ],
  },
] as const;

function go(path: string) {
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
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: auto minmax(0, 1fr) minmax(0, 1fr);
  gap: 0.75rem 1rem;
  flex: 1;
  min-height: 0;
  width: 100%;
}

.report-group {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.report-group--wide {
  grid-column: 1 / -1;
}

.report-group__title {
  margin: 0 0 0.4rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.report-group__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
  gap: 10px;
  flex: 1;
  min-height: 0;
}

.report-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.4rem;
  height: 100%;
  min-height: 0;
  padding: 0.9rem 1rem;
  text-align: left;
  border: 1px solid var(--bw-theme-border);
  border-radius: 14px;
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
  cursor: pointer;
}

.report-tile:hover {
  border-color: color-mix(in srgb, var(--tile-accent) 50%, var(--bw-theme-border));
  background: color-mix(in srgb, var(--tile-accent) 8%, var(--bw-theme-surface));
}

.report-tile:focus-visible {
  outline: 2px solid var(--bw-theme-primary);
  outline-offset: 2px;
}

.report-tile__icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: color-mix(in srgb, var(--tile-accent) 16%, transparent);
  color: var(--tile-accent);
}

.report-tile__title {
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.report-tile__caption {
  font-size: 0.8rem;
  line-height: 1.35;
  color: var(--bw-theme-muted);
}

.report-tile--cash {
  --tile-accent: var(--q-positive);
}

.report-tile--dues {
  --tile-accent: var(--q-warning);
}

.report-tile--wallet {
  --tile-accent: var(--q-secondary, #5c6bc0);
}

.report-tile--sales {
  --tile-accent: var(--q-info);
}

.report-tile--profit {
  --tile-accent: var(--bw-theme-primary);
}

.report-tile--batch {
  --tile-accent: #b45309;
}

.report-tile--courier {
  --tile-accent: var(--q-orange, #f97316);
}

.report-tile--owner {
  --tile-accent: var(--q-purple, #7c3aed);
}

@media (max-width: 899px) {
  .reports-overview-page {
    height: auto;
    overflow: visible;
  }

  .reports-hub {
    grid-template-columns: 1fr;
    grid-template-rows: none;
  }

  .report-group--wide {
    grid-column: auto;
  }

  .report-tile {
    min-height: 128px;
  }
}
</style>
