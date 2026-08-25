<template>
  <q-page class="shop-order-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <div v-if="visibleCards.length" class="row q-col-gutter-sm">
        <div
          v-for="card in visibleCards"
          :key="card.key"
          class="col-12 col-sm-6 col-md-4"
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

      <q-card v-else flat bordered class="floating-surface q-pa-xl column items-center text-center">
        <q-icon name="ph ph-storefront" size="48px" color="grey-5" class="q-mb-md" />
        <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
          {{ $t('shop_admin.shop_order_overview_empty_title') }}
        </div>
        <p class="text-body2 text-grey-7 q-mb-none" style="max-width: 420px">
          {{ $t('shop_admin.shop_order_overview_empty_caption') }}
        </p>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
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
const { t } = useI18n();
const authStore = useAuthStore();
const { getModuleAccess } = useModulePermissions();

const STORE_HUB_MODULE_KEYS: ModuleKey[] = [
  'shop_config',
  'shop_category',
  'shop_pricing',
];

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const hubCards = computed<HubCard[]>(() => [
  {
    key: 'shops',
    moduleKey: 'shop_config',
    path: 'shops',
    title: t('navigation.shops'),
    caption: t('shop_admin.shop_setup_hub_caption'),
    icon: 'ph ph-storefront',
    badgeClass: 'bg-blue-1 text-blue-9',
  },
  {
    key: 'orders',
    moduleKey: 'shop_order_mgmt',
    path: 'orders',
    title: t('navigation.orders'),
    caption: t('shop_admin.shop_orders_subtitle'),
    icon: 'ph ph-receipt',
    badgeClass: 'bg-indigo-1 text-indigo-9',
  },
  {
    key: 'shipping',
    moduleKey: 'shop_shipping',
    path: 'shipping',
    title: t('navigation.shipping'),
    caption: t('shop_admin.shipping_hub_caption'),
    icon: 'ph ph-truck',
    badgeClass: 'bg-orange-1 text-orange-9',
  },
]);

const hasStoreHubAccess = () =>
  STORE_HUB_MODULE_KEYS.some((moduleKey) => getModuleAccess(moduleKey, 'view').allowed);

const visibleCards = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;
  void authStore.tenantId;

  return hubCards.value.filter((card) => {
    if (card.key === 'shops') {
      return hasStoreHubAccess();
    }
    return getModuleAccess(card.moduleKey, 'view').allowed;
  });
});

const goTo = (path: string) => {
  void router.push(`${getTenantPrefix()}/app/shop/${path}`);
};
</script>

<style scoped>
.shop-order-overview-page {
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

body.body--dark .shop-order-overview-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .hub-type-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
