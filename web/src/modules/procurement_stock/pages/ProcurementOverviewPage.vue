<template>
  <q-page class="procurement-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <div class="row q-col-gutter-sm">
        <div
          v-for="card in visibleCards"
          :key="card.key"
          class="col-12 col-sm-6 col-md-3"
        >
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md full-height"
            @click="goTo(card.path)"
          >
            <div class="row items-center q-mb-sm">
              <div class="hub-icon-badge" :class="card.badgeClass">
                <q-icon :name="card.icon" size="24px" />
              </div>
            </div>

            <div class="text-subtitle1 text-weight-bolder text-grey-9">{{ card.title }}</div>
            <p class="text-caption text-grey-7 text-xs q-mt-xs q-mb-none">
              {{ card.caption }}
            </p>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useModulePermissions, type ModuleKey } from 'src/modules/navigation/modulePermissions';

type HubCard = {
  key: string;
  moduleKey: ModuleKey;
  path: string;
  title: string;
  caption: string;
  icon: string;
  badgeClass: string;
};

const router = useRouter();
const route = useRoute();
const { hasModuleAccess } = useModulePermissions();

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const hubCards: HubCard[] = [
  {
    key: 'demand',
    moduleKey: 'procurement_demand',
    path: 'demand',
    title: 'Demand',
    caption: 'Items to source from shop orders and costing files.',
    icon: 'ph ph-list-checks',
    badgeClass: 'bg-teal-1 text-teal-9',
  },
  {
    key: 'shipment',
    moduleKey: 'global_shipment',
    path: 'shipment/list',
    title: 'Shipments',
    caption: 'Inbound goods from vendors — add items and receive stock.',
    icon: 'ph ph-truck',
    badgeClass: 'bg-blue-1 text-blue-9',
  },
  {
    key: 'warehouse',
    moduleKey: 'global_stock',
    path: 'stock',
    title: 'Warehouse',
    caption: 'What is on the shelves and whether it can be sold.',
    icon: 'ph ph-warehouse',
    badgeClass: 'bg-purple-1 text-purple-9',
  },
  {
    key: 'movements',
    moduleKey: 'global_stock_movement',
    path: 'movements',
    title: 'Movements',
    caption: 'Move stock between shelves or sellable / held states.',
    icon: 'ph ph-arrows-left-right',
    badgeClass: 'bg-indigo-1 text-indigo-9',
  },
  {
    key: 'locations',
    moduleKey: 'global_stock_location',
    path: 'locations',
    title: 'Locations',
    caption: 'Shelves and boxes where warehouse stock sits.',
    icon: 'ph ph-map-pin',
    badgeClass: 'bg-cyan-1 text-cyan-9',
  },
  {
    key: 'cargo',
    moduleKey: 'cargo_company',
    path: 'cargo-companies',
    title: 'Cargo Companies',
    caption: 'Freight agents used on inbound shipments.',
    icon: 'ph ph-airplane-tilt',
    badgeClass: 'bg-orange-1 text-orange-9',
  },
  {
    key: 'progress',
    moduleKey: 'shipment_progress_settings',
    path: 'shipment-progress',
    title: 'Shipment Progress',
    caption: 'Journey stages for shipments and public tracking.',
    icon: 'ph ph-map-trifold',
    badgeClass: 'bg-grey-2 text-grey-9',
  },
  {
    key: 'child-stock',
    moduleKey: 'inventory',
    path: 'child-stock',
    title: 'Shop Stock',
    caption: 'Stock this shop can sell from received shipments.',
    icon: 'ph ph-package',
    badgeClass: 'bg-green-1 text-positive',
  },
];

const visibleCards = computed(() =>
  hubCards.filter((card) => hasModuleAccess(card.moduleKey, 'view')),
);

const goTo = (path: string) => {
  void router.push(`${getTenantPrefix()}/app/procurement/${path}`);
};
</script>

<style scoped>
.procurement-overview-page {
  background: var(--bw-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  overflow: hidden;
}

.overview-container {
  height: 100%;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 4px 12px -2px rgba(51, 65, 85, 0.05);
}

.hub-type-card {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.9);
  transition: all 0.2s ease-in-out;
}

.hub-type-card:hover {
  transform: translateY(-3px);
  border-color: rgba(59, 130, 246, 0.45);
  box-shadow:
    0 16px 32px -6px rgba(51, 65, 85, 0.12),
    0 8px 16px -4px rgba(51, 65, 85, 0.06);
}

.hub-icon-badge {
  width: 44px;
  height: 44px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}

body.body--dark .procurement-overview-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .hub-type-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
