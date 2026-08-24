import { computed } from 'vue';

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { AccessRole } from 'src/modules/auth/guards/accessGuard';
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';
import { hasTenantContextForScope, useModulePermissions } from './modulePermissions';
import { MODULE_REGISTRY } from './moduleRegistry';
import { buildNavLinksFromModuleHierarchy } from 'src/modules/featureCatalog/utils/moduleHierarchy';

/**
 * Sidebar nav grouping for the app scope.
 *
 * NAV SEPARATION (do not violate):
 * - Each enabled feature module gets its own sidebar link (flat or domain group).
 * - Do NOT nest unrelated modules under a shared parent (e.g. no "Global" mega-menu).
 * - `global_stock` (Warehouse) and `inventory` (Stock) are separate module keys and separate links.
 * - Domain groups (Invoices, Accounting, Commerce, …) only contain routes from that same module family.
 */

type WorkspaceScope = AuthScope;

type BaseWorkspaceLinkDefinition = {
  title: string;
  caption: string;
  icon: string;
  route: (context: { scope: WorkspaceScope; tenantSlug: string | null }) => string;
  scopes: readonly WorkspaceScope[];
  allowedRoles?: readonly AccessRole[];
  requiresTenantContext?: boolean;
  target?: string;
};

const WORKSPACE_NAV_REGISTRY: readonly BaseWorkspaceLinkDefinition[] = [
  {
    title: 'Dashboard',
    caption: 'Platform pulse and rollout status',
    icon: 'ph ph-squares-four',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Create and govern businesses',
    icon: 'ph ph-buildings',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/tenants',
  },
  {
    title: 'Feature Catalog',
    caption: 'Control modules and activation',
    icon: 'ph ph-archive-box',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/modules',
  },
  {
    title: 'Global Reference',
    caption: 'Currencies, markets, payment methods, units',
    icon: 'ph ph-books',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/reference',
  },
  {
    title: 'Super Admins',
    caption: 'Manage platform superadmin access',
    icon: 'ph ph-shield',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/superadmins',
  },
  {
    title: 'Dashboard',
    caption: 'Internal activity and quick actions',
    icon: 'ph ph-chart-line-up',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard'),
  },
  {
    title: 'Tenants',
    caption: 'Open tenant details and assignments',
    icon: 'ph ph-buildings',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/tenants` : '/app/tenants'),
  },
  {
    title: 'Access Control',
    caption: 'Govern roles, members & features',
    icon: 'ph ph-shield-check',
    scopes: ['app'],
    allowedRoles: ['admin'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/access-control` : '/app/access-control',
  },
  {
    title: 'Help Center',
    caption: 'How-to guides for your workspace',
    icon: 'ph ph-question',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff', 'viewer'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/help` : '/app/help'),
  },
  {
    title: 'Home',
    caption: 'Your shops and orders that need you',
    icon: 'ph ph-squares-four',
    scopes: ['shop'],
    allowedRoles: ['customer_admin', 'customer_manager', 'customer_staff'],
    requiresTenantContext: true,
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/shop/dashboard` : '/shop/dashboard'),
  },
] as const;

const getBaseWorkspaceLinks = ({
  scope,
  role,
  tenantId,
  tenantSlug,
}: {
  scope: WorkspaceScope | null;
  role: AccessRole | null | undefined;
  tenantId: number | null | undefined;
  tenantSlug: string | null;
}): WorkspaceLink[] => {
  if (!scope) {
    return [];
  }

  return WORKSPACE_NAV_REGISTRY.filter((definition) => {
    if (!definition.scopes.includes(scope)) {
      return false;
    }

    if (definition.allowedRoles && (!role || !definition.allowedRoles.includes(role))) {
      return false;
    }

    if (definition.requiresTenantContext && !hasTenantContextForScope({ scope, tenantId })) {
      return false;
    }

    return true;
  }).map((definition) => {
    const link: WorkspaceLink = {
      title: definition.title,
      caption: definition.caption,
      icon: definition.icon,
      to: definition.route({ scope, tenantSlug }),
    };
    if (definition.target) {
      link.target = definition.target;
    }
    return link;
  });
};

export const useWorkspaceLinks = (scope: WorkspaceScope) => {
  const authStore = useAuthStore();
  const { accessibleModuleRoutes } = useModulePermissions();

  const links = computed<WorkspaceLink[]>(() => {
    const baseLinks = getBaseWorkspaceLinks({
      scope,
      role: authStore.matchedRole,
      tenantId: authStore.tenantId,
      tenantSlug: authStore.tenantSlug,
    });

    const scopedModuleRouteDefinitions = accessibleModuleRoutes.value.filter(
      (routeDefinition) => routeDefinition.scope === scope,
    );

    const moduleLinks = scopedModuleRouteDefinitions.map((routeDefinition) => ({
      title: routeDefinition.title,
      caption: routeDefinition.caption,
      icon: routeDefinition.icon,
      to: routeDefinition.to,
    }));

    if (scope === 'shop') {
      const shopNavRoutes = scopedModuleRouteDefinitions.filter(
        (routeDefinition) => routeDefinition.moduleKey !== 'shop_cart',
      );

      const shopModuleLinks = shopNavRoutes.map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }));

      const hasKobaRetailModuleAccess = shopNavRoutes.some(
        (routeDefinition) => routeDefinition.moduleKey === 'koba_retail',
      );

      if (!hasKobaRetailModuleAccess) {
        return [...baseLinks, ...shopModuleLinks];
      }

      const moduleLinksWithoutGrouped = shopNavRoutes
        .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: routeDefinition.icon,
          to: routeDefinition.to,
        }));

      const kobaRetailChildren = shopNavRoutes
        .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: routeDefinition.icon,
          to: routeDefinition.to,
        }));

      const groupedLinks = [
        ...moduleLinksWithoutGrouped,
        {
          title: 'Koba Retail',
          caption: 'Koba Retail module',
          icon: 'ph ph-tote',
          children: kobaRetailChildren,
        },
      ];

      return [...baseLinks, ...groupedLinks];
    }

    if (scope !== 'app') {
      return [...baseLinks, ...moduleLinks];
    }

    const { hierarchyLinks, remainingRoutes } = buildNavLinksFromModuleHierarchy(
      scopedModuleRouteDefinitions,
      MODULE_REGISTRY,
    );

    const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'koba_retail',
    );

    const flatLinks = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }));

    const kobaRetailChildren = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
      .filter((routeDefinition) => {
        const role = authStore.matchedRole;
        const isAdminOrSuper = role === 'admin' || role === 'superadmin';
        if (isAdminOrSuper && routeDefinition.title === 'Cart') {
          return false;
        }
        return true;
      })
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }));

    const groupedLinks = [
      ...flatLinks,
      ...(hasKobaRetailModuleAccess
        ? [
            {
              title: 'Koba Retail',
              caption: 'Koba Retail module',
              icon: 'ph ph-tote',
              children: kobaRetailChildren,
            },
          ]
        : []),
      ...hierarchyLinks,
    ];

    return [...baseLinks, ...groupedLinks];
  });

  return {
    links,
  };
};

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app');
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop');
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform');
