<template>
  <WorkspaceShell
    :logout-to="logoutTo"
    theme="app"
    :links="links"
  >
    <template #header-left>
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="showHeaderBackButton"
          flat
          round
          dense
          size="md"
          color="primary"
          icon="keyboard_backspace"
          class="app-header-back-btn"
          @click="onHeaderBack"
        />
        <div v-if="tenantName" class="app-context__title">
          {{ tenantName }}
        </div>
      </div>
    </template>

    <template #header-extra>
      <q-select
        v-if="tenantOptions.length"
        :model-value="selectedTenantId"
        :options="tenantOptions"
        dense
        outlined
        emit-value
        map-options
        option-value="value"
        option-label="label"
        label="Tenant"
        class="app-layout__tenant-switcher"
        :loading="selectingTenantId !== null"
        @update:model-value="onSelectTenant"
      />
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAppWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'
import { useAdminTenantSelection } from 'src/modules/tenant/composables/useAdminTenantSelection'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const route = useRoute()
const router = useRouter()
const { links } = useAppWorkspaceLinks()
const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/app/login` : '/app/login',
)
const tenantName = computed(() => tenantStore.selectedTenant?.name ?? '')
const selectedTenantId = computed(() => tenantStore.selectedTenantId)
const tenantOptions = computed(() =>
  tenantStore.availableAdminTenants.map((tenant) => ({
    label: `${tenant.name} (${tenant.slug})`,
    value: tenant.id,
  })),
)
const { ensureSelectedTenantWorkspace, selectTenantWorkspace, selectingTenantId } =
  useAdminTenantSelection()

const routeName = computed(() => String(route.name ?? ''))

const inferredBackRouteName = computed(() => {
  const name = routeName.value
  if (!name.includes('details')) {
    return null
  }

  const mapped = name.replace(/-details-page$/, '-page')
  if (mapped !== name && router.hasRoute(mapped)) {
    return mapped
  }

  return null
})

const showHeaderBackButton = computed(() => {
  const metaFlag = route.meta?.showHeaderBackButton
  if (metaFlag === false) {
    return false
  }

  if (metaFlag === true) {
    return true
  }

  return routeName.value.includes('details')
})

const onHeaderBack = () => {
  if (window.history.length > 1) {
    router.back()
    return
  }

  if (inferredBackRouteName.value) {
    void router.push({ name: inferredBackRouteName.value })
    return
  }

  void router.push({ name: 'app-dashboard' })
}

const onSelectTenant = (tenantId: number | null) => {
  const tenant =
    tenantStore.availableAdminTenants.find((item) => item.id === tenantId) ?? null

  if (!tenant) {
    return
  }

  void selectTenantWorkspace(tenant)
}

onMounted(() => {
  void (async () => {
    if (!tenantStore.availableAdminTenants.length && authStore.user?.email) {
      await tenantStore.fetchTenantsByMembership({
        email: authStore.user.email,
      })
    }

    await ensureSelectedTenantWorkspace()
  })()
})
</script>

<style scoped>
.app-context__title {
  overflow: hidden;
  font-size: clamp(1.2rem, 2vw, 1.7rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-layout__tenant-switcher {
  min-width: min(18rem, 48vw);
}

.app-header-back-btn {
  font-weight: 700;
  border: 1px solid var(--q-separator-color);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.72);
}
</style>
