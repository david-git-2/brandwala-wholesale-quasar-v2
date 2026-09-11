<template>
  <q-page class="shop-order-overview-page page-fixed-layout q-pa-md">
    <div v-if="treeNodes.length" class="overview-container column no-wrap full-height">
      <div class="q-pb-sm flex-shrink-0">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          {{ $t('shop_admin.shop_and_order') }}
        </div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-none">
          {{ $t('shop_admin.shop_setup_hub_caption') }}
        </p>
      </div>

      <div class="col scroll q-pt-sm">
        <q-tree
          v-model:expanded="expandedKeys"
          :nodes="treeNodes"
          node-key="key"
          label-key="label"
          icon-key="icon"
          no-connectors
          dense
          default-expand-all
          class="shop-hub-tree"
          data-test="shop-hub-tree"
          @update:selected="onNodeSelected"
        >
          <template #default-header="prop">
            <div
              class="shop-hub-tree__node row items-center no-wrap"
              :class="{ 'shop-hub-tree__node--leaf': !!prop.node.routeName }"
              :data-test="`shop-hub-node-${prop.node.key}`"
              @click="onNodeHeaderClick(prop.node, $event)"
            >
              <q-icon :name="prop.node.icon" size="18px" class="q-mr-sm text-grey-7" />
              <span class="text-body2 text-weight-medium text-grey-9">{{ prop.node.label }}</span>
              <q-icon
                v-if="prop.node.routeName"
                name="ph ph-arrow-right"
                size="14px"
                class="q-ml-auto text-grey-5"
              />
            </div>
          </template>
        </q-tree>
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
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  SHOP_ORDER_HUB_TREE,
  filterHubTree,
  findHubTreeNodeByKey,
  mapHubTreeToQTreeNodes,
  type ShopHubTreeNode,
} from '../config/shopOrderHubTree';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const authStore = useAuthStore();
const { getModuleAccess } = useModulePermissions();

const expandedKeys = ref<string[]>([]);

const filteredTreeDefs = computed(() => {
  void authStore.activeModuleKeys;
  void authStore.access?.effectiveGrants;
  void authStore.tenantId;

  return filterHubTree(SHOP_ORDER_HUB_TREE, (moduleKey) =>
    getModuleAccess(moduleKey, 'view').allowed,
  );
});

const treeNodes = computed<ShopHubTreeNode[]>(() =>
  mapHubTreeToQTreeNodes(filteredTreeDefs.value, (key) => t(key)),
);

const tenantSlug = computed(
  () => authStore.selectedTenant?.slug ?? (route.params.tenantSlug as string | undefined) ?? '',
);

const navigateToNode = (node: ShopHubTreeNode) => {
  if (!node.routeName) {
    return;
  }
  void router.push({
    name: node.routeName,
    params: { tenantSlug: tenantSlug.value },
  });
};

const onNodeHeaderClick = (node: ShopHubTreeNode, event: Event) => {
  if (!node.routeName) {
    return;
  }
  event.stopPropagation();
  navigateToNode(node);
};

const onNodeSelected = (key: string | null) => {
  if (!key) {
    return;
  }
  const node = findHubTreeNodeByKey(treeNodes.value, key);
  if (node) {
    navigateToNode(node);
  }
};
</script>

<style scoped>
.shop-order-overview-page {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.overview-container {
  height: 100%;
}

.shop-hub-tree :deep(.q-tree__node-header) {
  padding: 4px 0;
  border-radius: 8px;
}

.shop-hub-tree :deep(.q-tree__node-header:hover) {
  background: rgba(241, 245, 249, 0.9);
}

.shop-hub-tree__node {
  width: 100%;
  min-height: 36px;
  padding: 6px 8px;
  border-radius: 8px;
}

.shop-hub-tree__node--leaf {
  cursor: pointer;
}

.shop-hub-tree__node--leaf:hover {
  color: var(--q-primary);
}

body.body--dark .shop-hub-tree :deep(.q-tree__node-header:hover) {
  background: rgba(38, 38, 38, 0.9);
}
</style>
