<template>
  <q-page class="procurement-overview-page page-fixed-layout q-pa-md">
    <div v-if="hubItems.length" class="overview-shell column no-wrap full-height">
      <app-page-header
        title="More — warehouse operations"
        subtitle="Batch codes, movements, locations, cargo companies, and shop stock."
        eyebrow="PROCUREMENT & STOCK"
      />

      <div class="col scroll overview-scroll">
        <hub-link-list :items="hubItems" @select="onSelect" />
      </div>
    </div>

    <div v-else class="column items-center text-center q-pa-xl">
      <q-icon name="ph ph-truck" size="48px" color="grey-5" class="q-mb-md" />
      <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">No additional tools</div>
      <p class="text-body2 text-grey-7 q-mb-none" style="max-width: 420px">
        Use Demand, Shipments, and Warehouse from the sidebar for daily procurement work.
      </p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import HubLinkList, { type HubLinkItem } from 'src/components/ui/HubLinkList.vue';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  PROCUREMENT_MORE_LINKS,
  filterProcurementMoreLinks,
} from '../config/procurementHubConfig';

const router = useRouter();
const route = useRoute();
const { hasModuleAccess } = useModulePermissions();

const moreLinks = computed(() =>
  filterProcurementMoreLinks(PROCUREMENT_MORE_LINKS, (moduleKey) =>
    hasModuleAccess(moduleKey, 'view'),
  ),
);

const hubItems = computed<HubLinkItem[]>(() =>
  moreLinks.value.map((link) => ({
    key: link.key,
    title: link.title,
    caption: link.caption,
    icon: link.icon,
    dataTest: `procurement-hub-node-${link.key}`,
  })),
);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const onSelect = (item: HubLinkItem) => {
  const link = moreLinks.value.find((entry) => entry.key === item.key);
  if (!link) {
    return;
  }
  void router.push(`${getTenantPrefix()}/app/procurement/${link.path}`);
};
</script>

<style scoped>
.procurement-overview-page {
  background: var(--bw-brand-base, #eef0f4);
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

body.body--dark .procurement-overview-page {
  background: #171717;
}
</style>
