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
        <div v-if="headerTitle" class="app-context__title">
          {{ headerTitle }}
        </div>
      </div>
    </template>

    <template #header-extra>
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="hasTasksModule"
          flat
          round
          dense
          color="primary"
          icon="search"
          @click="searchDialogOpen = true"
        >
          <q-tooltip>Search Tasks Cross-Tenants</q-tooltip>
        </q-btn>

        <q-chip
          v-if="tenantOptions.length"
          clickable
          outline
          color="primary"
          text-color="primary"
          class="app-layout__tenant-chip"
        >
          <q-spinner
            v-if="selectingTenantId !== null"
            size="14px"
            color="primary"
            class="q-mr-xs"
          />
          <span class="ellipsis">{{ selectedTenantLabel }}</span>
          <q-icon name="expand_more" size="16px" class="q-ml-xs" />

          <q-menu
            v-model="tenantMenuOpen"
            anchor="bottom right"
            self="top right"
          >
            <q-list style="min-width: 260px">
              <q-item
                v-for="option in tenantOptions"
                :key="option.value"
                clickable
                :active="option.value === selectedTenantId"
                active-class="bg-primary text-white"
                @click="onSelectTenant(option.value)"
              >
                <q-item-section>
                  <q-item-label>{{ option.label }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>
      </div>

      <TaskSearchDialog v-model="searchDialogOpen" />
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAppWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'
import { useAdminTenantSelection } from 'src/modules/tenant/composables/useAdminTenantSelection'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import TaskSearchDialog from 'src/modules/tasks/components/TaskSearchDialog.vue'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const route = useRoute()
const router = useRouter()
const { links } = useAppWorkspaceLinks()

const searchDialogOpen = ref(false)
const hasTasksModule = computed(() => authStore.activeModuleKeys.includes('tasks'))
const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/app/login` : '/app/login',
)
const selectedTenantId = computed(() => tenantStore.selectedTenantId)
const tenantOptions = computed(() =>
  tenantStore.availableAdminTenants.map((tenant) => ({
    label: tenant.name,
    value: tenant.id,
  })),
)
const tenantMenuOpen = ref(false)
const selectedTenantLabel = computed(() => {
  const selectedOption =
    tenantOptions.value.find((option) => option.value === selectedTenantId.value) ?? null

  return selectedOption?.label ?? 'Select tenant'
})
const { ensureSelectedTenantWorkspace, selectTenantWorkspace, selectingTenantId } =
  useAdminTenantSelection()

const routeName = computed(() => String(route.name ?? ''))
const routeMetaTitle = computed(() =>
  typeof route.meta?.title === 'string' ? route.meta.title.trim() : '',
)
const routeMetaHeaderTitle = computed(() =>
  typeof route.meta?.headerTitle === 'string' ? route.meta.headerTitle.trim() : '',
)

const prettifyRouteName = (name: string) =>
  name
    .replace(/-(page|details)$/g, '')
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')

const headerTitle = computed(() => {
  if (routeMetaHeaderTitle.value) {
    return routeMetaHeaderTitle.value
  }

  if (routeMetaTitle.value) {
    return routeMetaTitle.value
  }

  if (routeName.value) {
    return prettifyRouteName(routeName.value)
  }

  return 'App'
})

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
  tenantMenuOpen.value = false

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
  font-size: clamp(0.92rem, 1.35vw, 1.15rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-layout__tenant-chip {
  max-width: min(21rem, 58vw);
  font-weight: 600;
  border-radius: 8px;
}

.app-header-back-btn {
  font-weight: 700;
  border: 1px solid var(--q-separator-color);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.72);
}
</style>
