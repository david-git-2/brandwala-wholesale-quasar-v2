<template>
  <q-page class="bw-page after-sales-overview-page">
    <section class="bw-page__stack">
      <AfterSalesOverviewSkeleton v-if="hubQuery.isLoading.value" />

      <template v-else>
        <AfterSalesHubSummaryChart
          :kpis="hubQuery.data.value ?? emptyKpis"
          @navigate="goTo"
        />

        <div class="bw-inline-actions">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus-circle"
            label="New wholesale case"
            style="border-radius: 8px"
            @click="wholesaleDialogOpen = true"
          />
          <q-btn
            outline
            color="primary"
            no-caps
            icon="ph ph-chat-circle-dots"
            label="Log dropship complaint"
            style="border-radius: 8px"
            @click="goTo('after-sales/dropship/intake')"
          />
          <q-btn
            flat
            color="warning"
            no-caps
            icon="ph ph-hourglass"
            label="Pending my approval"
            @click="goTo('after-sales/cases?status=pending_approval')"
          />
        </div>

        <div class="after-sales-hub">
          <section class="hub-group">
            <h2 class="hub-group__title">Queues</h2>
            <div class="bw-entity-grid">
              <button
                v-for="card in queueCards"
                :key="card.key"
                type="button"
                class="hub-tile"
                :class="`hub-tile--${card.tone}`"
                @click="goTo(card.path)"
              >
                <span class="hub-tile__icon" aria-hidden="true">
                  <q-icon :name="card.icon" size="26px" />
                </span>
                <span class="hub-tile__title">{{ card.title }}</span>
                <span class="hub-tile__caption">{{ card.caption }}</span>
              </button>
            </div>
          </section>

          <section class="hub-group">
            <h2 class="hub-group__title">Intake &amp; policy</h2>
            <div class="bw-entity-grid">
              <button
                v-for="card in intakePolicyCards"
                :key="card.key"
                type="button"
                class="hub-tile"
                :class="`hub-tile--${card.tone}`"
                @click="goTo(card.path)"
              >
                <span class="hub-tile__icon" aria-hidden="true">
                  <q-icon :name="card.icon" size="26px" />
                </span>
                <span class="hub-tile__title">{{ card.title }}</span>
                <span class="hub-tile__caption">{{ card.caption }}</span>
              </button>
            </div>
          </section>
        </div>
      </template>
    </section>

    <OpenWholesaleReturnCaseDialog v-model="wholesaleDialogOpen" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import AfterSalesHubSummaryChart from '../components/AfterSalesHubSummaryChart.vue';
import AfterSalesOverviewSkeleton from '../components/AfterSalesOverviewSkeleton.vue';
import OpenWholesaleReturnCaseDialog from '../components/OpenWholesaleReturnCaseDialog.vue';
import { useAfterSalesHubQuery } from '../composables/useAfterSalesHubQuery';
import type { AfterSalesHubSummary } from '../types/afterSales.types';

type HubTile = {
  key: string;
  path: string;
  title: string;
  caption: string;
  icon: string;
  tone: string;
  audience?: 'parent' | 'child';
};

const router = useRouter();
const route = useRoute();
const tenantStore = useTenantStore();
const { isParentTenant: isParentWorkspace } = useInvoiceWorkspace();

const wholesaleDialogOpen = ref(false);
const tenantId = computed(() => tenantStore.selectedTenant?.id ?? null);

const hubQuery = useAfterSalesHubQuery(tenantId);

const emptyKpis: AfterSalesHubSummary = {
  open_cases: 0,
  pending_approval: 0,
  awaiting_receipt: 0,
  wholesale_count: 0,
  dropship_count: 0,
  closed_this_month: 0,
};

const queueCards: HubTile[] = [
  {
    key: 'all',
    path: 'after-sales/cases',
    title: 'All cases',
    caption: 'Unified inbox — filter by status, channel, and tenant.',
    icon: 'ph ph-tray',
    tone: 'inbox',
  },
];

const intakePolicyCards = computed(() => {
  const cards: HubTile[] = [
    {
      key: 'intake',
      path: 'after-sales/dropship/intake',
      title: 'Log dropship complaint',
      caption: 'Phone, WhatsApp, in person, email.',
      icon: 'ph ph-chat-teardrop-text',
      tone: 'intake',
    },
  ];

  if (isParentWorkspace.value) {
    cards.push({
      key: 'policy',
      path: 'after-sales/policy',
      title: 'Return policies',
      caption: 'Create and manage named policies by program type.',
      icon: 'ph ph-sliders',
      tone: 'policy',
      audience: 'parent',
    });
  } else {
    cards.push({
      key: 'policy-readonly',
      path: 'after-sales/policy',
      title: 'View parent policies',
      caption: 'Read-only list — managed by parent company.',
      icon: 'ph ph-eye',
      tone: 'policy',
      audience: 'child',
    });
  }

  return cards;
});

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goTo = (path: string) => {
  void router.push(`${getTenantPrefix()}/app/${path}`);
};
</script>

<style scoped>
.after-sales-overview-page {
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - 55px);
}

.after-sales-hub {
  display: grid;
  gap: 1rem;
  min-width: 0;
}

.hub-group {
  min-width: 0;
}

.hub-group__title {
  margin: 0 0 0.45rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.hub-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.45rem;
  min-height: 128px;
  padding: 0.95rem 1rem;
  text-align: left;
  border: 1px solid var(--bw-theme-border);
  border-radius: 14px;
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
  cursor: pointer;
  transition:
    border-color 0.2s ease,
    background 0.2s ease,
    transform 0.2s ease,
    box-shadow 0.2s ease;
}

.hub-tile:hover {
  border-color: color-mix(in srgb, var(--tile-accent) 50%, var(--bw-theme-border));
  background: color-mix(in srgb, var(--tile-accent) 8%, var(--bw-theme-surface));
  transform: translateY(-2px);
  box-shadow: 0 8px 20px -8px color-mix(in srgb, var(--tile-accent) 35%, transparent);
}

.hub-tile:focus-visible {
  outline: 2px solid var(--bw-theme-primary);
  outline-offset: 2px;
}

.hub-tile__icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: color-mix(in srgb, var(--tile-accent) 16%, transparent);
  color: var(--tile-accent);
}

.hub-tile__title {
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.hub-tile__caption {
  font-size: 0.8rem;
  line-height: 1.35;
  color: var(--bw-theme-muted);
}

.hub-tile--inbox {
  --tile-accent: var(--q-info);
}

.hub-tile--wholesale {
  --tile-accent: var(--q-purple, #7c3aed);
}

.hub-tile--dropship {
  --tile-accent: var(--q-teal, #0d9488);
}

.hub-tile--intake {
  --tile-accent: var(--q-orange, #f97316);
}

.hub-tile--policy {
  --tile-accent: var(--bw-theme-primary);
}
</style>
