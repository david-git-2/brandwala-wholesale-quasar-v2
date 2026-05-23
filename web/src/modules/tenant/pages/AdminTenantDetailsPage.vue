<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="tenant-details-hero">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-md">
            <div class="text-overline">Operations</div>
            <h1 class="text-h5 q-my-none">Tenant Details</h1>
            <p v-if="tenant" class="text-body2 text-grey-7 q-mt-xs q-mb-none">
              {{ tenant.name }} · {{ tenant.slug }}
            </p>
          </div>
          <div class="col-12 col-md-auto row q-gutter-sm items-center">
            <q-chip class="tenant-details-hero-chip" :color="tenant?.is_active ? 'positive' : 'grey-6'" text-color="white">
              {{ tenant?.is_active ? 'Active' : 'Inactive' }}
            </q-chip>
          </div>
        </div>
      </section>

      <q-banner v-if="pageError" class="bw-status-banner text-white" rounded>
        {{ pageError }}
      </q-banner>

      <q-card v-if="pageLoading" flat bordered>
        <q-card-section class="text-grey-7">Loading tenant details...</q-card-section>
      </q-card>

      <q-card v-else-if="!tenant" flat bordered>
        <q-card-section class="text-grey-7">Tenant not found.</q-card-section>
      </q-card>

      <div v-else class="row q-col-gutter-md">
        <div class="col-12 col-lg-7">
          <q-card flat bordered class="tenant-details-card">
            <q-card-section class="row items-start justify-between q-col-gutter-sm">
              <div class="col">
                <div class="text-overline">Tenant #{{ tenant.id }}</div>
                <div class="text-h6 text-weight-bold">{{ tenant.name }}</div>
                <div class="text-body2 text-grey-7">{{ tenant.slug }}</div>
              </div>
              <div class="col-auto">
                <q-chip class="tenant-status-chip" :color="tenant.is_active ? 'positive' : 'grey-6'" text-color="white">
                  {{ tenant.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-gutter-md">
              <div><strong>ID:</strong> #{{ tenant.id }}</div>
              <div><strong>Name:</strong> {{ tenant.name }}</div>
              <div><strong>Slug:</strong> {{ tenant.slug }}</div>

              <q-card flat bordered class="q-pa-sm">
                <div class="text-caption text-grey-7 q-mb-xs">Admin Login</div>
                <div class="row items-center justify-between q-gutter-sm">
                  <a :href="adminLoginUrl" class="text-primary ellipsis col" target="_blank" rel="noopener noreferrer">
                    {{ adminLoginUrl }}
                  </a>
                  <q-btn flat round dense icon="content_copy" aria-label="Copy admin login URL" @click="copyLoginUrl(adminLoginUrl, 'Admin login URL copied.')" />
                </div>
              </q-card>

              <q-card flat bordered class="q-pa-sm">
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
          <q-card flat bordered class="tenant-details-card">
            <q-card-section>
              <div class="text-h6 text-weight-bold">Management</div>
              <div class="text-body2 text-grey-7 q-mt-xs">
                Open each area on a dedicated page to keep workflows clean.
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="column q-gutter-sm">
              <q-btn color="primary" icon="groups" label="Customer Group Management" no-caps unelevated class="full-width" @click="goToSection('customer-groups')" />
              <q-btn color="primary" icon="manage_accounts" label="Staff Management" no-caps unelevated class="full-width" @click="goToSection('staff')" />
              <q-btn color="primary" icon="extension" label="Enable Modules" no-caps unelevated class="full-width" @click="goToSection('modules')" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { copyToClipboard, useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import { useTenantStore } from '../stores/tenantStore'
import type { Tenant } from '../types'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()

const tenantStore = useTenantStore()
const { items } = storeToRefs(tenantStore)

const pageLoading = ref(false)
const pageError = ref('')

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
)

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
.tenant-details-hero {
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 14px;
  padding: 1rem;
  background:
    linear-gradient(135deg, rgba(59, 130, 246, 0.1), rgba(16, 185, 129, 0.08)),
    #ffffff;
}

.tenant-details-hero-chip {
  font-weight: 600;
}

.tenant-details-card {
  border-radius: 12px;
}

.tenant-status-chip {
  font-weight: 600;
}
</style>
