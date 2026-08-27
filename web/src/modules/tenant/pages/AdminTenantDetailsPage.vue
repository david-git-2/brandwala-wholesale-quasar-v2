<template>
  <q-page class="q-pa-md admin-tenant-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Tenant Details</div>
            <div v-if="tenant" class="text-caption text-grey-8">
              {{ tenant.name }} · {{ tenant.slug }}
            </div>
          </div>
          <div class="col-auto">
            <q-chip
              dense
              square
              class="costing-status-chip"
              :style="tenant?.is_active ? activeStatusStyle : inactiveStatusStyle"
            >
              <span
                class="status-dot"
                :style="{ backgroundColor: tenant?.is_active ? '#2f8b5d' : '#66758c' }"
              />
              {{ tenant?.is_active ? 'Active' : 'Inactive' }}
            </q-chip>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <PageInitialLoader v-if="pageLoading" />

    <template v-else>
      <div v-if="!tenant" class="text-grey-7 q-pa-lg text-center">Tenant not found.</div>

      <div v-else class="row q-col-gutter-md">
        <div class="col-12 col-lg-7">
          <q-card flat class="tenant-details-card floating-surface shadow-1">
            <q-card-section class="row items-start justify-between q-col-gutter-sm">
              <div class="col">
                <div class="text-overline text-primary text-weight-bold">
                  Tenant #{{ tenant.id }}
                </div>
                <div class="text-subtitle1 text-weight-bold text-grey-9">{{ tenant.name }}</div>
                <div class="text-body2 text-grey-7 q-mt-xs">{{ tenant.slug }}</div>
              </div>
              <div class="col-auto">
                <q-chip
                  dense
                  square
                  class="costing-status-chip"
                  :style="tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
                >
                  <span
                    class="status-dot"
                    :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }"
                  />
                  {{ tenant.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-gutter-md">
              <div><strong>ID:</strong> #{{ tenant.id }}</div>
              <div><strong>Name:</strong> {{ tenant.name }}</div>
              <div><strong>Slug:</strong> {{ tenant.slug }}</div>

              <div class="text-overline text-grey-7 text-weight-bold q-mb-sm">Access Portals</div>
              <div class="row q-col-gutter-sm">
                <div class="col-12 col-md-4">
                  <button
                    type="button"
                    class="portal-card portal-card--clickable q-pa-md full-width"
                    aria-label="Copy admin portal login URL"
                    @click="copyLoginUrl(adminLoginUrl)"
                  >
                    <div class="row items-center q-gutter-sm no-wrap">
                      <q-icon name="ph ph-shield-check" size="20px" color="primary" />
                      <span class="text-caption text-weight-medium text-grey-9">Admin Portal</span>
                      <q-space />
                      <q-icon name="ph ph-copy" size="14px" color="grey-6" />
                    </div>
                  </button>
                </div>

                <div class="col-12 col-md-4">
                  <button
                    type="button"
                    class="portal-card portal-card--clickable q-pa-md full-width"
                    aria-label="Copy customer storefront login URL"
                    @click="copyLoginUrl(customerLoginUrl)"
                  >
                    <div class="row items-center q-gutter-sm no-wrap">
                      <q-icon name="ph ph-storefront" size="20px" color="secondary" />
                      <span class="text-caption text-weight-medium text-grey-9">Customer Storefront</span>
                      <q-space />
                      <q-icon name="ph ph-copy" size="14px" color="grey-6" />
                    </div>
                  </button>
                </div>

                <div v-if="isCapitalHostTenant" class="col-12 col-md-4">
                  <button
                    type="button"
                    class="portal-card portal-card--clickable q-pa-md full-width"
                    aria-label="Copy investor portal login URL"
                    @click="copyLoginUrl(investorLoginUrl)"
                  >
                    <div class="row items-center q-gutter-sm no-wrap">
                      <q-icon name="ph ph-piggy-bank" size="20px" color="amber-9" />
                      <span class="text-caption text-weight-medium text-grey-9">Investor Portal</span>
                      <q-space />
                      <q-icon name="ph ph-copy" size="14px" color="grey-6" />
                    </div>
                  </button>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-lg-5">
          <q-card flat class="tenant-details-card floating-surface shadow-1">
            <q-card-section>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Management</div>
              <div class="text-caption text-grey-8 q-mt-xs">
                Open each area on a dedicated page to keep workflows clean.
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="column q-gutter-sm">
              <q-btn
                color="primary"
                icon="ph ph-users-three"
                label="Customer Group Management"
                no-caps
                class="pill-btn slim-btn full-width"
                @click="goToSection('customer-groups')"
              />
              <q-btn
                color="primary"
                icon="ph ph-user-gear"
                label="Staff Management"
                no-caps
                class="pill-btn slim-btn full-width"
                @click="goToSection('staff')"
              />
              <q-btn
                v-if="isCapitalHostTenant"
                color="primary"
                icon="ph ph-piggy-bank"
                label="Investor Management"
                no-caps
                class="pill-btn slim-btn full-width"
                @click="goToSection('investors')"
              />
              <q-btn
                color="primary"
                icon="ph ph-puzzle-piece"
                :label="modulesButtonLabel"
                no-caps
                class="pill-btn slim-btn full-width"
                @click="goToSection('modules')"
              />
              <q-btn
                color="primary"
                icon="ph ph-faders"
                label="Tenant Preferences"
                no-caps
                class="pill-btn slim-btn full-width"
                @click="goToSection('preferences')"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { useTenantStore } from '../stores/tenantStore';
import type { Tenant } from '../types';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const tenantStore = useTenantStore();
const { items } = storeToRefs(tenantStore);

const pageLoading = ref(false);
const pageError = ref('');

const canManageModules = computed(() => {
  return authStore.matchedRole === 'superadmin' && authStore.scope === 'platform';
});

const modulesButtonLabel = computed(() => {
  return canManageModules.value ? 'Enable Modules' : 'Module Features';
});

const tenantId = computed(() => Number(route.params.id));

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
);

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
  tenant.value?.slug
    ? `${baseUrl.value}/${tenant.value.slug}/app/login`
    : `${baseUrl.value}/app/login`,
);

const customerLoginUrl = computed(() =>
  tenant.value?.slug
    ? `${baseUrl.value}/${tenant.value.slug}/shop/login`
    : `${baseUrl.value}/shop/login`,
);

const investorLoginUrl = computed(() =>
  tenant.value?.slug
    ? `${baseUrl.value}/${tenant.value.slug}/investor/login`
    : `${baseUrl.value}/investor/login`,
);

const isCapitalHostTenant = computed(() => tenant.value?.parent_id === null);

const loadPageData = async () => {
  pageLoading.value = true;
  pageError.value = '';

  try {
    await tenantStore.fetchTenantDetailsByMembership({
      tenantId: tenantId.value,
    });

    if (!tenant.value) {
      pageError.value = 'Tenant not found.';
    }
  } catch (error) {
    console.error(error);
    pageError.value = 'Failed to load tenant details.';
  } finally {
    pageLoading.value = false;
  }
};

const copyLoginUrl = async (value: string) => {
  try {
    await copyToClipboard(value);
    showSuccessNotification('Copied to clipboard');
  } catch (error) {
    console.error(error);
    showErrorNotification('Failed to copy URL.');
  }
};

const goToSection = (
  section: 'customer-groups' | 'staff' | 'investors' | 'modules' | 'preferences',
) => {
  const slug = tenant.value?.slug ?? tenantStore.selectedTenantSlug ?? null;
  if (section === 'preferences') {
    const base = slug ? `/${slug}/app/tenants/${tenantId.value}` : `/app/tenants/${tenantId.value}`;
    void router.push(`${base}/preferences`);
  } else {
    // Map section to corresponding access control tab name
    const tabMap = {
      'customer-groups': 'customer-groups',
      staff: 'team',
      investors: 'investors',
      modules: 'modules',
    };
    const tab = tabMap[section] || 'modules';
    const base = slug ? `/${slug}/app/access-control` : '/app/access-control';
    void router.push(`${base}/${tab}`);
  }
};

watch(
  tenant,
  (value) => {
    if (!value) {
      return;
    }

    tenantStore.setSelectedTenant({
      id: value.id,
      slug: value.slug,
    });
  },
  { immediate: true },
);

onMounted(() => {
  void loadPageData();
});
</script>

<style scoped>
.admin-tenant-details-page {
  background: transparent;
}
.hero-surface {
  border-radius: 16px;
}

.tenant-details-card {
  border-radius: 14px;
}

.portal-card {
  border-radius: 8px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(255, 255, 255, 0.6);
  transition: all 0.2s ease;
  text-align: left;
}

.portal-card--clickable {
  cursor: pointer;
  appearance: none;
  font: inherit;
  color: inherit;
}

.portal-card--clickable:hover,
.portal-card--clickable:focus-visible {
  background: rgba(255, 255, 255, 0.95);
  border-color: rgba(34, 56, 101, 0.16);
  outline: none;
}

.portal-card--clickable:focus-visible {
  box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.25);
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
