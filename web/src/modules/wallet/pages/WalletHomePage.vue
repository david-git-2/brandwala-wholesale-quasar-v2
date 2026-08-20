<template>
  <q-page class="q-pa-md" style="min-height: calc(100vh - 55px)">
    <!-- Header section -->
    <div class="q-mb-lg">
      <div class="text-overline text-primary text-weight-bold tracking-wide">
        FINANCE &amp; WALLETS
      </div>
      <div class="text-h4 text-weight-bolder text-grey-9 q-mt-xs">
        Wallets
      </div>
      <div class="text-subtitle1 text-grey-7 q-mt-xs">
        Whose money do you want to see?
      </div>
    </div>

    <!-- Skeleton Loader -->
    <div v-if="loading" class="bw-entity-grid">
      <q-card
        v-for="i in 6"
        :key="i"
        flat
        bordered
        class="bg-white q-pa-md"
        style="border-radius: 12px"
      >
        <div class="row items-center no-wrap q-gutter-x-md">
          <q-skeleton type="QAvatar" size="48px" />
          <div class="col">
            <q-skeleton type="text" width="60%" height="24px" />
            <q-skeleton type="text" width="85%" height="16px" />
          </div>
        </div>
      </q-card>
    </div>

    <!-- Entity Cards Grid -->
    <div v-else class="bw-entity-grid">
      <q-card
        v-for="card in walletCards"
        :key="card.slug"
        flat
        bordered
        class="bw-wallet-card bg-white q-pa-md transition-all cursor-pointer"
        style="border-radius: 12px"
        @click="navigateTo(card)"
      >
        <q-card-section class="q-pa-none">
          <div class="row items-center no-wrap q-gutter-x-md">
            <q-avatar
              size="48px"
              :color="card.bgColor"
              :text-color="card.iconColor"
              class="q-mr-xs"
            >
              <q-icon :name="card.icon" size="24px" />
            </q-avatar>

            <div class="col">
              <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center justify-between">
                <span>{{ card.title }}</span>
                <q-icon name="ph ph-caret-right" size="18px" class="text-grey-5 card-arrow" />
              </div>
              <div class="text-caption text-grey-7 q-mt-xs line-clamp-2">
                {{ card.caption }}
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { WalletSlug } from '../utils/walletSlugMap';

interface WalletCardItem {
  slug: WalletSlug;
  title: string;
  caption: string;
  icon: string;
  bgColor: string;
  iconColor: string;
  isCompany?: boolean;
}

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const loading = ref(false);

const tenantId = computed(() => authStore.selectedTenant?.id);

const walletCards: WalletCardItem[] = [
  {
    slug: 'company',
    title: 'Our company',
    caption: 'This business’s cash',
    icon: 'ph ph-buildings',
    bgColor: 'blue-1',
    iconColor: 'blue-9',
    isCompany: true,
  },
  {
    slug: 'customers',
    title: 'Customers',
    caption: 'People who buy from you',
    icon: 'ph ph-users-three',
    bgColor: 'green-1',
    iconColor: 'green-9',
  },
  {
    slug: 'suppliers',
    title: 'Suppliers',
    caption: 'People you buy from',
    icon: 'ph ph-truck-trailer',
    bgColor: 'amber-1',
    iconColor: 'amber-10',
  },
  {
    slug: 'cargo',
    title: 'Cargo',
    caption: 'Freight agents for inbound shipments',
    icon: 'ph ph-package',
    bgColor: 'purple-1',
    iconColor: 'purple-9',
  },
  {
    slug: 'couriers',
    title: 'Couriers',
    caption: 'Last-mile COD',
    icon: 'ph ph-moped',
    bgColor: 'teal-1',
    iconColor: 'teal-9',
  },
  {
    slug: 'investors',
    title: 'Investors',
    caption: 'People who put money in',
    icon: 'ph ph-chart-line-up',
    bgColor: 'orange-1',
    iconColor: 'orange-9',
  },
];

const navigateTo = (card: WalletCardItem) => {
  if (card.isCompany) {
    const activeTenantId = tenantId.value || 1;
    void router.push({
      name: 'app-wallet-company-detail',
      params: { ...route.params, tenantId: activeTenantId },
    });
  } else {
    void router.push({
      name: 'app-wallet-entity-list-page',
      params: { ...route.params, walletType: card.slug },
    });
  }
};
</script>

<style scoped lang="scss">
.bw-wallet-card {
  border: 1px solid #e2e8f0;
  transition: all 0.2s ease-in-out;

  &:hover {
    border-color: var(--q-primary);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
    transform: translateY(-2px);

    .card-arrow {
      color: var(--q-primary) !important;
      transform: translateX(3px);
    }
  }
}

.card-arrow {
  transition: transform 0.2s ease, color 0.2s ease;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
