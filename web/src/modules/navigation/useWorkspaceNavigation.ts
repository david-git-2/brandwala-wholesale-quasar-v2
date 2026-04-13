import { computed } from 'vue'

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import { hasTenantContextForScope, useModulePermissions } from './modulePermissions'

type WorkspaceScope = AuthScope

type BaseWorkspaceLinkDefinition = {
  title: string
  caption: string
  icon: string
  route: (context: {
    scope: WorkspaceScope
    tenantSlug: string | null
  }) => string
  scopes: readonly WorkspaceScope[]
  allowedRoles?: readonly AccessRole[]
  requiresTenantContext?: boolean
}

const WORKSPACE_NAV_REGISTRY: readonly BaseWorkspaceLinkDefinition[] = [
  {
    title: 'Dashboard',
    caption: 'Platform pulse and rollout status',
    icon: 'space_dashboard',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Create and govern businesses',
    icon: 'apartment',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/tenants',
  },
  {
    title: 'Feature Catalog',
    caption: 'Control modules and activation',
    icon: 'inventory_2',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/modules',
  },
  {
    title: 'Markets',
    caption: 'Manage ISO market catalog',
    icon: 'public',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/markets',
  },
  {
    title: 'Super Admins',
    caption: 'Manage platform superadmin access',
    icon: 'shield',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/superadmins',
  },
  {
    title: 'Dashboard',
    caption: 'Internal activity and quick actions',
    icon: 'insights',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Open tenant details and assignments',
    icon: 'domain',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/tenants` : '/app/tenants',
  },
  {
    title: 'Dashboard',
    caption: 'Current orders, approvals, and next actions',
    icon: 'shopping_bag',
    scopes: ['shop'],
    allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
    requiresTenantContext: true,
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/shop/dashboard` : '/shop/dashboard',
  },
] as const

const getBaseWorkspaceLinks = ({
  scope,
  role,
  tenantId,
  tenantSlug,
}: {
  scope: WorkspaceScope | null
  role: AccessRole | null | undefined
  tenantId: number | null | undefined
  tenantSlug: string | null
}): WorkspaceLink[] => {
  if (!scope) {
    return []
  }

  return WORKSPACE_NAV_REGISTRY.filter((definition) => {
    if (!definition.scopes.includes(scope)) {
      return false
    }

    if (definition.allowedRoles && (!role || !definition.allowedRoles.includes(role))) {
      return false
    }

    if (
      definition.requiresTenantContext &&
      !hasTenantContextForScope({ scope, tenantId })
    ) {
      return false
    }

    return true
  }).map((definition) => ({
    title: definition.title,
    caption: definition.caption,
    icon: definition.icon,
    to: definition.route({ scope, tenantSlug }),
  }))
}

export const useWorkspaceLinks = (scope: WorkspaceScope) => {
  const authStore = useAuthStore()
  const tenantStore = useTenantStore()
  const { accessibleModuleRoutes } = useModulePermissions()

  const links = computed<WorkspaceLink[]>(() => {
    const baseLinks = getBaseWorkspaceLinks({
      scope,
      role: authStore.matchedRole,
      tenantId: authStore.tenantId,
      tenantSlug: authStore.tenantSlug,
    })

    const scopedModuleRouteDefinitions = accessibleModuleRoutes.value.filter(
      (routeDefinition) => routeDefinition.scope === scope,
    )

    const moduleLinks = scopedModuleRouteDefinitions
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))

    if (scope !== 'app') {
      return [...baseLinks, ...moduleLinks]
    }

    const hasStoreModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'store',
    )

    if (!hasStoreModuleAccess) {
      return [...baseLinks, ...moduleLinks]
    }

    const moduleLinksWithoutStore = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey !== 'store')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))
    const activeTenantSlug = tenantStore.selectedTenantSlug ?? authStore.tenantSlug
    const tenantPrefix = activeTenantSlug ? `/${activeTenantSlug}` : ''

    return [
      ...baseLinks,
      ...moduleLinksWithoutStore,
      {
        title: 'Stores',
        caption: 'Store module',
        icon: 'store',
        children: [
          {
            title: 'Manage Store',
            caption: 'Store module',
            icon: 'chevron_right',
            to: `${tenantPrefix}/app/stores/manage-store`,
          },
          {
            title: 'Manage Access',
            caption: 'Store module',
            icon: 'chevron_right',
            to: `${tenantPrefix}/app/stores/manage-access`,
          },
          {
            title: 'Store Products',
            caption: 'Store module',
            icon: 'chevron_right',
            to: `${tenantPrefix}/app/stores/store-products`,
          },
        ],
      },
    ]
  })

  return {
    links,
  }
}

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app')
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop')
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform')
