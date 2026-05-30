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
              <span class="status-dot" :style="{ backgroundColor: tenant?.is_active ? '#2f8b5d' : '#66758c' }" />
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
      <div v-if="!tenant" class="text-grey-7 q-pa-lg text-center">
        Tenant not found.
      </div>

      <div v-else class="row q-col-gutter-md">
        <div class="col-12 col-lg-7">
          <q-card flat class="tenant-details-card floating-surface shadow-1">
            <q-card-section class="row items-start justify-between q-col-gutter-sm">
              <div class="col">
                <div class="text-overline text-primary text-weight-bold">Tenant #{{ tenant.id }}</div>
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
                  <span class="status-dot" :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }" />
                  {{ tenant.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-gutter-md">
              <div><strong>ID:</strong> #{{ tenant.id }}</div>
              <div><strong>Name:</strong> {{ tenant.name }}</div>
              <div><strong>Slug:</strong> {{ tenant.slug }}</div>

              <q-card flat class="q-pa-sm inner-card">
                <div class="text-caption text-grey-7 q-mb-xs">Admin Login</div>
                <div class="row items-center justify-between q-gutter-sm">
                  <a :href="adminLoginUrl" class="text-primary ellipsis col" target="_blank" rel="noopener noreferrer">
                    {{ adminLoginUrl }}
                  </a>
                  <q-btn flat round dense icon="content_copy" aria-label="Copy admin login URL" @click="copyLoginUrl(adminLoginUrl, 'Admin login URL copied.')" />
                </div>
              </q-card>

              <q-card flat class="q-pa-sm inner-card">
                <div class="text-caption text-grey-7 q-mb-xs">Customer Login</div>
                <div class="row items-center justify-between q-gutter-sm">
                  <a :href="customerLoginUrl" class="text-primary ellipsis col" target="_blank" rel="noopener noreferrer">
                    {{ customerLoginUrl }}
                  </a>
                  <q-btn flat round dense icon="content_copy" aria-label="Copy customer login URL" @click="copyLoginUrl(customerLoginUrl, 'Customer login URL copied.')" />
                </div>
              </q-card>
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
              <q-btn color="primary" icon="o_groups" label="Customer Group Management" no-caps class="pill-btn slim-btn full-width" @click="goToSection('customer-groups')" />
              <q-btn color="primary" icon="o_manage_accounts" label="Staff Management" no-caps class="pill-btn slim-btn full-width" @click="goToSection('staff')" />
              <q-btn color="primary" icon="o_extension" :label="modulesButtonLabel" no-caps class="pill-btn slim-btn full-width" @click="goToSection('modules')" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { copyToClipboard, useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useTenantStore } from '../stores/tenantStore'
import type { Tenant } from '../types'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const tenantStore = useTenantStore()
const { items } = storeToRefs(tenantStore)

const pageLoading = ref(false)
const pageError = ref('')

const canManageModules = computed(() => {
  return authStore.matchedRole === 'superadmin' && authStore.scope === 'platform'
})

const modulesButtonLabel = computed(() => {
  return canManageModules.value ? 'Enable Modules' : 'Module Features'
})

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
)

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
}

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
}

const baseUrl = computed(() =>
  typeof window === 'undefined' ? '' : window.location.origin,
)

const adminLoginUrl = computed(() =>
  tenant.value?.slug ? `${baseUrl.value}/${tenant.value.slug}/app/login` : `${baseUrl.value}/app/login`,
)

const customerLoginUrl = computed(() =>
  tenant.value?.slug ? `${baseUrl.value}/${tenant.value.slug}/shop/login` : `${baseUrl.value}/shop/login`,
)

const loadPageData = async () => {
  pageLoading.value = true
  pageError.value = ''

  try {
    await tenantStore.fetchTenantDetailsByMembership({
      tenantId: tenantId.value,
    })

    if (!tenant.value) {
      pageError.value = 'Tenant not found.'
    }
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
}

const copyLoginUrl = async (value: string, successMessage: string) => {
  try {
    await copyToClipboard(value)
    $q.notify({
      color: 'positive',
      message: successMessage,
      icon: 'check',
      position: 'top',
    })
  } catch (error) {
    console.error(error)
    $q.notify({
      color: 'negative',
      message: 'Failed to copy URL.',
      icon: 'error',
      position: 'top',
    })
  }
}

const goToSection = (section: 'customer-groups' | 'staff' | 'modules') => {
  const slug = tenant.value?.slug ?? tenantStore.selectedTenantSlug ?? null
  const base = slug ? `/${slug}/app/tenants/${tenantId.value}` : `/app/tenants/${tenantId.value}`
  void router.push(`${base}/${section}`)
}

watch(
  tenant,
  (value) => {
    if (!value) {
      return
    }

    tenantStore.setSelectedTenant({
      id: value.id,
      slug: value.slug,
    })
  },
  { immediate: true },
)

onMounted(() => {
  void loadPageData()
})
</script>

<style scoped>
.admin-tenant-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.tenant-details-card {
  border-radius: 14px;
}

.inner-card {
  border-radius: 12px;
  border: 1px solid rgba(34, 56, 101, 0.06);
  background: rgba(255, 255, 255, 0.5);
}

.pill-btn {
  border-radius: 999px;
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
