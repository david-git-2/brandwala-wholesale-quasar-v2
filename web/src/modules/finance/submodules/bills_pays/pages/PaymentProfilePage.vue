<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>

    <ProfileOperatingAccountPanel
      v-if="entityId > 0"
      class="col overflow-hidden"
      :tenant-id="tenantId"
      :books-tenant-id="booksTenantId"
      :entity-type="entityType"
      :entity-id="entityId"
      :party-name="partyName"
      :tenant-name="tenantName"
      :tenant-slug="tenantSlug"
      active
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProfileOperatingAccountPanel from '../components/ProfileOperatingAccountPanel.vue';
import { paymentsPageRoute } from '../utils/paymentsNavigation';
import { usePaymentProfileQuery } from '../composables/usePaymentProfileQuery';
import type { PayTransferEntityType } from '../types/payTransferParty';

const ALLOWED_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor', 'investor']);

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const entityType = computed(() => {
  const raw = route.params.entityType;
  const t = typeof raw === 'string' ? raw : '';
  return (ALLOWED_TYPES.has(t) ? t : 'customer') as PayTransferEntityType | 'investor';
});

const entityId = computed(() => {
  const raw = route.params.entityId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : 0;
});

const profileParams = computed(() => ({
  tenantId: tenantId.value,
  entityType: entityType.value,
  entityId: entityId.value,
  ledgerLimit: 50,
  paysLimit: 50,
}));

const profileQuery = usePaymentProfileQuery(profileParams);
const partyName = computed(() => profileQuery.data.value?.detail.name ?? '—');
const tenantName = computed(() => authStore.selectedTenant?.name ?? 'Company');
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const goBack = () => {
  router.push(paymentsPageRoute(tenantSlug.value, 'in'));
};
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
}
</style>
