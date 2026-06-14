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
      <!-- Mobile Only: Three Dots (Dropdown Menu) -->
      <div v-if="$q.screen.xs" class="row items-center">
        <q-btn
          flat
          round
          dense
          color="primary"
          icon="more_vert"
        >
          <q-menu style="min-width: 180px">
            <q-list class="q-py-xs">
              <q-item-label header class="text-uppercase text-weight-bold text-grey-7" style="font-size: 10px; letter-spacing: 0.1em;">Quick Actions</q-item-label>

              <!-- Task search on mobile -->
              <q-item v-if="hasTasksModule" clickable @click="searchDialogOpen = true">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px;">
                  <q-icon name="assignment" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Search Tasks</q-item-section>
              </q-item>

              <!-- Stock search on mobile -->
              <q-item v-if="hasInventoryModule" clickable @click="stockSearchDialogOpen = true">
                <q-item-section avatar class="q-pr-none" style="min-width: 32px;">
                  <q-icon name="inventory_2" size="sm" color="primary" />
                </q-item-section>
                <q-item-section>Search Stock</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>

      <!-- Desktop: Actions are empty here, placed in header-secondary instead -->
      <div v-else class="row items-center q-gutter-sm">
      </div>

      <TaskSearchDialog v-model="searchDialogOpen" />
      <StockSearchDialog v-model="stockSearchDialogOpen" />
    </template>

    <template #header-secondary>
      <div class="row items-center justify-end full-width q-px-sm">
        <div class="row items-center q-gutter-sm col-xs-12 col-sm-auto justify-end">
          <q-btn
            v-if="hasTasksModule"
            flat
            no-caps
            dense
            size="sm"
            color="primary"
            icon="assignment"
            label="Search Tasks"
            class="pill-btn slim-btn q-px-sm gt-xs"
            @click="searchDialogOpen = true"
          />

          <q-btn
            v-if="hasInventoryModule"
            flat
            no-caps
            dense
            size="sm"
            color="primary"
            icon="inventory_2"
            label="Search Stock"
            class="pill-btn slim-btn q-px-sm gt-xs"
            @click="stockSearchDialogOpen = true"
          />

          <q-btn-dropdown
            v-if="tenantOptions.length"
            outline
            no-caps
            dense
            size="sm"
            color="primary"
            class="tenant-dropdown-btn pill-btn q-px-md col-xs-12 col-sm-auto"
            :label="selectedTenantLabel"
            :loading="selectingTenantId !== null"
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
          </q-btn-dropdown>
        </div>
      </div>
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
import StockSearchDialog from 'src/modules/inventory/components/StockSearchDialog.vue'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const route = useRoute()
const router = useRouter()
const { links } = useAppWorkspaceLinks()

const searchDialogOpen = ref(false)
const stockSearchDialogOpen = ref(false)
const hasTasksModule = computed(() => authStore.activeModuleKeys.includes('tasks'))
const hasInventoryModule = computed(() => authStore.activeModuleKeys.includes('inventory'))
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 26px;
  padding-left: 8px;
  padding-right: 8px;
}

.tenant-dropdown-btn {
  font-weight: 600;
  font-size: 0.78rem;
  min-height: 26px;
}

@media (max-width: 600px) {
  .app-context__title {
    max-width: 100px;
  }
  .app-layout__tenant-chip {
    max-width: 90px !important;
  }
  .tenant-dropdown-btn {
    width: 100%;
  }
}
</style>
