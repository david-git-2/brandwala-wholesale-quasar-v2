<template>
  <q-page class="tf-page people-page page-fixed-layout q-pa-md column no-wrap overflow-hidden">
    <app-page-header title="People" subtitle="Parties and operating accounts." eyebrow="PEOPLE" />

    <TfDrawerSectionTabs v-model="activeTab" :tabs="sectionTabs" aria-label="People category" />

    <q-card flat bordered class="col column no-wrap overflow-hidden">
      <q-card-section v-if="activeTab === 'tenant'" class="col overflow-auto">
        <ProfileOperatingAccountPanel
          v-if="booksTenantId"
          :tenant-id="tenantId"
          :books-tenant-id="booksTenantId"
          entity-type="tenant"
          :entity-id="booksTenantId"
          :party-name="tenantName"
          :tenant-name="tenantName"
          :tenant-slug="tenantSlug"
          active
        />
      </q-card-section>

      <q-card-section
        v-else-if="activeTab === 'customer'"
        class="col column no-wrap q-pa-sm overflow-hidden"
      >
        <CustomerGroupListPanel :fill-height="false" />
      </q-card-section>

      <q-card-section v-else-if="activeTab === 'vendor'" class="col overflow-hidden column">
        <PeoplePartyListPanel entity-type="vendor" entity-label="vendors" />
      </q-card-section>

      <q-card-section v-else-if="activeTab === 'cargo'" class="col overflow-hidden column">
        <PeoplePartyListPanel entity-type="cargo_company" entity-label="cargo companies" />
      </q-card-section>

      <q-card-section v-else-if="activeTab === 'curia'" class="col overflow-hidden column">
        <PeoplePartyListPanel entity-type="courier" entity-label="courier / curia" />
      </q-card-section>

      <q-card-section v-else-if="activeTab === 'investor'" class="col overflow-hidden column">
        <PeoplePartyListPanel entity-type="investor" entity-label="investors" />
      </q-card-section>

      <q-card-section v-else class="people-page__placeholder" :data-active-tab="activeTab">
        <div class="text-body2 text-grey-7 text-center q-pa-lg">
          End-customer (dropship recipient) money is not tracked here — see the shop order only.
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import TfDrawerSectionTabs, {
  type TfDrawerSectionTab,
} from 'src/components/ui/TfDrawerSectionTabs.vue';
import CustomerGroupListPanel from 'src/modules/customer/components/CustomerGroupListPanel.vue';
import ProfileOperatingAccountPanel from 'src/modules/bills_pays/components/ProfileOperatingAccountPanel.vue';
import PeoplePartyListPanel from '../components/PeoplePartyListPanel.vue';

const PEOPLE_TABS = ['tenant', 'customer', 'curia', 'cargo', 'vendor', 'investor', 'end_customer'] as const;
type PeopleTab = (typeof PEOPLE_TABS)[number];

const isPeopleTab = (value: unknown): value is PeopleTab =>
  typeof value === 'string' && (PEOPLE_TABS as readonly string[]).includes(value);

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const activeTab = ref<PeopleTab>('tenant');

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});
const tenantName = computed(() => authStore.selectedTenant?.name ?? 'Company');
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const tabQueryValue = (tab: PeopleTab): string | undefined => (tab === 'tenant' ? undefined : tab);

const syncTabFromQuery = () => {
  const raw = route.query.tab;
  const next = typeof raw === 'string' && isPeopleTab(raw) ? raw : 'tenant';
  if (activeTab.value !== next) {
    activeTab.value = next;
  }
};

watch(() => route.query.tab, () => syncTabFromQuery());

watch(activeTab, (tab) => {
  const desired = tabQueryValue(tab);
  const current = typeof route.query.tab === 'string' ? route.query.tab : undefined;
  if (current === desired || (desired === undefined && !current)) {
    return;
  }
  void router.replace({
    query: {
      ...route.query,
      tab: desired,
    },
  });
});

onMounted(() => {
  syncTabFromQuery();
});

const sectionTabs: readonly TfDrawerSectionTab[] = [
  { name: 'tenant', label: 'Tenant' },
  { name: 'customer', label: 'Customer' },
  { name: 'curia', label: 'Curia' },
  { name: 'cargo', label: 'Cargo' },
  { name: 'vendor', label: 'Vendor' },
  { name: 'investor', label: 'Investor' },
  { name: 'end_customer', label: 'End customer' },
];
</script>

<style scoped>
.people-page__placeholder {
  min-height: 12rem;
}
</style>
