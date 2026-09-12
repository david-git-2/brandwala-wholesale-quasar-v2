import { computed } from 'vue';

import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { roleMatchesAllowed, type AccessRole } from 'src/modules/auth/guards/accessGuard';
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';
import { hasTenantContextForScope, useModulePermissions } from './modulePermissions';
import { MODULE_REGISTRY, type ModuleKey } from './moduleRegistry';
import { buildNavLinksFromModuleHierarchy } from 'src/modules/featureCatalog/utils/moduleHierarchy';
import {
  buildSettingsNavLink,
  buildShopProcurementHubNavLinks,
  getProcurementFamilyModuleKeys,
  getReferenceFamilyModuleKeys,
  getShopOrderFamilyModuleKeys,
  mergeNavLinksByWeight,
  type WeightedWorkspaceLink,
} from './hubNavConfig';

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

const NAV_WEIGHT = {
  dashboard: 10,
  catalog: 40,
  reports: 50,
  tenants: 60,
  settings: 70,
  help: 80,
  kobaRetail: 40,
} as const;

type BaseWorkspaceLinkDefinition = {
  title: string;
  caption: string;
  icon: string;
  navWeight: number;
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
    navWeight: NAV_WEIGHT.dashboard,
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Create and govern businesses',
    icon: 'ph ph-buildings',
    navWeight: NAV_WEIGHT.tenants,
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/tenants',
  },
  {
    title: 'Feature Catalog',
    caption: 'Control modules and activation',
    icon: 'ph ph-archive-box',
    navWeight: NAV_WEIGHT.catalog,
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/modules',
  },
  {
    title: 'Global Reference',
    caption: 'Currencies, markets, payment methods, units',
    icon: 'ph ph-books',
    navWeight: NAV_WEIGHT.catalog,
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/reference',
  },
  {
    title: 'Super Admins',
    caption: 'Manage platform superadmin access',
    icon: 'ph ph-shield',
    navWeight: NAV_WEIGHT.settings,
    scopes: ['platform'],
    allowedRoles: ['superadmin'],
    route: () => '/platform/superadmins',
  },
  {
    title: 'Dashboard',
    caption: 'Internal activity and quick actions',
    icon: 'ph ph-chart-line-up',
    navWeight: NAV_WEIGHT.dashboard,
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard'),
  },
  {
    title: 'Tenants',
    caption: 'Open tenant details and assignments',
    icon: 'ph ph-buildings',
    navWeight: NAV_WEIGHT.tenants,
    scopes: ['app'],
    allowedRoles: ['admin', 'staff'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/tenants` : '/app/tenants'),
  },
  {
    title: 'Help Center',
    caption: 'How-to guides for your workspace',
    icon: 'ph ph-question',
    navWeight: NAV_WEIGHT.help,
    scopes: ['app'],
    allowedRoles: ['admin', 'staff', 'viewer'],
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/app/help` : '/app/help'),
  },
  {
    title: 'Home',
    caption: 'Your shops and orders that need you',
    icon: 'ph ph-squares-four',
    navWeight: NAV_WEIGHT.dashboard,
    scopes: ['shop'],
    allowedRoles: ['customer_admin', 'customer_manager', 'customer_staff'],
    requiresTenantContext: true,
    route: ({ tenantSlug }) => (tenantSlug ? `/${tenantSlug}/shop/dashboard` : '/shop/dashboard'),
  },
] as const;

const EXCLUDED_APP_MODULE_KEYS = new Set<ModuleKey>([
  ...getShopOrderFamilyModuleKeys(),
  ...getProcurementFamilyModuleKeys(),
  ...getReferenceFamilyModuleKeys(),
]);

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
}): WeightedWorkspaceLink[] => {
  if (!scope) {
    return [];
  }

  return WORKSPACE_NAV_REGISTRY.filter((definition) => {
    if (!definition.scopes.includes(scope)) {
      return false;
    }

    if (definition.allowedRoles && (!role || !roleMatchesAllowed(role, definition.allowedRoles))) {
      return false;
    }

    if (definition.requiresTenantContext && !hasTenantContextForScope({ scope, tenantId })) {
      return false;
    }

    return true;
  }).map((definition) => {
    const link: WeightedWorkspaceLink = {
      navWeight: definition.navWeight,
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

const toWeightedLink = (
  link: WorkspaceLink,
  navWeight: number,
): WeightedWorkspaceLink => ({
  ...link,
  navWeight,
});

export const useWorkspaceLinks = (scope: WorkspaceScope) => {
  const authStore = useAuthStore();
  const { accessibleModuleRoutes, getModuleAccess } = useModulePermissions();

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
      return mergeNavLinksByWeight(baseLinks, moduleLinks.map((link) => toWeightedLink(link, NAV_WEIGHT.catalog)));
    }

    const canView = (moduleKey: ModuleKey) => getModuleAccess(moduleKey, 'view').allowed;

    const filteredModuleRoutes = scopedModuleRouteDefinitions.filter(
      (routeDefinition) => !EXCLUDED_APP_MODULE_KEYS.has(routeDefinition.moduleKey),
    );

    const { hierarchyLinks, remainingRoutes } = buildNavLinksFromModuleHierarchy(
      filteredModuleRoutes,
      MODULE_REGISTRY,
    );

    const hasKobaRetailModuleAccess = filteredModuleRoutes.some(
      (routeDefinition) => routeDefinition.moduleKey === 'koba_retail',
    );

    const resolveModuleNavWeight = (moduleKey: ModuleKey): number => {
      if (moduleKey === 'reporting_treasury') {
        return NAV_WEIGHT.reports;
      }
      return NAV_WEIGHT.catalog;
    };

    const flatLinks = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey !== 'koba_retail')
      .map((routeDefinition) =>
        toWeightedLink(
          {
            title: routeDefinition.title,
            caption: routeDefinition.caption,
            icon: routeDefinition.icon,
            to: routeDefinition.to,
          },
          resolveModuleNavWeight(routeDefinition.moduleKey),
        ),
      );

    const kobaRetailChildren = remainingRoutes
      .filter((routeDefinition) => routeDefinition.moduleKey === 'koba_retail')
      .filter((routeDefinition) => {
        const role = authStore.matchedRole;
        const isAdminOrSuper =
          role === 'owner' || role === 'manager' || role === 'admin' || role === 'superadmin';
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

    const hierarchyWeightedLinks = hierarchyLinks.map((link) =>
      toWeightedLink(link, NAV_WEIGHT.catalog),
    );

    const kobaRetailGroup =
      hasKobaRetailModuleAccess && kobaRetailChildren.length > 0
        ? [
            toWeightedLink(
              {
                title: 'Koba Retail',
                caption: 'Koba Retail module',
                icon: 'ph ph-tote',
                children: kobaRetailChildren,
              },
              NAV_WEIGHT.kobaRetail,
            ),
          ]
        : [];

    const hubLinks = buildShopProcurementHubNavLinks(canView, authStore.tenantSlug);

    const settingsLink = buildSettingsNavLink(
      {
        role: authStore.matchedRole,
        isAdmin: authStore.access?.isAdmin,
        canView,
      },
      authStore.tenantSlug,
    );

    const settingsLinks = settingsLink ? [settingsLink] : [];

    return mergeNavLinksByWeight(
      baseLinks,
      hubLinks,
      flatLinks,
      kobaRetailGroup,
      hierarchyWeightedLinks,
      settingsLinks,
    );
  });

  return {
    links,
  };
};

export const useAppWorkspaceLinks = () => useWorkspaceLinks('app');
export const useShopWorkspaceLinks = () => useWorkspaceLinks('shop');
export const usePlatformWorkspaceLinks = () => useWorkspaceLinks('platform');
