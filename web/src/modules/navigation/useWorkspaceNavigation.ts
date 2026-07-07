import { computed } from 'vue'

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import { hasTenantContextForScope, useModulePermissions } from './modulePermissions'
import { MODULE_REGISTRY } from './moduleRegistry'
import { buildNavLinksFromModuleHierarchy } from 'src/modules/featureCatalog/utils/moduleHierarchy'

/**
 * Sidebar nav grouping for the app scope.
 *
 * NAV SEPARATION (do not violate):
 * - Each enabled feature module gets its own sidebar link (flat or domain group).
 * - Do NOT nest unrelated modules under a shared parent (e.g. no "Global" mega-menu).
 * - `global_stock` and `inventory` (Tenant Stock) are separate module keys and separate links.
 * - Domain groups (Invoices, Accounting, Commerce, …) only contain routes from that same module family.
 */

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
  target?: string
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
    title: 'Global Reference',
    caption: 'Currencies, markets, payment methods, units',
    icon: 'library_books',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/reference',
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
    title: 'Documentation',
    caption: 'Global platform & module manuals',
    icon: 'menu_book',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/documentation',
    target: '_blank',
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
    title: 'Access Control',
    caption: 'Govern roles, members & features',
    icon: 'admin_panel_settings',
    scopes: ['app'],
    allowedRoles: ['admin'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/access-control` : '/app/access-control',
  },
  {
    title: 'Documentation',
    caption: 'User guides and feature manuals',
    icon: 'menu_book',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff', 'viewer'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/documentation` : '/app/documentation',
    target: '_blank',
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
  }).map((definition) => {
    const link: WorkspaceLink = {
      title: definition.title,
      caption: definition.caption,
      icon: definition.icon,
      to: definition.route({ scope, tenantSlug }),
    }
    if (definition.target) {
      link.target = definition.target
    }
    return link
  })
}

export const useWorkspaceLinks = (scope: WorkspaceScope) => {
  const authStore = useAuthStore()
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

    if (scope === 'shop') {
      const shopModuleLinks = scopedModuleRouteDefinitions.map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))

      const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
        (routeDefinition) => routeDefinition.moduleKey === 'koba_retail',
      )

      if (!hasKobaRetailModuleAccess) {
        return [...baseLinks, ...shopModuleLinks]
      }

      const moduleLinksWithoutGrouped = scopedModuleRouteDefinitions
        .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: routeDefinition.icon,
          to: routeDefinition.to,
        }))

      const kobaRetailChildren = scopedModuleRouteDefinitions
        .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: 'chevron_right',
          to: routeDefinition.to,
        }))

      const groupedLinks = [
        ...moduleLinksWithoutGrouped,
        {
          title: 'Koba Retail',
          caption: 'Koba Retail module',
          icon: 'shopping_bag',
          children: kobaRetailChildren,
        },
      ]

      return [...baseLinks, ...groupedLinks]
    }

    if (scope !== 'app') {
      return [...baseLinks, ...moduleLinks]
    }

    const { hierarchyLinks, remainingRoutes } = buildNavLinksFromModuleHierarchy(
      scopedModuleRouteDefinitions,
      MODULE_REGISTRY,
    )

    const hasProductsModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'products',
    )
    const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'koba_retail',
    )

    const flatLinks = remainingRoutes
      .filter(
        (routeDefinition) =>
          routeDefinition.moduleKey !== 'products' && routeDefinition.moduleKey !== 'koba_retail',
      )
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))

    const productsChildren = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey === 'products')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))

    const kobaRetailChildren = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
      .filter((routeDefinition) => {
        const role = authStore.matchedRole
        const isAdminOrSuper = role === 'admin' || role === 'superadmin'
        if (isAdminOrSuper && routeDefinition.title === 'Cart') {
          return false
        }
        return true
      })
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))

    const groupedLinks = [
      ...flatLinks,
      ...(hasProductsModuleAccess
        ? [
            {
              title: 'Product',
              caption: 'Product module',
              icon: 'inventory_2',
              children: productsChildren,
            },
          ]
        : []),
      ...(hasKobaRetailModuleAccess
        ? [
            {
              title: 'Koba Retail',
              caption: 'Koba Retail module',
              icon: 'shopping_bag',
              children: kobaRetailChildren,
            },
          ]
        : []),
      ...hierarchyLinks,
    ]

    const baseLinksMapped = baseLinks.map((link) => {
      if (link.title === 'Access Control') {
        const basePath = authStore.tenantSlug ? `/${authStore.tenantSlug}/app/access-control` : '/app/access-control'
        return {
          title: 'Access Control',
          caption: link.caption,
          icon: link.icon,
          children: [
            {
              title: 'Modules',
              caption: 'Workspace features',
              icon: 'extension',
              to: `${basePath}/modules`,
            },
            {
              title: 'Roles',
              caption: 'Workspace roles',
              icon: 'admin_panel_settings',
              to: `${basePath}/roles`,
            },
            {
              title: 'Team',
              caption: 'Workspace team',
              icon: 'manage_accounts',
              to: `${basePath}/team`,
            },
            {
              title: 'Customer Groups',
              caption: 'Workspace customer groups',
              icon: 'groups',
              to: `${basePath}/customer-groups`,
            },
            {
              title: 'Investor Access',
              caption: 'Workspace investor access',
              icon: 'savings',
              to: `${basePath}/investors`,
            },
          ],
        }
      }
      return link
    })

    return [...baseLinksMapped, ...groupedLinks]
  })

  return {
    links,
  }
}

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app')
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop')
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform')
