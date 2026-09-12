<template>
  <q-page class="shop-order-overview-page page-fixed-layout">
    <div v-if="hubCards.length" class="overview-shell column no-wrap full-height">
      <header class="overview-header flex-shrink-0">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          {{ $t('shop_admin.shop_and_order') }}
        </div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-none">
          {{ $t('shop_admin.shop_setup_hub_caption') }}
        </p>
      </header>

      <div class="col scroll overview-scroll">
        <div class="shop-hub-tree" data-test="shop-hub-tree">
            <section
              v-for="card in hubCards"
              :key="card.key"
              class="shop-hub-group"
              :data-test="`shop-hub-node-${card.key}`"
            >
              <div class="shop-hub-group__header">
                <button
                  type="button"
                  class="shop-hub-toggle"
                  :aria-expanded="isExpanded(card.key)"
                  :aria-label="isExpanded(card.key) ? $t('shop_admin.collapse') : $t('shop_admin.expand')"
                  @click="toggleGroup(card.key)"
                >
                  <q-icon
                    :name="isExpanded(card.key) ? 'ph ph-caret-down' : 'ph ph-caret-right'"
                    size="14px"
                  />
                </button>

                <div class="shop-hub-icon-badge shop-hub-icon-badge--parent">
                  <q-icon :name="card.icon" size="16px" />
                </div>

                <button
                  type="button"
                  class="shop-hub-group__title-btn"
                  @click="toggleGroup(card.key)"
                >
                  <span class="shop-hub-group__title">{{ $t(card.titleKey) }}</span>
                  <span class="shop-hub-group__caption">{{ $t(card.descriptionKey) }}</span>
                </button>
              </div>

              <div v-show="isExpanded(card.key)" class="shop-hub-children">
                <div
                  v-for="link in card.links"
                  :key="link.key"
                  class="shop-hub-row group"
                  :class="{ 'shop-hub-row--active': isLinkActive(link) }"
                  :data-test="`shop-hub-node-${link.key}`"
                  role="button"
                  tabindex="0"
                  @click="navigateToLink(link)"
                  @keydown.enter.prevent="navigateToLink(link)"
                  @keydown.space.prevent="navigateToLink(link)"
                >
                  <div class="shop-hub-icon-badge">
                    <q-icon :name="link.icon" size="15px" />
                  </div>

                  <div class="shop-hub-row__content min-width-0">
                    <div class="shop-hub-row__label">{{ $t(link.labelKey) }}</div>
                    <div class="shop-hub-row__caption">{{ $t(link.captionKey) }}</div>
                  </div>

                  <q-icon
                    name="ph ph-caret-right"
                    size="16px"
                    class="shop-hub-row__chevron"
                    aria-hidden="true"
                  />
                </div>
              </div>
            </section>
        </div>
      </div>
    </div>

    <div v-else class="column items-center text-center q-pa-xl">
      <q-icon name="ph ph-storefront" size="48px" color="grey-5" class="q-mb-md" />
      <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
        {{ $t('shop_admin.shop_order_overview_empty_title') }}
      </div>
      <p class="text-body2 text-grey-7 q-mb-none" style="max-width: 420px">
        {{ $t('shop_admin.shop_order_overview_empty_caption') }}
      </p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  SHOP_ORDER_HUB_CARDS,
  filterHubCards,
  type ShopHubCardLinkDef,
} from '../config/shopOrderHubTree';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { getModuleAccess } = useModulePermissions();

const expandedKeys = ref<string[]>([]);

const hubCards = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;
  void authStore.tenantId;

  return filterHubCards(SHOP_ORDER_HUB_CARDS, (moduleKey) =>
    getModuleAccess(moduleKey, 'view').allowed,
  );
});

watch(
  hubCards,
  (cards) => {
    expandedKeys.value = cards.map((card) => card.key);
  },
  { immediate: true },
);

const tenantSlug = computed(
  () => authStore.selectedTenant?.slug ?? (route.params.tenantSlug as string | undefined) ?? '',
);

const isExpanded = (key: string) => expandedKeys.value.includes(key);

const toggleGroup = (key: string) => {
  if (isExpanded(key)) {
    expandedKeys.value = expandedKeys.value.filter((item) => item !== key);
    return;
  }
  expandedKeys.value = [...expandedKeys.value, key];
};

const isLinkActive = (link: ShopHubCardLinkDef) => {
  if (route.name !== link.routeName) {
    return false;
  }

  if (!link.routeQuery) {
    return true;
  }

  return Object.entries(link.routeQuery).every(
    ([key, value]) => String(route.query[key] ?? '') === value,
  );
};

const navigateToLink = (link: ShopHubCardLinkDef) => {
  void router.push({
    name: link.routeName,
    params: { tenantSlug: tenantSlug.value },
    query: link.routeQuery ?? undefined,
  });
};
</script>

<style scoped>
.shop-order-overview-page {
  height: calc(100vh - 55px);
  overflow: hidden;
  padding: 16px;
}

.overview-shell {
  max-width: 720px;
  margin: 0 auto;
  height: 100%;
}

.overview-scroll {
  padding-top: 12px;
  min-height: 0;
}

.shop-hub-group + .shop-hub-group {
  margin-top: 6px;
}

.shop-hub-group__header {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 4px 2px;
}

.shop-hub-toggle {
  width: 24px;
  height: 24px;
  margin-top: 2px;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: #64748b;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.shop-hub-toggle:hover {
  background: rgb(241 245 249 / 0.9);
  color: #334155;
}

.shop-hub-group__title-btn {
  border: none;
  background: transparent;
  padding: 2px 4px;
  text-align: left;
  cursor: pointer;
  min-width: 0;
  flex: 1;
}

.shop-hub-group__title {
  display: block;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.35;
  color: #0f172a;
}

.shop-hub-group__caption {
  display: block;
  margin-top: 2px;
  font-size: 12px;
  line-height: 1.4;
  color: #64748b;
}

.shop-hub-children {
  position: relative;
  margin: 4px 0 2px 11px;
  padding-left: 18px;
  border-left: 1px solid #e2e8f0;
}

.shop-hub-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 52px;
  padding: 8px 10px;
  margin: 2px 0;
  border-radius: 10px;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.shop-hub-row:hover {
  background: rgb(241 245 249 / 0.7);
}

.shop-hub-row--active {
  background: #eff6ff;
  color: #2563eb;
}

.shop-hub-row--active .shop-hub-row__label {
  color: #1d4ed8;
  font-weight: 600;
}

.shop-hub-row--active .shop-hub-row__caption {
  color: #3b82f6;
}

.shop-hub-row--active .shop-hub-icon-badge {
  background: #dbeafe;
  color: #2563eb;
}

.shop-hub-icon-badge {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: #f1f5f9;
  color: #475569;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.shop-hub-icon-badge--parent {
  margin-top: 1px;
}

.shop-hub-row__content {
  flex: 1;
  min-width: 0;
}

.shop-hub-row__label {
  font-size: 14px;
  font-weight: 500;
  line-height: 1.35;
  color: #0f172a;
}

.shop-hub-row__caption {
  margin-top: 2px;
  font-size: 12px;
  line-height: 1.35;
  color: #64748b;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.shop-hub-row__chevron {
  color: #94a3b8;
  opacity: 0;
  flex-shrink: 0;
  transition: opacity 0.15s ease;
}

.shop-hub-row:hover .shop-hub-row__chevron,
.shop-hub-row--active .shop-hub-row__chevron,
.shop-hub-row:focus-visible .shop-hub-row__chevron {
  opacity: 1;
}

.shop-hub-row:focus-visible {
  outline: 2px solid #93c5fd;
  outline-offset: 1px;
}

body.body--dark .shop-hub-group__title {
  color: #f8fafc;
}

body.body--dark .shop-hub-group__caption,
body.body--dark .shop-hub-row__caption {
  color: #94a3b8;
}

body.body--dark .shop-hub-row__label {
  color: #f1f5f9;
}

body.body--dark .shop-hub-children {
  border-left-color: rgb(255 255 255 / 0.1);
}

body.body--dark .shop-hub-toggle:hover,
body.body--dark .shop-hub-row:hover {
  background: rgb(255 255 255 / 0.05);
}

body.body--dark .shop-hub-icon-badge {
  background: rgb(255 255 255 / 0.08);
  color: #cbd5e1;
}

body.body--dark .shop-hub-row--active {
  background: rgb(37 99 235 / 0.16);
}

body.body--dark .shop-hub-row--active .shop-hub-row__label {
  color: #93c5fd;
}

body.body--dark .shop-hub-row--active .shop-hub-icon-badge {
  background: rgb(37 99 235 / 0.24);
  color: #93c5fd;
}
</style>
