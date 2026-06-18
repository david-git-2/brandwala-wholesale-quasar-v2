import { computed } from 'vue'

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import { hasTenantContextForScope, useModulePermissions } from './modulePermissions'

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

    if (scope === 'shop') {
      const hasCommerceCart = scopedModuleRouteDefinitions.some(
        (routeDefinition) => routeDefinition.moduleKey === 'commerce_cart',
      )

      const filteredRouteDefinitions = hasCommerceCart
        ? scopedModuleRouteDefinitions.filter(
            (routeDefinition) => routeDefinition.moduleKey !== 'cart',
          )
        : scopedModuleRouteDefinitions

      const hasKobaRetailModuleAccess = filteredRouteDefinitions.some(
        (routeDefinition) => routeDefinition.moduleKey === 'koba_retail',
      )

      const shopModuleLinks = filteredRouteDefinitions.map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))

      if (!hasKobaRetailModuleAccess) {
        return [...baseLinks, ...shopModuleLinks]
      }

      const moduleLinksWithoutGrouped = filteredRouteDefinitions
        .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: routeDefinition.icon,
          to: routeDefinition.to,
        }))

      const kobaRetailChildren = filteredRouteDefinitions
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

    const hasStoreModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'store',
    )
    const hasInvoiceModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'invoice',
    )
    const hasAccountingModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'accounting',
    )
    const hasInvestorModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'investor',
    )
    const hasProductsModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'products',
    )
    const hasCommerceShopModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'commerce_shop',
    )
    const hasCommerceOrderModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'commerce_order',
    )
    const hasCommerceInvoiceModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'commerce_invoice',
    )
    const hasCommerceAccountingModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'commerce_accounting',
    )
    const hasCommerceCartModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.moduleKey === 'commerce_cart',
    )
    const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'koba_retail',
    )
    if (
      !hasStoreModuleAccess &&
      !hasInvoiceModuleAccess &&
      !hasAccountingModuleAccess &&
      !hasInvestorModuleAccess &&
      !hasProductsModuleAccess &&
      !hasCommerceShopModuleAccess &&
      !hasCommerceOrderModuleAccess &&
      !hasCommerceInvoiceModuleAccess &&
      !hasCommerceAccountingModuleAccess &&
      !hasCommerceCartModuleAccess &&
      !hasKobaRetailModuleAccess
    ) {
      return [...baseLinks, ...moduleLinks]
    }

    const moduleLinksWithoutGroupedModules = scopedModuleRouteDefinitions
      .filter(
        (routeDefinition) =>
          routeDefinition.moduleKey !== 'store' &&
          routeDefinition.moduleKey !== 'invoice' &&
          routeDefinition.moduleKey !== 'accounting' &&
          routeDefinition.moduleKey !== 'investor' &&
          routeDefinition.moduleKey !== 'products' &&
          routeDefinition.moduleKey !== 'commerce_shop' &&
          routeDefinition.moduleKey !== 'commerce_order' &&
          routeDefinition.moduleKey !== 'commerce_invoice' &&
          routeDefinition.moduleKey !== 'commerce_accounting' &&
          routeDefinition.moduleKey !== 'koba_retail',
      )
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }))
    const productsChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'products')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const investorChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'investor')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const invoiceChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'invoice')
      .map((routeDefinition) => ({
        title:
          routeDefinition.title === 'Invoices'
            ? 'Invoice Management'
            : routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const accountingChildren = scopedModuleRouteDefinitions
      .filter(
        (routeDefinition) =>
          routeDefinition.moduleKey === 'accounting' &&
          routeDefinition.title !== 'Accounting',
      )
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const commerceShopChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'commerce_shop')
      .map((routeDefinition) => ({
        title:
          routeDefinition.title === 'Commerce Shop Manage'
            ? 'Manage Store'
            : routeDefinition.title === 'Commerce Shop Access'
              ? 'Manage Access'
              : routeDefinition.title === 'Commerce Shop Products'
                ? 'Store Products'
                : routeDefinition.title === 'Commerce Shop Pricing'
                  ? 'Product Pricing'
                  : routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const commerceInvoiceChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'commerce_invoice')
      .map((routeDefinition) => ({
        title:
          routeDefinition.title === 'Commerce Invoices'
            ? 'Invoice Management'
            : routeDefinition.title === 'Commerce Billing Profiles'
              ? 'Billing Profiles'
              : routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const commerceOrderChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'commerce_order')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const commerceAccountingChildren = scopedModuleRouteDefinitions
      .filter((routeDefinition) => routeDefinition.moduleKey === 'commerce_accounting')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'chevron_right',
        to: routeDefinition.to,
      }))
    const kobaRetailChildren = scopedModuleRouteDefinitions
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
    const activeTenantSlug = tenantStore.selectedTenantSlug ?? authStore.tenantSlug
    const tenantPrefix = activeTenantSlug ? `/${activeTenantSlug}` : ''

    const groupedLinks = [
      ...moduleLinksWithoutGroupedModules,
      ...(hasInvestorModuleAccess
        ? [
            {
              title: 'Investor',
              caption: 'Investor module',
              icon: 'groups',
              children: investorChildren,
            },
          ]
        : []),
      ...(hasInvoiceModuleAccess
        ? [
            {
              title: 'Invoices',
              caption: 'Invoice module',
              icon: 'description',
              children: invoiceChildren,
            },
          ]
        : []),
      ...(hasAccountingModuleAccess
        ? [
            {
              title: 'Accounting',
              caption: 'Accounting module',
              icon: 'account_balance',
              children: accountingChildren,
            },
          ]
        : []),
      ...(hasStoreModuleAccess
        ? [
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
        : []),
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
      ...(hasCommerceShopModuleAccess
        ? [
            {
              title: 'Commerce Shop',
              caption: 'Commerce shop management',
              icon: 'storefront',
              children: commerceShopChildren,
            },
          ]
        : []),
      ...(hasCommerceOrderModuleAccess
        ? [
            {
              title: 'Commerce Orders',
              caption: 'Commerce order module',
              icon: 'receipt_long',
              children: commerceOrderChildren,
            },
          ]
        : []),
      ...(hasCommerceInvoiceModuleAccess
        ? [
            {
              title: 'Commerce Invoices',
              caption: 'Commerce invoice module',
              icon: 'description',
              children: commerceInvoiceChildren,
            },
          ]
        : []),
      ...(hasCommerceAccountingModuleAccess
        ? [
            {
              title: 'Commerce Accounting',
              caption: 'Commerce accounting module',
              icon: 'account_balance',
              children: commerceAccountingChildren,
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
    ]

    return [
      ...baseLinks,
      ...groupedLinks,
    ]
  })

  return {
    links,
  }
}

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app')
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop')
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform')
