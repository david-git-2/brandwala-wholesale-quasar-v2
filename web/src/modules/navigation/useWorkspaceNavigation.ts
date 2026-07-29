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
 * - `global_stock` and `inventory` (Tenant Stock) are separate module keys and separate links.
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
    title: 'Documentation',
    caption: 'Global platform & module manuals',
    icon: 'ph ph-book-open',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/documentation',
    target: '_blank',
  },
  {
    title: 'Help Center',
    caption: 'How-to guides for platform tools',
    icon: 'ph ph-question',
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/help',
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
    title: 'Documentation',
    caption: 'User guides and feature manuals',
    icon: 'ph ph-book-open',
    scopes: ['app'],
    allowedRoles: ['admin', 'staff', 'viewer'],
    route: ({ tenantSlug }) =>
      tenantSlug ? `/${tenantSlug}/app/documentation` : '/app/documentation',
    target: '_blank',
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
    title: 'Dashboard',
    caption: 'Current orders, approvals, and next actions',
    icon: 'ph ph-squares-four',
    scopes: ['shop'],
    allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
    requiresTenantContext: true,
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/shop/dashboard` : '/shop/dashboard'),
  },
  {
    title: 'Help Center',
    caption: 'Guides for ordering and tracking',
    icon: 'ph ph-question',
    scopes: ['shop'],
    allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
    requiresTenantContext: true,
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/shop/help` : '/shop/help'),
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
      const shopModuleLinks = scopedModuleRouteDefinitions.map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: routeDefinition.icon,
        to: routeDefinition.to,
      }));

      const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
        (routeDefinition) => routeDefinition.moduleKey === 'koba_retail',
      );

      if (!hasKobaRetailModuleAccess) {
        return [...baseLinks, ...shopModuleLinks];
      }

      const moduleLinksWithoutGrouped = scopedModuleRouteDefinitions
        .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: routeDefinition.icon,
          to: routeDefinition.to,
        }));

      const kobaRetailChildren = scopedModuleRouteDefinitions
        .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
        .map((routeDefinition) => ({
          title: routeDefinition.title,
          caption: routeDefinition.caption,
          icon: 'ph ph-caret-right',
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

    const hasProductsModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'products',
    );
    const hasKobaRetailModuleAccess = scopedModuleRouteDefinitions.some(
      (routeDefinition) =>
        routeDefinition.scope === 'app' && routeDefinition.moduleKey === 'koba_retail',
    );

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
      }));

    const productsChildren = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey === 'products')
      .map((routeDefinition) => ({
        title: routeDefinition.title,
        caption: routeDefinition.caption,
        icon: 'ph ph-caret-right',
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
        icon: 'ph ph-caret-right',
        to: routeDefinition.to,
      }));

    const groupedLinks = [
      ...flatLinks,
      ...(hasProductsModuleAccess
        ? [
            {
              title: 'Product',
              caption: 'Product module',
              icon: 'ph ph-archive-box',
              children: productsChildren,
            },
          ]
        : []),
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

    const baseLinksMapped = baseLinks.map((link) => {
      if (link.title === 'Access Control') {
        const basePath = authStore.tenantSlug
          ? `/${authStore.tenantSlug}/app/access-control`
          : '/app/access-control';
        return {
          title: 'Access Control',
          caption: link.caption,
          icon: link.icon,
          children: [
            {
              title: 'Modules',
              caption: 'Workspace features',
              icon: 'ph ph-puzzle-piece',
              to: `${basePath}/modules`,
            },
            {
              title: 'Roles',
              caption: 'Workspace roles',
              icon: 'ph ph-shield-check',
              to: `${basePath}/roles`,
            },
            {
              title: 'Team',
              caption: 'Workspace team',
              icon: 'ph ph-users',
              to: `${basePath}/team`,
            },
            {
              title: 'Customer Groups',
              caption: 'Workspace customer groups',
              icon: 'ph ph-users-three',
              to: `${basePath}/customer-groups`,
            },
            {
              title: 'Investor Access',
              caption: 'Workspace investor access',
              icon: 'ph ph-piggy-bank',
              to: `${basePath}/investors`,
            },
          ],
        };
      }
      return link;
    });

    return [...baseLinksMapped, ...groupedLinks];
  });

  return {
    links,
  };
};

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app');
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop');
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform');
