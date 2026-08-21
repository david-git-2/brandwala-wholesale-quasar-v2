import { computed, ref, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRoute, type RouteLocationRaw } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export interface BreadcrumbBadge {
  label: string;
  color?: string | undefined;
  textColor?: string | undefined;
  icon?: string | undefined;
}

export interface BreadcrumbItem {
  label: string;
  to?: RouteLocationRaw | undefined;
  icon?: string | undefined;
  badge?: BreadcrumbBadge | undefined;
}

// Global reactive override state (set by active page if custom)
const customBreadcrumbsState = ref<BreadcrumbItem[] | null>(null);

const DOMAIN_GROUPS: Record<string, string> = {
  procurement: 'Procurement',
  shop: 'Shop & Order',
  thrift: 'Thrift',
  tasks: 'Tasks',
  products: 'Products',
  vendor: 'Vendors',
  inventory: 'Stock Catalog',
  warehouse: 'Warehouse Stock',
  reporting: 'Reporting & Treasury',
  'reporting-treasury': 'Reporting & Treasury',
  investor: 'Investor Portal',
  costing: 'Costing Files',
  'global-reference': 'Global Reference',
  settings: 'Settings',
  access_control: 'Access Control',
  membership: 'Memberships',
};

const ENTITY_MAP: Record<string, { label: string; singular: string; defaultSubPath?: string | undefined }> = {
  shipment: { label: 'Shipments', singular: 'Shipment' },
  'inbound-shipments': { label: 'Inbound Shipments', singular: 'Shipment' },
  inbound: { label: 'Inbound Shipments', singular: 'Shipment' },
  stock: { label: 'Stock Catalog', singular: 'Stock Item' },
  'child-stock': { label: 'Location Stock', singular: 'Stock Item' },
  'stock-locations': { label: 'Stock Locations', singular: 'Stock Location' },
  'cargo-companies': { label: 'Cargo Companies', singular: 'Cargo Company' },
  'shipment-progress': { label: 'Shipment Progress', singular: 'Shipment Progress' },
  shops: { label: 'Shops', singular: 'Shop' },
  orders: { label: 'Orders', singular: 'Order' },
  'dropship-orders': { label: 'Dropship Orders', singular: 'Dropship Order' },
  'customer-groups': { label: 'Customer Groups', singular: 'Customer Group' },
  merchants: { label: 'Merchants', singular: 'Merchant' },
  categories: { label: 'Categories', singular: 'Category' },
  pricing: { label: 'Pricing', singular: 'Pricing' },
  invoices: { label: 'Invoices', singular: 'Invoice' },
  files: { label: 'Costing Files', singular: 'Costing File' },
  vendors: { label: 'Vendors', singular: 'Vendor' },
  profiles: { label: 'Profiles', singular: 'Profile' },
  allocations: { label: 'Allocations', singular: 'Allocation' },
  ledger: { label: 'Ledger', singular: 'Ledger' },
  tasks: { label: 'Tasks', singular: 'Task' },
};

const ACTION_MAP: Record<string, string> = {
  'rates-invoices': 'Rates & Invoices',
  items: 'Line Items',
  lines: 'Line Items',
  rates: 'Shipping Rates',
  adjust: 'Cost Adjustments',
  settle: 'Payee Settlement',
  'add-catalog': 'Add Catalog',
  settings: 'Settings',
  edit: 'Edit Details',
  create: 'Create New',
  new: 'Create New',
  overview: 'Overview',
  preview: 'Preview',
  details: 'Details',
  reports: 'Reports',
};

export function useBreadcrumbs() {
  const route = useRoute();
  const authStore = useAuthStore();

  const currentTenantSlug = computed(
    () => (route.params?.tenantSlug as string) || authStore.selectedTenant?.slug || null,
  );

  const autoBreadcrumbs = computed<BreadcrumbItem[]>(() => {
    // If custom breadcrumbs are provided by the active page, use them
    if (customBreadcrumbsState.value && customBreadcrumbsState.value.length > 0) {
      return customBreadcrumbsState.value;
    }

    const items: BreadcrumbItem[] = [];
    const tenantSlug = currentTenantSlug.value;

    const path = route.path || '';
    const isAppScope = path.includes('/app');
    const isShopScope = path.includes('/shop');
    const isPlatformScope = path.includes('/platform');

    // 1. Root Group (Unclickable group header)
    if (isAppScope) {
      const tenantName = authStore.selectedTenant?.name;
      items.push({
        label: tenantName || 'Workspace',
        icon: 'ph ph-buildings',
        to: undefined,
      });
    } else if (isShopScope) {
      items.push({
        label: authStore.tenant?.name || 'Shop',
        icon: 'ph ph-storefront',
        to: undefined,
      });
    } else if (isPlatformScope) {
      items.push({
        label: 'Platform',
        icon: 'ph ph-squares-four',
        to: undefined,
      });
    }

    // 2. Parse path segments
    const scopePrefix = isAppScope ? '/app/' : isShopScope ? '/shop/' : '/platform/';
    const scopeIndex = path.indexOf(scopePrefix);
    const subPath = scopeIndex !== -1 ? path.substring(scopeIndex + scopePrefix.length) : '';
    const segments = subPath.split('/').filter(Boolean);

    if (segments.length === 0) {
      items.push({ label: 'Dashboard' });
      return items;
    }

    const prefix = tenantSlug ? `/${tenantSlug}${scopePrefix.slice(0, -1)}` : scopePrefix.slice(0, -1);

    const firstSeg = segments[0] || '';
    const isDomainGroup = Boolean(firstSeg && DOMAIN_GROUPS[firstSeg]);

    // Add Domain Group if present (Unclickable category)
    if (isDomainGroup && firstSeg) {
      const domainTitle = DOMAIN_GROUPS[firstSeg] || firstSeg;
      if (segments.length === 1) {
        items.push({ label: domainTitle });
        return items;
      }
      items.push({
        label: domainTitle,
        to: undefined,
      });
    }

    // Process remaining entity/sub-path segments
    const remainingSegments = isDomainGroup ? segments.slice(1) : segments;
    let accumulatedPath = isDomainGroup ? `${prefix}/${firstSeg}` : prefix;
    let lastEntitySingular = 'Item';

    for (let i = 0; i < remainingSegments.length; i++) {
      const seg = remainingSegments[i] || '';
      if (!seg) continue;
      const isLeaf = i === remainingSegments.length - 1;
      accumulatedPath += `/${seg}`;

      const isIdParam = isNumericOrId(seg);

      if (isIdParam) {
        // ID parameter segment: Transform raw ID into descriptive title
        const metaHeaderTitle =
          typeof route.meta?.headerTitle === 'string' ? route.meta.headerTitle.trim() : '';
        const metaTitle = typeof route.meta?.title === 'string' ? route.meta.title.trim() : '';

        const label = metaHeaderTitle || metaTitle || `${lastEntitySingular} Details`;

        items.push({
          label,
          to: isLeaf ? undefined : accumulatedPath,
        });
      } else if (ENTITY_MAP[seg]) {
        // Known Entity segment (e.g. 'shipment', 'shops', 'orders')
        const entity = ENTITY_MAP[seg]!;
        lastEntitySingular = entity.singular;

        items.push({
          label: entity.label,
          to: isLeaf ? undefined : accumulatedPath,
        });
      } else if (ACTION_MAP[seg]) {
        // Action / Subpage segment (e.g. 'rates-invoices', 'items', 'settings')
        items.push({
          label: ACTION_MAP[seg]!,
          to: isLeaf ? undefined : accumulatedPath,
        });
      } else {
        // Fallback prettified segment
        items.push({
          label: prettifySegment(seg),
          to: isLeaf ? undefined : accumulatedPath,
        });
      }
    }

    return items;
  });

  return {
    breadcrumbs: autoBreadcrumbs,
    setCustomBreadcrumbs: (items: BreadcrumbItem[] | null) => {
      customBreadcrumbsState.value = items;
    },
    clearCustomBreadcrumbs: () => {
      customBreadcrumbsState.value = null;
    },
  };
}

function isNumericOrId(seg: string): boolean {
  // Matches integer IDs (e.g. '14', '105') or UUID patterns
  return /^\d+$/.test(seg) || /^[0-9a-f]{8}-[0-9a-f]{4}/i.test(seg);
}

function prettifySegment(seg: string): string {
  return seg
    .replace(/-(page|list|details)$/g, '')
    .split('-')
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(' ');
}

/**
 * Convenience composable for page components to register page-specific dynamic breadcrumbs.
 * Automatically clears breadcrumbs on unmount.
 */
export function usePageBreadcrumbs(
  breadcrumbs: BreadcrumbItem[] | (() => BreadcrumbItem[]),
) {
  const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

  const update = () => {
    const items = typeof breadcrumbs === 'function' ? breadcrumbs() : breadcrumbs;
    setCustomBreadcrumbs(items);
  };

  onMounted(() => {
    update();
  });

  if (typeof breadcrumbs === 'function') {
    watch(
      breadcrumbs,
      (newItems) => {
        setCustomBreadcrumbs(newItems);
      },
      { deep: true },
    );
  }

  onBeforeUnmount(() => {
    clearCustomBreadcrumbs();
  });
}
