<template>
  <q-page class="q-pa-md admin-tenant-page">
    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded dense>
      {{ error }}
    </q-banner>

    <PageInitialLoader v-if="loading" />

    <template v-else>
      <!-- Mode 1: Selected Tenant Details View -->
      <div v-if="activeTenant && !showAllWorkspaces" class="admin-tenant-details">
        <q-card flat class="tenant-compact-card floating-surface shadow-1">
          <!-- Compact Card Header -->
          <q-card-section class="q-pa-md">
            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="col-12 col-sm-auto row items-center no-wrap q-gutter-sm">
                <q-avatar size="36px" color="grey-3" text-color="grey-9" font-size="18px" square class="rounded-borders">
                  <q-icon name="ph ph-buildings" />
                </q-avatar>
                <div>
                  <div class="row items-center q-gutter-xs">
                    <span class="text-subtitle2 text-weight-bold text-grey-9">{{ activeTenant.name }}</span>
                    <q-badge color="grey-3" text-color="grey-8" class="q-ml-xs text-caption">#{{ activeTenant.id }}</q-badge>
                  </div>
                  <div class="row items-center q-gutter-x-xs text-caption text-grey-7">
                    <span>{{ activeTenant.slug }}</span>
                    <span>•</span>
                    <span class="text-weight-medium">{{ isCapitalHostTenant ? 'Parent Company' : 'Sister Concern' }}</span>
                  </div>
                </div>
              </div>

              <!-- Top Right Controls -->
              <div class="col-12 col-sm-auto row items-center q-gutter-xs">
                <q-chip
                  dense
                  square
                  class="costing-status-chip"
                  :style="activeTenant.is_active ? activeStatusStyle : inactiveStatusStyle"
                >
                  <span
                    class="status-dot"
                    :style="{ backgroundColor: activeTenant.is_active ? '#2f8b5d' : '#66758c' }"
                  />
                  {{ activeTenant.is_active ? 'Active' : 'Inactive' }}
                </q-chip>

                <q-btn
                  v-if="items.length > 1"
                  outline
                  dense
                  no-caps
                  color="primary"
                  icon="ph ph-squares-four"
                  label="All Workspaces"
                  class="pill-btn slim-btn q-px-sm"
                  @click="showAllWorkspaces = true"
                />
              </div>
            </div>
          </q-card-section>

          <q-separator />

          <!-- Portal Links Section -->
          <q-card-section class="q-pa-lg">
            <div class="text-overline text-grey-7 text-weight-bold q-mb-md">Access Portals</div>
            <div class="row q-col-gutter-md">
              <!-- Admin Portal Tile -->
              <div class="col-12 col-sm-6 col-md-4">
                <button
                  type="button"
                  class="portal-block-card portal-block-card--clickable full-width column items-center justify-center text-center q-pa-md"
                  aria-label="Copy admin portal login URL"
                  @click="copyLoginUrl(adminLoginUrl)"
                >
                  <div class="portal-icon-wrapper bg-primary-subtle q-mb-sm">
                    <q-icon name="ph ph-shield-check" size="26px" color="primary" />
                  </div>
                  <span class="portal-title text-subtitle2 text-weight-bold text-grey-9">Admin Portal</span>
                  <span class="portal-hint text-caption text-grey-6 q-mt-xs">
                    <q-icon name="ph ph-copy" size="13px" class="q-mr-xs" />Copy Link
                  </span>
                </button>
              </div>

              <!-- Customer Storefront Tile -->
              <div class="col-12 col-sm-6 col-md-4">
                <button
                  type="button"
                  class="portal-block-card portal-block-card--clickable full-width column items-center justify-center text-center q-pa-md"
                  aria-label="Copy customer storefront login URL"
                  @click="copyLoginUrl(customerLoginUrl)"
                >
                  <div class="portal-icon-wrapper bg-secondary-subtle q-mb-sm">
                    <q-icon name="ph ph-storefront" size="26px" color="secondary" />
                  </div>
                  <span class="portal-title text-subtitle2 text-weight-bold text-grey-9">Customer Storefront</span>
                  <span class="portal-hint text-caption text-grey-6 q-mt-xs">
                    <q-icon name="ph ph-copy" size="13px" class="q-mr-xs" />Copy Link
                  </span>
                </button>
              </div>

              <!-- Investor Portal Tile (if parent) -->
              <div v-if="isCapitalHostTenant" class="col-12 col-sm-6 col-md-4">
                <button
                  type="button"
                  class="portal-block-card portal-block-card--clickable full-width column items-center justify-center text-center q-pa-md"
                  aria-label="Copy investor portal login URL"
                  @click="copyLoginUrl(investorLoginUrl)"
                >
                  <div class="portal-icon-wrapper bg-amber-subtle q-mb-sm">
                    <q-icon name="ph ph-piggy-bank" size="26px" color="amber-9" />
                  </div>
                  <span class="portal-title text-subtitle2 text-weight-bold text-grey-9">Investor Portal</span>
                  <span class="portal-hint text-caption text-grey-6 q-mt-xs">
                    <q-icon name="ph ph-copy" size="13px" class="q-mr-xs" />Copy Link
                  </span>
                </button>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <!-- Danger Zone Card (Parent Tenant Only) -->
        <TenantDangerZoneCard
          v-if="isCapitalHostTenant"
          :tenant="activeTenant"
          @open-purge-modal="showPurgeModal = true"
        />

        <!-- Purge Confirmation Modal -->
        <TenantPurgeModal
          v-model="showPurgeModal"
          :tenant="activeTenant"
        />
      </div>

      <!-- Mode 2: Tenant Tree List View -->
      <div v-else-if="items.length" class="admin-tenant-list">
        <div v-if="activeTenant" class="row items-center justify-between q-mb-sm">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-arrow-left"
            :label="`Back to ${activeTenant.name}`"
            class="pill-btn q-px-sm"
            @click="showAllWorkspaces = false"
          />
          <span class="text-caption text-grey-7">All Workspaces</span>
        </div>
        <div class="admin-tenant-page__tree-container">
          <TenantTreeList :tenants="items" @click-tenant="goToTenantDetails" />
        </div>
      </div>

      <!-- Empty State -->
      <q-card v-else flat class="floating-surface shadow-1">
        <q-card-section class="text-center q-pa-xl">
          <div class="text-subtitle1 text-grey-9 text-weight-bold">No tenants found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">
            When tenant access is assigned, workspaces will appear here.
          </div>
        </q-card-section>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { copyToClipboard } from 'quasar';
import { storeToRefs } from 'pinia';
import { useRoute } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext';
import { useAdminTenantSelection } from '../composables/useAdminTenantSelection';
import { useTenantStore } from '../stores/tenantStore';
import TenantTreeList from '../components/TenantTreeList.vue';
import TenantDangerZoneCard from '../components/TenantDangerZoneCard.vue';
import TenantPurgeModal from '../components/TenantPurgeModal.vue';
import type { Tenant } from '../types';

const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { items, loading, error } = storeToRefs(tenantStore);
const { selectTenantWorkspace } = useAdminTenantSelection();

const showAllWorkspaces = ref(false);
const showPurgeModal = ref(false);

const routeTenantSlug = computed(() => getTenantSlugFromRoute(route));

const activeTenant = computed<Tenant | null>(() => {
  if (routeTenantSlug.value) {
    return items.value.find((item) => item.slug === routeTenantSlug.value) ?? null;
  }
  if (authStore.selectedTenant?.slug) {
    return items.value.find((item) => item.slug === authStore.selectedTenant?.slug) ?? null;
  }
  return null;
});

const isCapitalHostTenant = computed(() => activeTenant.value?.parent_id === null);

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
};

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
};

const baseUrl = computed(() => (typeof window === 'undefined' ? '' : window.location.origin));

const adminLoginUrl = computed(() =>
  activeTenant.value?.slug
    ? `${baseUrl.value}/${activeTenant.value.slug}/app/login`
    : `${baseUrl.value}/app/login`,
);

const customerLoginUrl = computed(() =>
  activeTenant.value?.slug
    ? `${baseUrl.value}/${activeTenant.value.slug}/shop/login`
    : `${baseUrl.value}/shop/login`,
);

const investorLoginUrl = computed(() =>
  activeTenant.value?.slug
    ? `${baseUrl.value}/${activeTenant.value.slug}/investor/login`
    : `${baseUrl.value}/investor/login`,
);

const refreshTenants = () =>
  tenantStore.fetchTenantsByMembership({
    email: authStore.user?.email ?? null,
  });

const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return;
  const targetTenant = items.value.find((item) => item.id === tenantId) ?? null;

  if (targetTenant) {
    showAllWorkspaces.value = false;
    void selectTenantWorkspace(targetTenant, { destination: 'tenant-details' });
  }
};

const copyLoginUrl = async (value: string) => {
  try {
    await copyToClipboard(value);
    showSuccessNotification('Copied to clipboard');
  } catch (err) {
    console.error(err);
    showErrorNotification('Failed to copy URL.');
  }
};

onMounted(() => {
  void refreshTenants();
});
</script>

<style scoped>
.admin-tenant-page {
  background: transparent;
}

.tenant-compact-card {
  border-radius: 12px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.portal-block-card {
  width: 100%;
  min-height: 120px;
  border-radius: 12px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(255, 255, 255, 0.7);
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  padding: 18px 12px;
}

.portal-block-card--clickable {
  cursor: pointer;
  appearance: none;
  font: inherit;
  color: inherit;
}

.portal-block-card--clickable:hover,
.portal-block-card--clickable:focus-visible {
  transform: translateY(-2px);
  background: #ffffff;
  border-color: rgba(34, 56, 101, 0.2);
  box-shadow: 0 4px 14px rgba(25, 35, 47, 0.08);
  outline: none;
}

.portal-block-card--clickable:focus-visible {
  box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.3);
}

.portal-icon-wrapper {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.bg-primary-subtle {
  background: rgba(25, 118, 210, 0.08);
}

.bg-secondary-subtle {
  background: rgba(38, 166, 154, 0.1);
}

.bg-amber-subtle {
  background: rgba(255, 179, 0, 0.12);
}

.portal-title {
  display: block;
  line-height: 1.2;
}

.portal-hint {
  display: flex;
  align-items: center;
  font-size: 11px;
}

.pill-btn {
  border-radius: 8px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>

