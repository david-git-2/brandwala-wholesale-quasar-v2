<template>
  <q-page class="shop-store-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <div v-if="visibleCards.length" class="row q-col-gutter-sm">
        <div
          v-for="card in visibleCards"
          :key="card.key"
          class="col-12 col-sm-6 col-md-3"
        >
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md full-height"
            @click="goToCard(card)"
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
          {{ $t('shop_admin.shop_store_overview_empty_title') }}
        </div>
        <p class="text-body2 text-grey-7 q-mb-none" style="max-width: 420px">
          {{ $t('shop_admin.shop_store_overview_empty_caption') }}
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
  routeName: string;
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

const hubCards = computed<HubCard[]>(() => [
  {
    key: 'shop-list',
    moduleKey: 'shop_config',
    routeName: 'app-shop-shops-list-page',
    title: t('navigation.shops'),
    caption: t('shop_admin.shop_hub_shops_caption'),
    icon: 'ph ph-storefront',
    badgeClass: 'bg-blue-1 text-blue-9',
  },
  {
    key: 'categories',
    moduleKey: 'shop_category',
    routeName: 'app-shop-categories-page',
    title: t('navigation.categories'),
    caption: t('shop_admin.shop_hub_categories_caption'),
    icon: 'ph ph-squares-four',
    badgeClass: 'bg-teal-1 text-teal-9',
  },
  {
    key: 'customer-groups',
    moduleKey: 'customer',
    routeName: 'app-customers-list',
    title: t('navigation.customer_groups'),
    caption: t('shop_admin.shop_hub_groups_caption'),
    icon: 'ph ph-users-three',
    badgeClass: 'bg-green-1 text-positive',
  },
]);

const visibleCards = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;
  void authStore.tenantId;

  return hubCards.value.filter((card) => getModuleAccess(card.moduleKey, 'view').allowed);
});

const goToCard = (card: HubCard) => {
  void router.push({
    name: card.routeName,
    params: { tenantSlug: authStore.selectedTenant?.slug ?? route.params.tenantSlug },
  });
};
</script>

<style scoped>
.shop-store-overview-page {
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

body.body--dark .shop-store-overview-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .hub-type-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
