import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'

export type ModuleKey =
  | 'order_management'
  | 'shipment'
  | 'inventory'
  | 'shop_costing_file'
  | 'costing_file'
  | 'accounting'
  | 'invoice'

export type ModuleAction = 'view'

export interface ModuleRouteDefinition {
  scope: Extract<AuthScope, 'app' | 'shop'>
  title: string
  caption: string
  icon: string
  to: string
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
        to: '/app/orders',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Build carts, place orders, and follow negotiation',
        icon: 'shopping_bag',
        to: '/shop/orders',
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
        to: '/app/shipment',
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
        to: '/app/inventory',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_costing_file',
    name: 'Shop Costing File',
    description: 'Support customer-side costing visibility and pricing context.',
    routes: [
      {
        scope: 'shop',
        title: 'Shop Costing',
        caption: 'Open customer-facing costing references',
        icon: 'request_quote',
        to: '/shop/costing',
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
        title: 'Costing',
        caption: 'Prepare internal costing files and price support',
        icon: 'price_change',
        to: '/app/costing',
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
        to: '/app/accounting',
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
        to: '/app/invoices',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Invoices',
        caption: 'View customer-facing invoice records',
        icon: 'receipt',
        to: '/shop/invoices',
        requiredAction: 'view',
      },
    ],
  },
] as const

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

export const getModuleRoutesForScope = (
  scope: Extract<AuthScope, 'app' | 'shop'>,
) =>
  MODULE_REGISTRY.flatMap((definition) =>
    definition.routes
      .filter((routeDefinition) => routeDefinition.scope === scope)
      .map((routeDefinition) => ({
        moduleKey: definition.key,
        moduleName: definition.name,
        ...routeDefinition,
      })),
  )
