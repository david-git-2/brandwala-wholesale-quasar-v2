<template>
  <q-page class="q-pa-md admin-tenant-preferences-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Tenant Preferences</div>
            <div v-if="tenant" class="text-caption text-grey-8">
              {{ tenant.name }} · {{ tenant.slug }}
            </div>
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

      <TenantPreferenceForm
        v-else
        :model-value="formState"
        :saving="preferenceStore.loading"
        @save="onSave"
      />
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import TenantPreferenceForm from '../components/TenantPreferenceForm.vue'
import { TENANT_PREFERENCE_FIELDS } from '../config/tenantPreferenceFields'
import { useTenantPreferenceStore } from '../stores/tenantPreferenceStore'
import { useTenantStore } from '../stores/tenantStore'
import type { Tenant } from '../types'
import {
  formStateToPreference,
  preferenceToFormState,
} from '../utils/tenantPreferenceUtils'

const route = useRoute()
const $q = useQuasar()
const tenantStore = useTenantStore()
const preferenceStore = useTenantPreferenceStore()
const { items } = storeToRefs(tenantStore)

const pageLoading = ref(false)
const pageError = ref('')
const formState = ref<Record<string, unknown>>({})

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
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
      return
    }

    formState.value = preferenceToFormState(
      TENANT_PREFERENCE_FIELDS,
      tenant.value.preference,
    )
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load tenant preferences.'
  } finally {
    pageLoading.value = false
  }
}

const onSave = async (nextFormState: Record<string, unknown>) => {
  if (!tenant.value) {
    return
  }

  const mergedPreference = formStateToPreference(
    TENANT_PREFERENCE_FIELDS,
    nextFormState,
    tenant.value.preference,
  )

  const result = await preferenceStore.savePreference(tenantId.value, mergedPreference)

  if (!result.success) {
    $q.notify({
      type: 'negative',
      message: result.error ?? 'Failed to save tenant preferences.',
    })
    return
  }

  formState.value = preferenceToFormState(
    TENANT_PREFERENCE_FIELDS,
    result.data?.preference,
  )

  $q.notify({
    type: 'positive',
    message: 'Tenant preferences saved.',
  })
}

onMounted(() => {
  void loadPageData()
})
</script>

<style scoped>
.admin-tenant-preferences-page {
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
</style>
