import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'

export type ModuleKey =
  | 'order_management'
  | 'shipment'
  | 'inventory'
  | 'vendor'
  | 'products'
  | 'product_based_costing'
  | 'costing_file'
  | 'accounting'
  | 'invoice'

export type ModuleAction = 'view'
export type InteractiveScope = Extract<AuthScope, 'app' | 'shop'>

export interface ModuleRouteDefinition {
  scope: InteractiveScope
  title: string
  caption: string
  icon: string
  routeSegment: string
  requiredAction?: ModuleAction
}

export interface ModuleDefinition {
  key: ModuleKey
  name: string
  description: string
  routes: ModuleRouteDefinition[]
}

export const MODULE_REGISTRY: readonly ModuleDefinition[] = [
  {
    key: 'order_management',
    name: 'Order Management',
    description: 'Create, review, approve, and track order flow.',
    routes: [
      {
        scope: 'app',
        title: 'Orders',
        caption: 'Manage order intake and internal workflow',
        icon: 'receipt_long',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Build carts, place orders, and follow negotiation',
        icon: 'shopping_bag',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shipment',
    name: 'Shipment',
    description: 'Coordinate dispatch, logistics, and delivery status.',
    routes: [
      {
        scope: 'app',
        title: 'Shipment',
        caption: 'Track dispatch, handoff, and delivery progress',
        icon: 'local_shipping',
        routeSegment: 'shipment',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'inventory',
    name: 'Inventory',
    description: 'Monitor stock, availability, and inventory movement.',
    routes: [
      {
        scope: 'app',
        title: 'Inventory',
        caption: 'Review stock levels and inventory operations',
        icon: 'inventory_2',
        routeSegment: 'inventory',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'vendor',
    name: 'Vendor',
    description: 'Manage vendor records, sourcing, and supplier collaboration.',
    routes: [
      {
        scope: 'app',
        title: 'Vendors',
        caption: 'Manage suppliers and vendor operations',
        icon: 'storefront',
        routeSegment: 'vendors',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'products',
    name: 'Products',
    description: 'Manage the product catalog and product-level records.',
    routes: [
      {
        scope: 'app',
        title: 'Products',
        caption: 'Manage tenant product catalog',
        icon: 'inventory_2',
        routeSegment: 'products',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'product_based_costing',
    name: 'Product Based Costing',
    description: 'Support product-based costing files for internal and customer workflows.',
    routes: [
      {
        scope: 'app',
        title: 'Product Based Costing',
        caption: 'Manage product based costing files',
        icon: 'request_quote',
        routeSegment: 'product-based-costing',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Pre order',
        caption: 'Open customer-facing costing references',
        icon: 'request_quote',
        routeSegment: 'costing',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'costing_file',
    name: 'Costing File',
    description: 'Manage internal costing references and pricing preparation.',
    routes: [
      {
        scope: 'app',
        title: 'Pre order',
        caption: 'Prepare internal costing files and price support',
        icon: 'price_change',
        routeSegment: 'costing',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'accounting',
    name: 'Accounting',
    description: 'Handle accounting workflows tied to tenant operations.',
    routes: [
      {
        scope: 'app',
        title: 'Accounting',
        caption: 'Review accounting workflows and financial handoff',
        icon: 'account_balance',
        routeSegment: 'accounting',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'invoice',
    name: 'Invoice',
    description: 'Manage invoice creation, status, and reconciliation flow.',
    routes: [
      {
        scope: 'app',
        title: 'Invoices',
        caption: 'Create and review invoice activity',
        icon: 'description',
        routeSegment: 'invoices',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Invoices',
        caption: 'View customer-facing invoice records',
        icon: 'receipt',
        routeSegment: 'invoices',
        requiredAction: 'view',
      },
    ],
  },
] as const

export const MODULE_REGISTRY_KEYS = MODULE_REGISTRY.map((definition) => definition.key)

export const MODULE_REGISTRY_BY_KEY: Readonly<Record<ModuleKey, ModuleDefinition>> =
  Object.freeze(
    MODULE_REGISTRY.reduce(
      (accumulator, definition) => {
        accumulator[definition.key] = definition
        return accumulator
      },
      {} as Record<ModuleKey, ModuleDefinition>,
    ),
  )

export const getModuleDefinition = (moduleKey: ModuleKey) =>
  MODULE_REGISTRY_BY_KEY[moduleKey]

export const buildModuleRoutePath = ({
  scope,
  routeSegment,
  tenantSlug,
}: {
  scope: InteractiveScope
  routeSegment: string
  tenantSlug?: string | null | undefined
}) => {
  if (scope === 'shop') {
    return tenantSlug ? `/${tenantSlug}/shop/${routeSegment}` : `/shop/${routeSegment}`
  }

  return tenantSlug ? `/${tenantSlug}/app/${routeSegment}` : `/app/${routeSegment}`
}

export const getModuleRoutesForScope = (
  scope: InteractiveScope,
  options?: {
    tenantSlug?: string | null | undefined
  },
) =>
  MODULE_REGISTRY.flatMap((definition) =>
    definition.routes
      .filter((routeDefinition) => routeDefinition.scope === scope)
      .map((routeDefinition) => ({
        moduleKey: definition.key,
        moduleName: definition.name,
        to: buildModuleRoutePath({
          scope: routeDefinition.scope,
          routeSegment: routeDefinition.routeSegment,
          tenantSlug: options?.tenantSlug,
        }),
        ...routeDefinition,
      })),
  )
