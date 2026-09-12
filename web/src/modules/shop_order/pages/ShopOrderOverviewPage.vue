<template>
  <q-page class="shop-order-overview-page page-fixed-layout q-pa-md">
    <div v-if="hubItems.length" class="overview-shell column no-wrap full-height">
      <app-page-header
        title="More — shop setup and shipping"
        subtitle="Categories, pricing, couriers, and remittance tools."
        eyebrow="SHOP & ORDER"
      />

      <div class="col scroll overview-scroll">
        <hub-link-list :items="hubItems" @select="onSelect" />
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
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import HubLinkList, { type HubLinkItem } from 'src/components/ui/HubLinkList.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  SHOP_ORDER_MORE_LINKS,
  filterMoreHubLinks,
  type ShopHubCardLinkDef,
} from '../config/shopOrderHubTree';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const authStore = useAuthStore();
const { getModuleAccess } = useModulePermissions();

const moreLinks = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;
  void authStore.tenantId;

  return filterMoreHubLinks(SHOP_ORDER_MORE_LINKS, (moduleKey) =>
    getModuleAccess(moduleKey, 'view').allowed,
  );
});

const hubItems = computed<HubLinkItem[]>(() =>
  moreLinks.value.map((link) => ({
    key: link.key,
    title: t(link.labelKey),
    caption: t(link.captionKey),
    icon: link.icon,
    dataTest: `shop-hub-node-${link.key}`,
  })),
);

const tenantSlug = computed(
  () => authStore.selectedTenant?.slug ?? (route.params.tenantSlug as string | undefined) ?? '',
);

const navigateToLink = (link: ShopHubCardLinkDef) => {
  void router.push({
    name: link.routeName,
    params: { tenantSlug: tenantSlug.value },
    query: link.routeQuery ?? undefined,
  });
};

const onSelect = (item: HubLinkItem) => {
  const link = moreLinks.value.find((entry) => entry.key === item.key);
  if (link) {
    navigateToLink(link);
  }
};
</script>

<style scoped>
.shop-order-overview-page {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.overview-shell {
  max-width: 720px;
  margin: 0 auto;
  height: 100%;
}

.overview-scroll {
  padding-top: 0.5rem;
  min-height: 0;
}
</style>
