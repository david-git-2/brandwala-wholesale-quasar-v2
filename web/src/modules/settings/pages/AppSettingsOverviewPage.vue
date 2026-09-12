<template>
  <q-page class="settings-overview-page page-fixed-layout q-pa-md">
    <div v-if="hubItems.length" class="overview-shell column no-wrap full-height">
      <app-page-header
        title="Settings"
        subtitle="Access control and reference catalogs for this workspace."
        eyebrow="WORKSPACE"
      />

      <div class="col scroll overview-scroll">
        <hub-link-list :items="hubItems" @select="onSelect" />
      </div>
    </div>

    <div v-else class="column items-center text-center q-pa-xl">
      <q-icon name="ph ph-gear" size="48px" color="grey-5" class="q-mb-md" />
      <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">No settings available</div>
      <p class="text-body2 text-grey-7 q-mb-none" style="max-width: 420px">
        You do not have permission to open any settings for this workspace.
      </p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import HubLinkList, { type HubLinkItem } from 'src/components/ui/HubLinkList.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { filterSettingsHubItems } from 'src/modules/navigation/hubNavConfig';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { getModuleAccess } = useModulePermissions();

const visibleItems = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;

  return filterSettingsHubItems({
    role: authStore.matchedRole,
    isAdmin: authStore.access?.isAdmin,
    canView: (moduleKey) => getModuleAccess(moduleKey, 'view').allowed,
  });
});

const hubItems = computed<HubLinkItem[]>(() =>
  visibleItems.value.map((item) => ({
    key: item.key,
    title: item.title,
    caption: item.caption,
    icon: item.icon,
    dataTest: `settings-hub-node-${item.key}`,
  })),
);

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const onSelect = (item: HubLinkItem) => {
  const settingsItem = visibleItems.value.find((entry) => entry.key === item.key);
  if (!settingsItem) {
    return;
  }
  void router.push(`${getTenantPrefix()}/app/${settingsItem.routeSegment}`);
};
</script>

<style scoped>
.settings-overview-page {
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
