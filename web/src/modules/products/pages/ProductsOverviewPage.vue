<template>
  <q-page class="module-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <div class="row q-col-gutter-sm">
        <div
          v-for="card in hubCards"
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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router';

type HubCard = {
  key: string;
  path: string;
  title: string;
  caption: string;
  icon: string;
  badgeClass: string;
};

const router = useRouter();
const route = useRoute();

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const hubCards: HubCard[] = [
  {
    key: 'catalog',
    path: 'list',
    title: 'Products',
    caption: 'Browse and manage your tenant product catalog.',
    icon: 'ph ph-package',
    badgeClass: 'bg-blue-1 text-blue-9',
  },
  {
    key: 'brands',
    path: 'brands',
    title: 'Brands',
    caption: 'Manage product brands used across the catalog.',
    icon: 'ph ph-tag',
    badgeClass: 'bg-purple-1 text-purple-9',
  },
  {
    key: 'categories',
    path: 'categories',
    title: 'Categories',
    caption: 'Organize products into categories and groups.',
    icon: 'ph ph-folders',
    badgeClass: 'bg-teal-1 text-teal-9',
  },
];

const goTo = (path: string) => {
  void router.push(`${getTenantPrefix()}/app/products/${path}`);
};
</script>

<style scoped>
.module-overview-page {
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

body.body--dark .module-overview-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .hub-type-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}
</style>
