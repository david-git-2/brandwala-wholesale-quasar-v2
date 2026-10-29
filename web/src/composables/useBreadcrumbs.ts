import { computed, ref, onMounted, onBeforeUnmount, watchEffect } from 'vue';
import { useRoute, useRouter, type RouteLocationRaw, type Router } from 'vue-router';
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
  'access-control': 'Access Control',
  membership: 'Memberships',
  'after-sales': 'After Sales',
  customers: 'Customers',
  capital: 'Capital',
  accounting: 'Accounting',
  wallet: 'Wallet',
  reference: 'Reference',
  koba: 'Koba',
  'product-based-costing': 'Product Costing',
  global: 'Global',
  finance: 'Finance',
};

/** Under `/app/finance/*` — URL folder only; crumbs match top-level modules. */
const FINANCE_URL_PREFIX_MODULES = new Set(['reports']);

const ENTITY_MAP: Record<
  string,
  { label: string; singular: string; defaultSubPath?: string | undefined; skipIdCrumb?: boolean }
> = {
  shipment: { label: 'Shipments', singular: 'Shipment' },
  'inbound-shipments': { label: 'Inbound Shipments', singular: 'Shipment' },
  inbound: { label: 'Inbound Shipments', singular: 'Shipment' },
  stock: { label: 'Warehouse', singular: 'Stock Item' },
  'child-stock': { label: 'Location Stock', singular: 'Stock Item' },
  'stock-locations': { label: 'Stock Locations', singular: 'Stock Location' },
  'cargo-companies': { label: 'Cargo Companies', singular: 'Cargo Company' },
  'shipment-progress': { label: 'Shipment Progress', singular: 'Shipment Progress' },
  shops: { label: 'Shops', singular: 'Shop', skipIdCrumb: true, defaultSubPath: 'list' },
  shipping: { label: 'Shipping', singular: 'Shipping' },
  orders: { label: 'Orders', singular: 'Order' },
  'dropship-orders': { label: 'Dropship Orders', singular: 'Dropship Order' },
  'dropship-management': { label: 'Dropship Orders', singular: 'Dropship Order' },
  'customer-groups': { label: 'Customer Groups', singular: 'Customer Group' },
  merchants: { label: 'Dropshippers', singular: 'Dropshipper' },
  categories: { label: 'Categories', singular: 'Category' },
  pricing: { label: 'Pricing', singular: 'Pricing' },
  invoices: { label: 'Bills', singular: 'Bill' },
  invoice: { label: 'Bills', singular: 'Bill' },
  payments: { label: 'Payments', singular: 'Payment' },
  files: { label: 'Costing Files', singular: 'Costing File' },
  vendors: { label: 'Vendors', singular: 'Vendor' },
  profiles: { label: 'Profiles', singular: 'Profile' },
  allocations: { label: 'Allocations', singular: 'Allocation' },
  ledger: { label: 'Ledger', singular: 'Ledger' },
  tasks: { label: 'Tasks', singular: 'Task' },
  tenants: { label: 'Company', singular: 'Company' },
  roles: { label: 'Roles', singular: 'Role' },
  investors: { label: 'Investors', singular: 'Investor' },
  'customer-payments': { label: 'Customer Payments', singular: 'Profile' },
  admin: { label: 'Admin', singular: 'Costing File' },
  staff: { label: 'Staff', singular: 'Costing File' },
  viewer: { label: 'Viewer', singular: 'Costing File' },
};

const ACTION_MAP: Record<string, string> = {
  'rates-invoices': 'Rates & Invoices',
  items: 'Line Items',
  lines: 'Shipment Lines',
  rates: 'Shipping Rates',
  adjust: 'Cost Adjustments',
  settle: 'Payee Settlement',
  'add-catalog': 'Add Catalog',
  setup: 'Config',
  access: 'Access',
  settings: 'Settings',
  edit: 'Edit Details',
  'create-wholesale': 'New bill',
  create: 'New bill',
  new: 'Create New',
  overview: 'Overview',
  preview: 'Preview',
  details: 'Details',
  reports: 'Reports',
  list: 'List',
  return: 'Return credit',
};

const ACTION_OVERRIDES: Record<string, Record<string, string>> = {
  customers: {
    create: 'New customer',
  },
};

/** URL folders that are not pages — do not render them as crumbs. */
const PATH_PREFIX_SEGMENTS = new Set(['sales']);

/** Path segments omitted from the breadcrumb trail (URL still includes them). */
const HIDDEN_SEGMENTS = new Set(['v2']);

/** Labels shown but not linked — no dedicated list/index route. */
const NON_PAGE_SEGMENTS = new Set(['group', 'party', 'product', 'points']);

/** Module hubs with no index route — show the label but do not link. */
const UNLINKED_DOMAIN_GROUPS = new Set(['finance', 'capital', 'accounting', 'global']);

function metaLabelForPath(router: Router, path: string, isIdSegment: boolean): string | null {
  try {
    const resolved = router.resolve(path);
    const matchedRecord = resolved.matched[resolved.matched.length - 1];
    if (!matchedRecord) return null;
    // A plain word (e.g. "party") must not borrow the title of a ":param" route.
    if (!isIdSegment && /\/:[^/]+$/.test(matchedRecord.path)) return null;
    const meta = resolved.meta;
    if (typeof meta.breadcrumb === 'string' && meta.breadcrumb.trim()) {
      return meta.breadcrumb.trim();
    }
    if (typeof meta.headerTitle === 'string' && meta.headerTitle.trim()) {
      return meta.headerTitle.trim();
    }
    if (typeof meta.title === 'string' && meta.title.trim()) {
      return meta.title.trim();
    }
  } catch {
    // ignore invalid resolve paths
  }
  return null;
}

function resolveActionLabel(seg: string, parentSeg: string | undefined): string | undefined {
  const override = parentSeg ? ACTION_OVERRIDES[parentSeg]?.[seg] : undefined;
  return override ?? ACTION_MAP[seg];
}

function crumbLink(
  accumulatedPath: string,
  seg: string,
  isLeaf: boolean,
): RouteLocationRaw | undefined {
  if (isLeaf || NON_PAGE_SEGMENTS.has(seg)) return undefined;
  return accumulatedPath;
}

function isEffectiveLeaf(remainingSegments: string[], index: number): boolean {
  for (let j = index + 1; j < remainingSegments.length; j++) {
    const next = remainingSegments[j];
    if (next && !HIDDEN_SEGMENTS.has(next)) return false;
  }
  return true;
}

export function useBreadcrumbs() {
  const route = useRoute();
  const router = useRouter();
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

    const skippedPrefixes: string[] = [];
    while (segments[0] && PATH_PREFIX_SEGMENTS.has(segments[0])) {
      skippedPrefixes.push(segments.shift() as string);
    }

    if (segments.length === 0) {
      items.push({ label: 'Dashboard' });
      return items;
    }

    if (
      segments[0] === 'finance' &&
      segments[1] &&
      FINANCE_URL_PREFIX_MODULES.has(segments[1])
    ) {
      segments.shift();
    }

    const prefix =
      (tenantSlug ? `/${tenantSlug}${scopePrefix.slice(0, -1)}` : scopePrefix.slice(0, -1)) +
      (skippedPrefixes.length ? `/${skippedPrefixes.join('/')}` : '');

    const firstSeg = segments[0] || '';
    const isDomainGroup = Boolean(firstSeg && DOMAIN_GROUPS[firstSeg]);

    // Add Domain Group if present — link to module hub when on a sub-page
    if (isDomainGroup && firstSeg) {
      const domainTitle = DOMAIN_GROUPS[firstSeg] || firstSeg;
      const hubPath = `${prefix}/${firstSeg}`;

      if (segments.length === 1) {
        items.push({ label: domainTitle });
        return items;
      }

      items.push({
        label: domainTitle,
        to: UNLINKED_DOMAIN_GROUPS.has(firstSeg) ? undefined : hubPath,
      });
    }

    // Process remaining entity/sub-path segments
    const remainingSegments = isDomainGroup ? segments.slice(1) : segments;
    let accumulatedPath = isDomainGroup ? `${prefix}/${firstSeg}` : prefix;
    let lastEntitySingular = 'Item';
    let skipIdCrumb = false;

    for (let i = 0; i < remainingSegments.length; i++) {
      const seg = remainingSegments[i] || '';
      if (!seg) continue;

      accumulatedPath += `/${seg}`;

      if (HIDDEN_SEGMENTS.has(seg)) {
        continue;
      }

      const isLeaf = isEffectiveLeaf(remainingSegments, i);
      const parentSeg = i > 0 ? remainingSegments[i - 1] : undefined;
      const isIdParam = isNumericOrId(seg);
      const metaLabel = metaLabelForPath(router, accumulatedPath, isIdParam);

      if (isIdParam) {
        if (skipIdCrumb) {
          continue;
        }

        const label = metaLabel || `${lastEntitySingular} Details`;

        items.push({
          label,
          to: isLeaf ? undefined : accumulatedPath,
        });
      } else if (ENTITY_MAP[seg]) {
        const entity = ENTITY_MAP[seg]!;
        lastEntitySingular = entity.singular;
        skipIdCrumb = Boolean(entity.skipIdCrumb);

        let entityTo: string | undefined;
        if (isLeaf) {
          entityTo = undefined;
        } else if (entity.defaultSubPath) {
          entityTo = `${accumulatedPath}/${entity.defaultSubPath}`;
        } else {
          entityTo = accumulatedPath;
        }

        items.push({
          label: metaLabel || entity.label,
          to: entityTo,
        });
      } else {
        const actionLabel = resolveActionLabel(seg, parentSeg);
        if (actionLabel) {
          items.push({
            label: metaLabel || actionLabel,
            to: crumbLink(accumulatedPath, seg, isLeaf),
          });
        } else {
          items.push({
            label: metaLabel || prettifySegment(seg),
            to: crumbLink(accumulatedPath, seg, isLeaf),
          });
        }
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

  // Start only after mount: the previous page's unmount clears the shared state first.
  onMounted(() => {
    update();
    if (typeof breadcrumbs === 'function') {
      watchEffect(() => {
        setCustomBreadcrumbs(breadcrumbs());
      });
    }
  });

  onBeforeUnmount(() => {
    clearCustomBreadcrumbs();
  });
}
