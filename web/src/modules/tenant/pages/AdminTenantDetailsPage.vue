<template>
  <q-page class="q-pa-sm">
    <div class="q-mb-md row items-center justify-between">
      <div class="row items-center q-gutter-sm">
        <q-btn flat round icon="arrow_back" @click="goBack" />
        <div>
          <div class="text-h5 text-weight-bold">Tenant Details</div>
          <div v-if="tenant" class="text-grey-7">
            {{ tenant.name }} · {{ tenant.slug }}
          </div>
        </div>
      </div>
    </div>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <div v-if="pageLoading" class="text-grey-7">Loading tenant details...</div>

    <div v-else-if="!tenant" class="text-grey-7">Tenant not found.</div>

    <div v-else class="row q-col-gutter-lg">
      <div class="col-12 col-lg-6">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-start justify-between">
            <div>
              <div class="text-h6">{{ tenant.name }}</div>
              <div class="text-caption text-grey-7">{{ tenant.slug }}</div>
            </div>

            <q-badge :color="tenant.is_active ? 'positive' : 'grey-6'">
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </q-badge>
          </q-card-section>

          <q-separator />

          <q-card-section class="q-gutter-md">
            <div><strong>ID:</strong> #{{ tenant.id }}</div>
            <div><strong>Name:</strong> {{ tenant.name }}</div>
            <div><strong>Slug:</strong> {{ tenant.slug }}</div>
            <div class="row items-center justify-between q-gutter-sm">
              <div class="col min-w-0">
                <strong>Admin Login:</strong>
                <a
                  :href="adminLoginUrl"
                  class="text-primary"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ adminLoginUrl }}
                </a>
              </div>
              <div class="col-auto">
                <q-btn
                  flat
                  round
                  dense
                  icon="content_copy"
                  aria-label="Copy admin login URL"
                  @click="copyLoginUrl(adminLoginUrl, 'Admin login URL copied.')"
                />
              </div>
            </div>
            <div class="row items-center justify-between q-gutter-sm">
              <div class="col min-w-0">
                <strong>Customer Login:</strong>
                <a
                  :href="customerLoginUrl"
                  class="text-primary"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ customerLoginUrl }}
                </a>
              </div>
              <div class="col-auto">
                <q-btn
                  flat
                  round
                  dense
                  icon="content_copy"
                  aria-label="Copy customer login URL"
                  @click="copyLoginUrl(customerLoginUrl, 'Customer login URL copied.')"
                />
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-lg-6">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-h6">Management</div>
            <div class="text-caption text-grey-7">
              Open each area on a separate page for a cleaner workflow.
            </div>
          </q-card-section>

          <q-separator />

          <q-card-section class="column q-gutter-sm">
            <q-btn
              color="primary"
              icon="groups"
              label="Customer Group Management"
              no-caps
              unelevated
              class="full-width"
              @click="goToSection('customer-groups')"
            />
            <q-btn
              color="primary"
              icon="manage_accounts"
              label="Staff Management"
              no-caps
              unelevated
              class="full-width"
              @click="goToSection('staff')"
            />
            <q-btn
              color="primary"
              icon="extension"
              label="Enable Modules"
              no-caps
              unelevated
              class="full-width"
              @click="goToSection('modules')"
            />
          </q-card-section>
        </q-card>
      </div>
    </div>
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

const goBack = () => {
  const tenantSlug = tenantStore.selectedTenantSlug
  void router.push(tenantSlug ? `/${tenantSlug}/app/tenants` : '/app/tenants')
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
