<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Header with Subtitle -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Management</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Customer &amp; Billing Profiles</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage customer groups, member access rules, and sales billing profile defaults.
          </p>
        </div>
      </section>

      <!-- Navigation Tabs Card -->
      <q-card flat bordered class="bg-surface rounded-borders">
        <q-tabs
          :model-value="activeTab"
          dense
          class="text-grey-8"
          active-color="primary"
          indicator-color="primary"
          align="left"
          @update:model-value="onTabChange"
        >
          <q-tab name="customer-groups" icon="ph ph-user-list" label="Customer Groups" no-caps />
          <q-tab name="billing-profiles" icon="ph ph-receipt" label="Billing Profiles" no-caps />
        </q-tabs>
      </q-card>

      <!-- Tab Content Panels -->
      <q-tab-panels
        v-model="activeTab"
        animated
        swipeable
        transition-prev="fade"
        transition-next="fade"
        class="bg-transparent"
      >
        <q-tab-panel name="customer-groups" class="q-pa-none">
          <CustomerAccessPage :is-embedded="true" />
        </q-tab-panel>

        <q-tab-panel name="billing-profiles" class="q-pa-none">
          <BillingProfilesPage :is-embedded="true" />
        </q-tab-panel>
      </q-tab-panels>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CustomerAccessPage from 'src/modules/shop_order/pages/CustomerAccessPage.vue';
import BillingProfilesPage from 'src/modules/sales_invoice/pages/BillingProfilesPage.vue';

const route = useRoute();
const router = useRouter();

type TabType = 'customer-groups' | 'billing-profiles';
const activeTab = ref<TabType>('customer-groups');

const resolveActiveTab = () => {
  const queryTab = route.query.tab as string | undefined;
  if (queryTab === 'billing-profiles' || queryTab === 'customer-groups') {
    activeTab.value = queryTab as TabType;
  } else if (route.name === 'app-global-billing-profiles') {
    activeTab.value = 'billing-profiles';
  } else {
    activeTab.value = 'customer-groups';
  }
};

const onTabChange = (newTab: TabType) => {
  activeTab.value = newTab;
  void router.replace({
    query: {
      ...route.query,
      tab: newTab,
    },
  });
};

onMounted(resolveActiveTab);

watch(
  () => [route.name, route.query.tab],
  () => {
    resolveActiveTab();
  }
);
</script>

<style scoped>
.bw-page {
  padding: clamp(1rem, 2.4vw, 2rem);
}
.bw-page__stack {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}
</style>
