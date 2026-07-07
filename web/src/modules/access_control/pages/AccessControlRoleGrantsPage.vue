<template>
  <q-page class="q-pa-md admin-access-control-role-grants-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-auto">
            <q-btn
              flat
              round
              dense
              icon="arrow_back"
              color="primary"
              @click="goBack"
            />
          </div>
          <div class="col">
            <div class="text-h6 text-weight-bold">
              Grants Matrix: {{ role?.name || 'Loading...' }}
            </div>
            <div class="text-caption text-grey-8">
              Configure fine-grained module × action access rights. Platform-scoped controls are hidden.
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <div v-if="loading" class="row justify-center q-my-lg">
      <q-spinner-dots size="40px" color="primary" />
    </div>

    <!-- Grant Matrix Grouped by Module -->
    <div v-else class="row q-col-gutter-md">
      <div v-for="mod in groupedActions" :key="mod.moduleKey" class="col-12 col-md-6">
        <q-card flat class="floating-surface shadow-1 full-height">
          <q-card-section class="bg-grey-2 q-py-sm">
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              {{ formatModuleKey(mod.moduleKey) }}
            </div>
            <div class="text-caption text-grey-6">Module key: {{ mod.moduleKey }}</div>
          </q-card-section>

          <q-separator />

          <q-card-section class="q-py-xs">
            <q-list separator>
              <q-item v-for="act in mod.actions" :key="act.action" class="q-py-xs">
                <q-item-section>
                  <q-item-label class="text-weight-medium text-grey-8 text-capitalize">
                    {{ act.action }}
                  </q-item-label>
                  <q-item-label v-if="act.description" caption class="text-grey-6">
                    {{ act.description }}
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <q-toggle
                    :model-value="isAllowed(mod.moduleKey, act.action)"
                    color="positive"
                    :disable="savingMap[mod.moduleKey + ':' + act.action]"
                    @update:model-value="(val) => toggleGrant(mod.moduleKey, act.action, val)"
                  >
                    <q-spinner v-if="savingMap[mod.moduleKey + ':' + act.action]" size="xs" color="positive" />
                  </q-toggle>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { showSuccessNotification } from 'src/utils/appFeedback'

const props = defineProps<{
  id: number
}>()

const router = useRouter()
const authStore = useAuthStore()

const role = ref<any>(null)
const grants = ref<any[]>([])
const moduleActions = ref<any[]>([])
const loading = ref(false)
const pageError = ref<string | null>(null)

// Track individual toggles currently saving to DB
const savingMap = ref<Record<string, boolean>>({})

const loadData = async () => {
  loading.value = true
  pageError.value = null

  try {
    // 1. Fetch role details
    const { data: roleData, error: roleError } = await supabase.rpc(
      'get_tenant_role_detail',
      { p_role_id: props.id }
    )

    if (roleError) {
      pageError.value = roleError.message
      return
    }

    role.value = roleData

    const tenantId = authStore.tenantId
    if (!tenantId) {
      pageError.value = 'Tenant context is required.'
      return
    }

    const { data: actionsData, error: actionsError } = await supabase.rpc(
      'list_configurable_module_actions',
      {
        p_scope: roleData.scope,
        p_tenant_id: tenantId,
      },
    )

    if (actionsError) {
      pageError.value = actionsError.message
      return
    }

    moduleActions.value = actionsData || []

    // 3. Fetch existing role grants
    const { data: grantsData, error: grantsError } = await supabase.rpc(
      'list_tenant_role_grants',
      { p_tenant_role_id: props.id }
    )

    if (grantsError) {
      pageError.value = grantsError.message
      return
    }

    grants.value = grantsData || []
  } catch (err: any) {
    pageError.value = err.message || 'Failed to load grants data'
  } finally {
    loading.value = false
  }
}

// Group active configurable module actions by module key
const groupedActions = computed(() => {
  const activeModuleKeys = authStore.activeModuleKeys
  // Only display actions belonging to modules currently enabled for the tenant
  const activeActions = moduleActions.value.filter((action) =>
    activeModuleKeys.includes(action.module_key)
  )

  const groups: Record<string, any[]> = {}
  activeActions.forEach((action) => {
    const key = action.module_key
    const arr = groups[key] || []
    arr.push(action)
    groups[key] = arr
  })

  return Object.keys(groups).map((moduleKey) => ({
    moduleKey,
    actions: groups[moduleKey],
  }))
})

const isAllowed = (moduleKey: string, action: string): boolean => {
  const grant = grants.value.find(
    (g) => g.module_key === moduleKey && g.action === action
  )
  return grant ? Boolean(grant.allowed) : false
}

const toggleGrant = async (moduleKey: string, action: string, allowed: boolean) => {
  const key = `${moduleKey}:${action}`
  savingMap.value[key] = true
  pageError.value = null

  try {
    const { error } = await supabase.rpc('upsert_tenant_role_grant', {
      p_tenant_role_id: props.id,
      p_module_key: moduleKey,
      p_action: action,
      p_allowed: allowed,
    })

    if (error) {
      pageError.value = error.message
      return
    }

    // Update local state list
    const existingIndex = grants.value.findIndex(
      (g) => g.module_key === moduleKey && g.action === action
    )

    if (existingIndex >= 0) {
      grants.value[existingIndex] = {
        ...grants.value[existingIndex],
        allowed,
      }
    } else {
      grants.value.push({
        tenant_role_id: props.id,
        module_key: moduleKey,
        action,
        allowed,
      })
    }

    showSuccessNotification(`Grant rules updated for ${formatModuleKey(moduleKey)}: ${action}`)
  } catch (err: any) {
    pageError.value = err.message || 'Failed to update grant rule'
  } finally {
    savingMap.value[key] = false
  }
}

const formatModuleKey = (key: string): string => {
  return key
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}

const goBack = () => {
  const tenantSlug = authStore.tenantSlug
  const backRoute = tenantSlug ? `/${tenantSlug}/app/access-control/roles` : '/app/access-control/roles'
  void router.push(backRoute)
}

onMounted(() => {
  void loadData()
})
</script>

<style scoped>
.floating-surface {
  border-radius: 12px;
}
.hero-surface {
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}
</style>
