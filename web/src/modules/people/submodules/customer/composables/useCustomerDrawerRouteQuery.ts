import { onMounted, watch, type Ref } from 'vue';
import { useRoute, useRouter, type RouteLocationNormalizedLoaded, type Router } from 'vue-router';
import { customerRepository } from '../repositories/customerRepository';
import type { CustomerAccount } from '../types/customer';

export type CustomerDrawerPanel = 'general' | 'members' | 'account' | 'locations';

const QUERY_CUSTOMER_GROUP = 'customerGroup';
const QUERY_CUSTOMER_PANEL = 'customerPanel';

const VALID_PANELS: CustomerDrawerPanel[] = ['general', 'members', 'account', 'locations'];

export function parseCustomerGroupFromQuery(
  route: RouteLocationNormalizedLoaded,
): number | null {
  const raw = route.query[QUERY_CUSTOMER_GROUP];
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
}

export function parseCustomerPanelFromQuery(
  route: RouteLocationNormalizedLoaded,
): CustomerDrawerPanel {
  const raw = route.query[QUERY_CUSTOMER_PANEL];
  if (typeof raw === 'string' && (VALID_PANELS as string[]).includes(raw)) {
    return raw as CustomerDrawerPanel;
  }
  return 'general';
}

function panelQueryValue(panel: CustomerDrawerPanel): string | undefined {
  return panel === 'general' ? undefined : panel;
}

export function replaceCustomerDrawerQuery(
  router: Router,
  route: RouteLocationNormalizedLoaded,
  customerGroupId: number | null,
  panel: CustomerDrawerPanel,
) {
  const desiredGroup =
    customerGroupId != null && customerGroupId > 0 ? String(customerGroupId) : undefined;
  const desiredPanel = customerGroupId != null ? panelQueryValue(panel) : undefined;

  const currentGroup =
    typeof route.query[QUERY_CUSTOMER_GROUP] === 'string'
      ? route.query[QUERY_CUSTOMER_GROUP]
      : undefined;
  const currentPanel =
    typeof route.query[QUERY_CUSTOMER_PANEL] === 'string'
      ? route.query[QUERY_CUSTOMER_PANEL]
      : undefined;

  if (currentGroup === desiredGroup && currentPanel === desiredPanel) {
    return;
  }
  if (!desiredGroup && !currentGroup && !currentPanel) {
    return;
  }

  const query = { ...route.query };
  if (desiredGroup) {
    query[QUERY_CUSTOMER_GROUP] = desiredGroup;
    if (desiredPanel) {
      query[QUERY_CUSTOMER_PANEL] = desiredPanel;
    } else {
      delete query[QUERY_CUSTOMER_PANEL];
    }
  } else {
    delete query[QUERY_CUSTOMER_GROUP];
    delete query[QUERY_CUSTOMER_PANEL];
  }

  void router.replace({ query });
}

export function clearCustomerDrawerQuery(
  router: Router,
  route: RouteLocationNormalizedLoaded,
) {
  replaceCustomerDrawerQuery(router, route, null, 'general');
}

export function useCustomerDrawerQueryPersistence(options: {
  customer: Ref<CustomerAccount | null>;
  activeTab: Ref<CustomerDrawerPanel>;
  drawerOpen: Ref<boolean>;
}) {
  const route = useRoute();
  const router = useRouter();
  let skipPanelSync = false;

  const applyPanelFromRoute = () => {
    const panel = parseCustomerPanelFromQuery(route);
    if (options.activeTab.value !== panel) {
      skipPanelSync = true;
      options.activeTab.value = panel;
    }
  };

  watch(
    () => options.customer.value?.customer_group_id,
    (groupId) => {
      if (groupId == null) return;
      applyPanelFromRoute();
    },
    { immediate: true },
  );

  watch(
    () => route.query[QUERY_CUSTOMER_PANEL],
    () => {
      if (!options.customer.value) return;
      applyPanelFromRoute();
    },
  );

  const persistDrawerQuery = () => {
    const groupId = options.customer.value?.customer_group_id;
    if (groupId == null) return;
    replaceCustomerDrawerQuery(router, route, groupId, options.activeTab.value);
  };

  watch(options.activeTab, (panel) => {
    if (skipPanelSync) {
      skipPanelSync = false;
      return;
    }
    const groupId = options.customer.value?.customer_group_id;
    if (groupId == null) return;
    replaceCustomerDrawerQuery(router, route, groupId, panel);
  });

  watch(
    () => options.customer.value?.customer_group_id,
    (groupId) => {
      if (groupId == null) return;
      persistDrawerQuery();
    },
  );

  watch(options.drawerOpen, (open, wasOpen) => {
    if (wasOpen && !open) {
      persistDrawerQuery();
    } else if (open) {
      persistDrawerQuery();
    }
  });
}

export function useRestoreCustomerDrawerFromQuery(options: {
  tenantId: Ref<number | null | undefined>;
  customers: Ref<CustomerAccount[]>;
  selectedCustomer: Ref<CustomerAccount | null>;
  drawerOpen: Ref<boolean>;
}) {
  const route = useRoute();
  let restoring = false;

  const resolveCustomer = async (groupId: number): Promise<CustomerAccount | null> => {
    const cached = options.customers.value.find((c) => c.customer_group_id === groupId);
    if (cached) return cached;
    const tid = options.tenantId.value;
    if (!tid) return null;
    try {
      const rows = await customerRepository.listCustomers(tid);
      return rows.find((c) => c.customer_group_id === groupId) ?? null;
    } catch {
      return null;
    }
  };

  const restore = async () => {
    if (restoring) return;
    const groupId = parseCustomerGroupFromQuery(route);
    if (!groupId) return;

    restoring = true;
    try {
      const customer = await resolveCustomer(groupId);
      if (!customer) return;
      options.selectedCustomer.value = customer;
      options.drawerOpen.value = true;
    } finally {
      restoring = false;
    }
  };

  watch(
    () => [parseCustomerGroupFromQuery(route), options.tenantId.value] as const,
    () => {
      void restore();
    },
  );

  watch(
    options.customers,
    () => {
      const groupId = parseCustomerGroupFromQuery(route);
      if (!groupId || options.selectedCustomer.value?.customer_group_id === groupId) return;
      void restore();
    },
    { deep: true },
  );

  onMounted(() => {
    void restore();
  });
}