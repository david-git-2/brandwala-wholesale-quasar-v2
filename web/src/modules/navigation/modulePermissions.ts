import { computed } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import {
  getModuleRoutesForScope,
  type InteractiveScope,
  type ModuleAction,
  type ModuleKey,
} from './moduleRegistry'

type ModulePermissionMatrix = Readonly<
  Record<AccessRole, Readonly<Partial<Record<ModuleKey, readonly ModuleAction[]>>>>
>

const NO_ACCESS: readonly ModuleAction[] = []

const MODULE_PERMISSION_MATRIX: ModulePermissionMatrix = {
  superadmin: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: ['view'],
    commerce_shop: NO_ACCESS,
    commerce_order: NO_ACCESS,
    commerce_invoice: NO_ACCESS,
    commerce_accounting: ['view'],
    commerce_cart: NO_ACCESS,
    investor: ['view'],
    vendor: ['view'],
    products: ['view'],
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    store: NO_ACCESS,
    cart: NO_ACCESS,
    accounting: ['view'],
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: ['view'],
    tasks: ['view'],
    thrift_stock: ['view'],
    thrift_shipment: ['view'],
    thrift_box: ['view'],
    thrift_shelf: ['view'],
    thrift_barcode: ['view'],
    thrift_category: ['view'],
    thrift_type: ['view'],
    thrift_settings: ['view'],
    global_reference: NO_ACCESS,
    global_reference_currency: ['view'],
    global_reference_market: ['view'],
    global_reference_payment_method: ['view'],
    global_reference_unit_of_measure: ['view'],
    global_shipment: ['view'],
    global_stock: ['view'],
    global_invoice: ['view'],
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: ['view'],
    global_investor_shipment: ['view'],
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: ['view'],
    recipient_profile: ['view'],
    invoice_brand: ['view'],
    reporting_treasury: NO_ACCESS,
    payments: ['view'],
    invoice_reports: ['view'],
    shipment_reports: ['view'],
    billing_balances: ['view'],
    parent_dashboard: ['view'],
    investor_reports: ['view'],
    investor_capital: NO_ACCESS,
    investor_profiles: ['view'],
    investor_capital_ledger: ['view'],
    investor_shipment_share: ['view'],
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: NO_ACCESS,
    shop_cart: NO_ACCESS,
    shop_order_mgmt: NO_ACCESS,
    shop_fulfillment: NO_ACCESS,
  },
  admin: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: ['view'],
    commerce_shop: ['view'],
    commerce_order: ['view'],
    commerce_invoice: ['view'],
    commerce_accounting: ['view'],
    commerce_cart: NO_ACCESS,
    investor: ['view'],
    vendor: ['view'],
    products: ['view'],
    product_based_costing: ['view'],
    costing_file: ['view'],
    store: ['view'],
    cart: NO_ACCESS,
    accounting: ['view'],
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: ['view'],
    tasks: ['view'],
    thrift_stock: ['view'],
    thrift_shipment: ['view'],
    thrift_box: ['view'],
    thrift_shelf: ['view'],
    thrift_barcode: ['view'],
    thrift_category: ['view'],
    thrift_type: ['view'],
    thrift_settings: ['view'],
    global_reference: NO_ACCESS,
    global_reference_currency: ['view'],
    global_reference_market: ['view'],
    global_reference_payment_method: ['view'],
    global_reference_unit_of_measure: ['view'],
    global_shipment: ['view'],
    global_stock: ['view'],
    global_invoice: ['view'],
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: ['view'],
    global_investor_shipment: ['view'],
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: ['view'],
    recipient_profile: ['view'],
    invoice_brand: ['view'],
    reporting_treasury: NO_ACCESS,
    payments: ['view'],
    invoice_reports: ['view'],
    shipment_reports: ['view'],
    billing_balances: ['view'],
    parent_dashboard: ['view'],
    investor_reports: ['view'],
    investor_capital: NO_ACCESS,
    investor_profiles: ['view'],
    investor_capital_ledger: ['view'],
    investor_shipment_share: ['view'],
    shop_order: NO_ACCESS,
    shop_config: ['view'],
    shop_permissions: ['view'],
    shop_pricing: ['view'],
    shop_storefront: NO_ACCESS,
    shop_cart: NO_ACCESS,
    shop_order_mgmt: ['view'],
    shop_fulfillment: ['view'],
  },
  staff: {
    order_management: ['view'],
    commerce_shop: ['view'],
    commerce_order: ['view'],
    commerce_invoice: ['view'],
    commerce_accounting: NO_ACCESS,
    commerce_cart: NO_ACCESS,
    investor: ['view'],
    vendor: ['view'],
    products: ['view'],
    product_based_costing: ['view'],
    costing_file: ['view'],
    store: NO_ACCESS,
    cart: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: ['view'],
    tasks: ['view'],
    thrift_stock: ['view'],
    thrift_shipment: ['view'],
    thrift_box: ['view'],
    thrift_shelf: ['view'],
    thrift_barcode: ['view'],
    thrift_category: ['view'],
    thrift_type: ['view'],
    thrift_settings: ['view'],
    global_reference: NO_ACCESS,
    global_reference_currency: ['view'],
    global_reference_market: ['view'],
    global_reference_payment_method: ['view'],
    global_reference_unit_of_measure: ['view'],
    global_shipment: ['view'],
    global_stock: ['view'],
    global_invoice: ['view'],
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: ['view'],
    recipient_profile: ['view'],
    invoice_brand: ['view'],
    reporting_treasury: NO_ACCESS,
    payments: ['view'],
    invoice_reports: ['view'],
    shipment_reports: NO_ACCESS,
    billing_balances: ['view'],
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: ['view'],
    investor_capital_ledger: ['view'],
    investor_shipment_share: ['view'],
    shop_order: NO_ACCESS,
    shop_config: ['view'],
    shop_permissions: ['view'],
    shop_pricing: ['view'],
    shop_storefront: NO_ACCESS,
    shop_cart: NO_ACCESS,
    shop_order_mgmt: ['view'],
    shop_fulfillment: ['view'],
  },
  viewer: {
    order_management: NO_ACCESS,
    commerce_order: NO_ACCESS,
    commerce_invoice: NO_ACCESS,
    commerce_accounting: NO_ACCESS,
    commerce_cart: NO_ACCESS,
    investor: NO_ACCESS,
    vendor: NO_ACCESS,
    products: NO_ACCESS,
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    store: NO_ACCESS,
    cart: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: NO_ACCESS,
    koba_retail: NO_ACCESS,
    koba_wholesale: NO_ACCESS,
    tasks: ['view'],
    thrift_stock: NO_ACCESS,
    thrift_shipment: NO_ACCESS,
    thrift_box: NO_ACCESS,
    thrift_shelf: NO_ACCESS,
    thrift_barcode: NO_ACCESS,
    thrift_category: NO_ACCESS,
    thrift_type: NO_ACCESS,
    thrift_settings: NO_ACCESS,
    global_reference: NO_ACCESS,
    global_reference_currency: NO_ACCESS,
    global_reference_market: NO_ACCESS,
    global_reference_payment_method: NO_ACCESS,
    global_reference_unit_of_measure: NO_ACCESS,
    global_shipment: NO_ACCESS,
    global_stock: NO_ACCESS,
    global_invoice: NO_ACCESS,
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: NO_ACCESS,
    recipient_profile: NO_ACCESS,
    invoice_brand: NO_ACCESS,
    reporting_treasury: NO_ACCESS,
    payments: NO_ACCESS,
    invoice_reports: NO_ACCESS,
    shipment_reports: NO_ACCESS,
    billing_balances: NO_ACCESS,
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: NO_ACCESS,
    investor_capital_ledger: NO_ACCESS,
    investor_shipment_share: NO_ACCESS,
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: NO_ACCESS,
    shop_cart: NO_ACCESS,
    shop_order_mgmt: NO_ACCESS,
    shop_fulfillment: NO_ACCESS,
  },
  customer_admin: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    commerce_shop: ['view'],
    commerce_order: ['view'],
    commerce_invoice: NO_ACCESS,
    commerce_accounting: NO_ACCESS,
    commerce_cart: ['view'],
    investor: NO_ACCESS,
    vendor: NO_ACCESS,
    products: NO_ACCESS,
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    store: ['view'],
    cart: ['view'],
    accounting: NO_ACCESS,
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: NO_ACCESS,
    tasks: NO_ACCESS,
    thrift_stock: NO_ACCESS,
    thrift_shipment: NO_ACCESS,
    thrift_box: NO_ACCESS,
    thrift_shelf: NO_ACCESS,
    thrift_barcode: NO_ACCESS,
    thrift_category: NO_ACCESS,
    thrift_type: NO_ACCESS,
    thrift_settings: NO_ACCESS,
    global_reference: NO_ACCESS,
    global_reference_currency: NO_ACCESS,
    global_reference_market: NO_ACCESS,
    global_reference_payment_method: NO_ACCESS,
    global_reference_unit_of_measure: NO_ACCESS,
    global_shipment: NO_ACCESS,
    global_stock: NO_ACCESS,
    global_invoice: NO_ACCESS,
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: NO_ACCESS,
    recipient_profile: NO_ACCESS,
    invoice_brand: NO_ACCESS,
    reporting_treasury: NO_ACCESS,
    payments: NO_ACCESS,
    invoice_reports: NO_ACCESS,
    shipment_reports: NO_ACCESS,
    billing_balances: NO_ACCESS,
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: NO_ACCESS,
    investor_capital_ledger: NO_ACCESS,
    investor_shipment_share: NO_ACCESS,
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: ['view'],
    shop_cart: ['view'],
    shop_order_mgmt: ['view'],
    shop_fulfillment: NO_ACCESS,
  },
  customer_negotiator: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    commerce_shop: ['view'],
    commerce_order: ['view'],
    commerce_invoice: NO_ACCESS,
    commerce_accounting: NO_ACCESS,
    commerce_cart: ['view'],
    investor: NO_ACCESS,
    vendor: NO_ACCESS,
    products: NO_ACCESS,
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    store: ['view'],
    cart: ['view'],
    accounting: NO_ACCESS,
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: NO_ACCESS,
    tasks: NO_ACCESS,
    thrift_stock: NO_ACCESS,
    thrift_shipment: NO_ACCESS,
    thrift_box: NO_ACCESS,
    thrift_shelf: NO_ACCESS,
    thrift_barcode: NO_ACCESS,
    thrift_category: NO_ACCESS,
    thrift_type: NO_ACCESS,
    thrift_settings: NO_ACCESS,
    global_reference: NO_ACCESS,
    global_reference_currency: NO_ACCESS,
    global_reference_market: NO_ACCESS,
    global_reference_payment_method: NO_ACCESS,
    global_reference_unit_of_measure: NO_ACCESS,
    global_shipment: NO_ACCESS,
    global_stock: NO_ACCESS,
    global_invoice: NO_ACCESS,
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: NO_ACCESS,
    recipient_profile: NO_ACCESS,
    invoice_brand: NO_ACCESS,
    reporting_treasury: NO_ACCESS,
    payments: NO_ACCESS,
    invoice_reports: NO_ACCESS,
    shipment_reports: NO_ACCESS,
    billing_balances: NO_ACCESS,
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: NO_ACCESS,
    investor_capital_ledger: NO_ACCESS,
    investor_shipment_share: NO_ACCESS,
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: ['view'],
    shop_cart: ['view'],
    shop_order_mgmt: ['view'],
    shop_fulfillment: NO_ACCESS,
  },
  customer_staff: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    commerce_shop: ['view'],
    commerce_order: ['view'],
    commerce_invoice: NO_ACCESS,
    commerce_accounting: NO_ACCESS,
    commerce_cart: ['view'],
    investor: NO_ACCESS,
    vendor: NO_ACCESS,
    products: NO_ACCESS,
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    store: ['view'],
    cart: ['view'],
    accounting: NO_ACCESS,
    invoice: ['view'],
    koba_retail: ['view'],
    koba_wholesale: NO_ACCESS,
    tasks: NO_ACCESS,
    thrift_stock: NO_ACCESS,
    thrift_shipment: NO_ACCESS,
    thrift_box: NO_ACCESS,
    thrift_shelf: NO_ACCESS,
    thrift_barcode: NO_ACCESS,
    thrift_category: NO_ACCESS,
    thrift_type: NO_ACCESS,
    thrift_settings: NO_ACCESS,
    global_reference: NO_ACCESS,
    global_reference_currency: NO_ACCESS,
    global_reference_market: NO_ACCESS,
    global_reference_payment_method: NO_ACCESS,
    global_reference_unit_of_measure: NO_ACCESS,
    global_shipment: NO_ACCESS,
    global_stock: NO_ACCESS,
    global_invoice: NO_ACCESS,
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: NO_ACCESS,
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: NO_ACCESS,
    recipient_profile: NO_ACCESS,
    invoice_brand: NO_ACCESS,
    reporting_treasury: NO_ACCESS,
    payments: NO_ACCESS,
    invoice_reports: NO_ACCESS,
    shipment_reports: NO_ACCESS,
    billing_balances: NO_ACCESS,
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: NO_ACCESS,
    investor_capital_ledger: NO_ACCESS,
    investor_shipment_share: NO_ACCESS,
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: ['view'],
    shop_cart: ['view'],
    shop_order_mgmt: ['view'],
    shop_fulfillment: NO_ACCESS,
  },
  investor_portal: {
    order_management: NO_ACCESS,
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    commerce_shop: NO_ACCESS,
    commerce_order: NO_ACCESS,
    commerce_invoice: NO_ACCESS,
    commerce_accounting: NO_ACCESS,
    commerce_cart: NO_ACCESS,
    investor: NO_ACCESS,
    vendor: NO_ACCESS,
    products: NO_ACCESS,
    product_based_costing: NO_ACCESS,
    costing_file: NO_ACCESS,
    store: NO_ACCESS,
    cart: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: NO_ACCESS,
    koba_retail: NO_ACCESS,
    koba_wholesale: NO_ACCESS,
    tasks: NO_ACCESS,
    thrift_stock: NO_ACCESS,
    thrift_shipment: NO_ACCESS,
    thrift_box: NO_ACCESS,
    thrift_shelf: NO_ACCESS,
    thrift_barcode: NO_ACCESS,
    thrift_category: NO_ACCESS,
    thrift_type: NO_ACCESS,
    thrift_settings: NO_ACCESS,
    global_reference: NO_ACCESS,
    global_reference_currency: NO_ACCESS,
    global_reference_market: NO_ACCESS,
    global_reference_payment_method: NO_ACCESS,
    global_reference_unit_of_measure: NO_ACCESS,
    global_shipment: NO_ACCESS,
    global_stock: NO_ACCESS,
    global_invoice: NO_ACCESS,
    global_accounting_ledger: NO_ACCESS,
    global_shipment_accounting: NO_ACCESS,
    global_invoice_accounting: NO_ACCESS,
    global_investor: NO_ACCESS,
    global_investor_shipment: NO_ACCESS,
    investor_portal: ['view'],
    procurement_stock: NO_ACCESS,
    global_stock_type: NO_ACCESS,
    sales_invoice: NO_ACCESS,
    billing_profile: NO_ACCESS,
    recipient_profile: NO_ACCESS,
    invoice_brand: NO_ACCESS,
    reporting_treasury: NO_ACCESS,
    payments: NO_ACCESS,
    invoice_reports: NO_ACCESS,
    shipment_reports: NO_ACCESS,
    billing_balances: NO_ACCESS,
    parent_dashboard: NO_ACCESS,
    investor_reports: NO_ACCESS,
    investor_capital: NO_ACCESS,
    investor_profiles: NO_ACCESS,
    investor_capital_ledger: NO_ACCESS,
    investor_shipment_share: NO_ACCESS,
    shop_order: NO_ACCESS,
    shop_config: NO_ACCESS,
    shop_permissions: NO_ACCESS,
    shop_pricing: NO_ACCESS,
    shop_storefront: NO_ACCESS,
    shop_cart: NO_ACCESS,
    shop_order_mgmt: NO_ACCESS,
    shop_fulfillment: NO_ACCESS,
  },
}

const isInteractiveScope = (
  scope: AuthScope | null,
): scope is InteractiveScope => scope === 'app' || scope === 'shop'

export const hasTenantContextForScope = ({
  scope,
  tenantId,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
}) => {
  if (!isInteractiveScope(scope)) {
    return false
  }

  return typeof tenantId === 'number' && Number.isFinite(tenantId)
}

export const hasCustomerGroupContextForScope = ({
  scope,
  customerGroupId,
}: {
  scope: AuthScope | null
  customerGroupId: number | null | undefined
}) => {
  if (scope !== 'shop') {
    return true
  }

  return typeof customerGroupId === 'number' && Number.isFinite(customerGroupId)
}

export type ModuleAccessResolution = {
  allowed: boolean
  hasScopeContext: boolean
  hasTenantContext: boolean
  hasCustomerGroupContext: boolean
  moduleEnabled: boolean
  roleAllowed: boolean
  allowedActions: readonly ModuleAction[]
}

export const getAllowedModuleActions = (
  role: AccessRole | null | undefined,
  moduleKey: ModuleKey,
) => {
  if (!role) {
    return NO_ACCESS
  }

  return MODULE_PERMISSION_MATRIX[role]?.[moduleKey] ?? NO_ACCESS
}

export const canAccessModule = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
}) => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const tenantHasModule = activeModuleKeys.includes(moduleKey)
  const allowedActions = getAllowedModuleActions(role, moduleKey)
  const roleAllowed = allowedActions.includes(action)

  if (
    moduleKey === 'global_shipment' ||
    moduleKey === 'global_stock' ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore()
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null
    if (current && current.parent_id !== null) {
      return false
    }
  }

  return (
    hasScopeContext &&
    hasTenantContext &&
    hasCustomerGroupContext &&
    tenantHasModule &&
    roleAllowed
  )
}

export const resolveModuleAccess = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
}): ModuleAccessResolution => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const allowedActions = getAllowedModuleActions(role, moduleKey)
  const moduleEnabled = activeModuleKeys.includes(moduleKey)
  const roleAllowed = allowedActions.includes(action)

  let isBlockedByChildStatus = false
  if (
    moduleKey === 'global_shipment' ||
    moduleKey === 'global_stock' ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore()
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null
    if (current && current.parent_id !== null) {
      isBlockedByChildStatus = true
    }
  }

  return {
    allowed:
      hasScopeContext &&
      hasTenantContext &&
      hasCustomerGroupContext &&
      moduleEnabled &&
      roleAllowed &&
      !isBlockedByChildStatus,
    hasScopeContext,
    hasTenantContext,
    hasCustomerGroupContext,
    moduleEnabled: moduleEnabled && !isBlockedByChildStatus,
    roleAllowed,
    allowedActions,
  }
}

export const getAccessibleModuleRoutes = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  activeModuleKeys,
  tenantSlug,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  activeModuleKeys: readonly string[]
  tenantSlug?: string | null | undefined
}) => {
  if (!isInteractiveScope(scope)) {
    return []
  }

  return getModuleRoutesForScope(scope, { tenantSlug }).filter((routeDefinition) =>
    resolveModuleAccess({
      scope,
      tenantId,
      customerGroupId,
      role,
      moduleKey: routeDefinition.moduleKey,
      activeModuleKeys,
      action: routeDefinition.requiredAction ?? 'view',
    }).allowed,
  )
}

export const useModulePermissions = () => {
  const authStore = useAuthStore()

  const accessibleModuleRoutes = computed(() =>
    getAccessibleModuleRoutes({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      activeModuleKeys: authStore.activeModuleKeys,
      tenantSlug: authStore.tenantSlug,
    }),
  )

  const hasModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
    })

  const getModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    resolveModuleAccess({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
    })

  return {
    accessibleModuleRoutes,
    getModuleAccess,
    hasModuleAccess,
  }
}

export type { ModuleKey, ModuleAction } from './moduleRegistry'
