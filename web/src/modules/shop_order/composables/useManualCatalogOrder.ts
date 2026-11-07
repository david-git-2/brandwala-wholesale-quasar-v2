import { computed, onBeforeUnmount, ref, watch, type Ref } from 'vue';
import { useMutation, useQuery } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import {
  staffManualCatalogOrderRepository,
  type StaffCatalogOrderCreateMode,
  type StaffCatalogOrderLineInput,
  type StaffCatalogOrderRatesInput,
} from '../repositories/staffManualCatalogOrderRepository';
import { useBooksCustomerGroupsQuery } from './useBooksCustomerGroupsQuery';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import type { Product } from 'src/modules/products/types';
import type { ShopCatalogItem } from '../types';

export type ManualCatalogCreateTab = 'standard' | 'old_order';

export type ManualCatalogSubmitBlocker =
  | 'submitting'
  | 'customer_group'
  | 'order_date'
  | 'no_lines'
  | 'line_sell_required'
  | 'old_order_rates';

export type OldOrderStatus = 'procuring' | 'delivered' | 'closed';

export interface ManualCatalogLineItem {
  localId: string;
  product_id: number;
  name: string;
  image_url: string | null;
  product_barcode?: string | null;
  product_code?: string | null;
  quantity: number;
  cost_price_amount?: number | null;
  sell_price_amount?: number | null;
}

function nextLocalId(): string {
  return `line-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export function productRowToCatalogItem(p: Product): ShopCatalogItem {
  return {
    product_id: p.id,
    product_name: p.name ?? '',
    product_image_url: p.image_url,
    product_barcode: p.barcode,
    product_code: p.product_code,
    product_brand: p.brand,
    product_category: p.category,
    vendor_code: p.vendor_code,
    is_available: true,
    unit_price: null,
    sell_price: null,
    resell_minimum_price: null,
    available_units: p.available_units,
    unit_price_amount: p.list_price_amount,
    global_stock_allocation_id: null,
    global_stock_id: null,
  };
}

function defaultPurchaseGbpFromCatalogRow(row: ShopCatalogItem): number | null {
  const raw = row.unit_price_amount ?? row.unit_price?.amount;
  if (raw == null || raw === '') return null;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

export async function browseManualCatalogProducts(
  tenantId: number,
  shopIds: number[],
  search: string,
): Promise<ShopCatalogItem[]> {
  if (shopIds.length > 0) {
    const pages = await Promise.all(
      shopIds.map((shopId) =>
        shopOrderRepository.browseShopCatalogForAdmin(tenantId, shopId, {
          search: search || null,
          limit: 24,
          includeBelowMinUnits: true,
        }),
      ),
    );
    return mergeCatalogItems(pages.flatMap((p) => p.data ?? []));
  }
  const page = await productRepository.listProducts({
    tenantId,
    search,
    pageSize: 24,
  });
  return (page.data ?? []).map(productRowToCatalogItem);
}

function mergeCatalogItems(pages: ShopCatalogItem[]): ShopCatalogItem[] {
  const byId = new Map<number, ShopCatalogItem>();
  for (const row of pages) {
    if (!byId.has(row.product_id)) byId.set(row.product_id, row);
  }
  return [...byId.values()].sort((a, b) => a.product_name.localeCompare(b.product_name));
}

export function useManualCatalogOrder(options: {
  tenantId: Ref<number>;
  parentTenantId: Ref<number | null | undefined>;
  vendorCatalogShopIds: Ref<number[]>;
}) {
  const createTab = ref<ManualCatalogCreateTab>('standard');
  const selectedShopId = ref<number | null>(null);
  const selectedCustomerGroupId = ref<number | null>(null);
  const itemSearch = ref('');
  const debouncedSearch = ref('');
  const lineItems = ref<ManualCatalogLineItem[]>([]);
  const recordedAtDate = ref('');
  const hiddenFromCustomer = ref(true);

  const oldOrderInitialStatus = ref<OldOrderStatus>('procuring');
  const oldOrderRates = ref<StaffCatalogOrderRatesInput>({
    conversion_rate: 1,
    cargo_rate: 0,
    profit_rate: 0,
    profit_basis: 'total_cost',
  });

  let itemSearchDebounceTimer: ReturnType<typeof setTimeout> | undefined;

  const applyItemSearchQuery = (raw: string) => {
    const trimmed = raw.trim();
    debouncedSearch.value = trimmed.length >= 2 ? trimmed : '';
  };

  const submitItemSearch = () => {
    if (itemSearchDebounceTimer) {
      clearTimeout(itemSearchDebounceTimer);
      itemSearchDebounceTimer = undefined;
    }
    applyItemSearchQuery(itemSearch.value);
  };

  watch(itemSearch, (value) => {
    if (itemSearchDebounceTimer) {
      clearTimeout(itemSearchDebounceTimer);
    }
    const trimmed = value.trim();
    if (trimmed.length < 2) {
      debouncedSearch.value = '';
      return;
    }
    itemSearchDebounceTimer = setTimeout(() => {
      applyItemSearchQuery(trimmed);
      itemSearchDebounceTimer = undefined;
    }, 300);
  });

  onBeforeUnmount(() => {
    if (itemSearchDebounceTimer) {
      clearTimeout(itemSearchDebounceTimer);
    }
  });

  const booksCustomerGroupsQuery = useBooksCustomerGroupsQuery(
    options.tenantId,
    options.parentTenantId,
  );

  const customerGroupOptions = computed(() => {
    const groups = booksCustomerGroupsQuery.data.value ?? [];
    return groups.filter((g) => g.is_active);
  });

  const browseShopIds = computed(() => {
    if (selectedShopId.value) return [selectedShopId.value];
    return options.vendorCatalogShopIds.value;
  });

  const browseShopScopeKey = computed(() => {
    if (selectedShopId.value) return String(selectedShopId.value);
    return [...browseShopIds.value].sort((a, b) => a - b).join(',');
  });

  const browseQuery = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.staffManualCatalogBrowse(
        options.tenantId.value,
        selectedShopId.value ?? 0,
        debouncedSearch.value,
        browseShopScopeKey.value,
      ),
    ),
    queryFn: async () => {
      const data = await browseManualCatalogProducts(
        options.tenantId.value,
        browseShopIds.value,
        debouncedSearch.value,
      );
      return {
        data,
        meta: { has_more: false, next_cursor: null, limit: 24 },
      };
    },
    enabled: computed(() => debouncedSearch.value.length >= 2),
    refetchOnWindowFocus: false,
  });

  const listings = computed(() => browseQuery.data.value?.data ?? []);

  const items = computed(() => lineItems.value);

  const isOldOrderTab = computed(() => createTab.value === 'old_order');

  const addProduct = (
    row: ShopCatalogItem,
    quantity = 1,
    opts?: { sellPrice?: number; costPrice?: number },
  ) => {
    const qty = Math.max(1, Math.floor(quantity));
    const existing = lineItems.value.find((l) => l.product_id === row.product_id);
    if (existing) {
      existing.quantity += qty;
      if (isOldOrderTab.value && opts?.sellPrice != null && Number.isFinite(opts.sellPrice)) {
        existing.sell_price_amount = opts.sellPrice;
      }
      if (isOldOrderTab.value && opts?.costPrice != null && Number.isFinite(opts.costPrice)) {
        existing.cost_price_amount = opts.costPrice;
      }
      itemSearch.value = '';
      debouncedSearch.value = '';
      return;
    }
    const purchaseGbp =
      opts?.costPrice != null && Number.isFinite(opts.costPrice)
        ? opts.costPrice
        : defaultPurchaseGbpFromCatalogRow(row);
    lineItems.value.push({
      localId: nextLocalId(),
      product_id: row.product_id,
      name: row.product_name,
      image_url: row.product_image_url,
      product_barcode: row.product_barcode,
      product_code: row.product_code,
      quantity: qty,
      cost_price_amount: isOldOrderTab.value ? purchaseGbp : undefined,
      sell_price_amount: isOldOrderTab.value ? (opts?.sellPrice ?? null) : undefined,
    });
    itemSearch.value = '';
    debouncedSearch.value = '';
  };

  const setLineQuantity = (localId: string, qty: number) => {
    const line = lineItems.value.find((l) => l.localId === localId);
    if (!line) return;
    line.quantity = Math.max(1, Math.floor(qty));
  };

  const setLineCostPrice = (localId: string, amount: number) => {
    const line = lineItems.value.find((l) => l.localId === localId);
    if (!line) return;
    line.cost_price_amount = Math.max(0, Number(amount) || 0);
  };

  const setLineSellPrice = (localId: string, amount: number) => {
    const line = lineItems.value.find((l) => l.localId === localId);
    if (!line) return;
    line.sell_price_amount = Math.max(0, Number(amount) || 0);
  };

  const removeLine = (localId: string) => {
    lineItems.value = lineItems.value.filter((l) => l.localId !== localId);
  };

  const findProductByKey = async (key: string): Promise<ShopCatalogItem | null> => {
    const needle = key.trim();
    if (!needle) return null;
    const norm = (v: string | null | undefined) => (v ?? '').trim().toLowerCase();
    const target = norm(needle);

    const hits = await browseManualCatalogProducts(
      options.tenantId.value,
      browseShopIds.value,
      needle,
    );
    const exact =
      hits.find((p) => norm(p.product_barcode) === target || norm(p.product_code) === target) ??
      hits[0] ??
      null;
    return exact;
  };

  const applyBulkKeys = async (
    lines: {
      key: string;
      quantity: number;
      cost_price_amount?: number;
      sell_price_amount?: number;
    }[],
  ): Promise<{ added: number; missing: string[] }> => {
    const missing: string[] = [];
    let added = 0;
    for (const line of lines) {
      const product = await findProductByKey(line.key);
      if (!product) {
        missing.push(line.key);
        continue;
      }
      addProduct(product, line.quantity, {
        sellPrice: line.sell_price_amount,
      });
      added += 1;
    }
    return { added, missing };
  };

  watch([selectedShopId, selectedCustomerGroupId], () => {
    lineItems.value = [];
    itemSearch.value = '';
    debouncedSearch.value = '';
  });

  watch(createTab, () => {
    lineItems.value = [];
    itemSearch.value = '';
    debouncedSearch.value = '';
  });

  const toRecordedAtIso = (): string => {
    const raw = recordedAtDate.value.trim();
    if (!raw) {
      throw new Error('Order date is required');
    }
    return `${raw}T12:00:00.000Z`;
  };

  const ratesValid = computed(() => {
    if (!isOldOrderTab.value) return true;
    const r = oldOrderRates.value;
    return (
      r.conversion_rate != null &&
      Number.isFinite(r.conversion_rate) &&
      r.cargo_rate != null &&
      Number.isFinite(r.cargo_rate) &&
      r.profit_rate != null &&
      Number.isFinite(r.profit_rate) &&
      !!r.profit_basis
    );
  });

  const linesValid = computed(() => {
    if (lineItems.value.length === 0) return false;
    if (!isOldOrderTab.value) return true;
    return lineItems.value.every(
      (l) =>
        l.sell_price_amount != null &&
        Number.isFinite(l.sell_price_amount) &&
        l.sell_price_amount >= 0,
    );
  });

  const submitMutation = useMutation({
    mutationFn: async () => {
      if (!selectedCustomerGroupId.value) {
        throw new Error('Select customer group');
      }
      const shopId = await staffManualCatalogOrderRepository.resolveVendorCatalogShopForCreate({
        tenantId: options.tenantId.value,
        parentTenantId: options.parentTenantId?.value ?? null,
        customerGroupId: selectedCustomerGroupId.value,
        selectedShopId: selectedShopId.value,
        knownVendorCatalogShopIds: options.vendorCatalogShopIds.value,
      });
      const mode: StaffCatalogOrderCreateMode = isOldOrderTab.value ? 'old_order' : 'standard';
      const payload: StaffCatalogOrderLineInput[] = lineItems.value.map((l) => {
        const base = { product_id: l.product_id, quantity: l.quantity };
        if (mode === 'old_order') {
          const row: StaffCatalogOrderLineInput = {
            ...base,
            sell_price_amount: Number(l.sell_price_amount ?? 0),
          };
          if (l.cost_price_amount != null && Number.isFinite(l.cost_price_amount)) {
            row.cost_price_amount = Number(l.cost_price_amount);
          }
          return row;
        }
        return base;
      });
      return staffManualCatalogOrderRepository.createOrder(shopId, selectedCustomerGroupId.value, payload, {
        recordedAt: toRecordedAtIso(),
        hiddenFromCustomer: hiddenFromCustomer.value,
        createMode: mode,
        initialStatus: mode === 'old_order' ? oldOrderInitialStatus.value : undefined,
        rates: mode === 'old_order' ? { ...oldOrderRates.value } : undefined,
      });
    },
  });

  const canSubmit = computed(
    () =>
      (selectedCustomerGroupId.value ?? 0) > 0 &&
      recordedAtDate.value.trim().length > 0 &&
      linesValid.value &&
      ratesValid.value &&
      !submitMutation.isPending.value,
  );

  const submitBlocker = computed((): ManualCatalogSubmitBlocker | null => {
    if (canSubmit.value) return null;
    if (submitMutation.isPending.value) return 'submitting';
    if (!(selectedCustomerGroupId.value ?? 0)) return 'customer_group';
    if (!recordedAtDate.value.trim()) return 'order_date';
    if (lineItems.value.length === 0) return 'no_lines';
    if (isOldOrderTab.value) {
      const missingSell = lineItems.value.some(
        (l) =>
          l.sell_price_amount == null ||
          !Number.isFinite(l.sell_price_amount) ||
          l.sell_price_amount < 0,
      );
      if (missingSell) return 'line_sell_required';
      if (!ratesValid.value) return 'old_order_rates';
    }
    return null;
  });

  const hasDraftChanges = computed(
    () =>
      lineItems.value.length > 0 ||
      (selectedCustomerGroupId.value ?? 0) > 0 ||
      recordedAtDate.value.trim().length > 0 ||
      selectedShopId.value != null ||
      !hiddenFromCustomer.value ||
      (isOldOrderTab.value &&
        (oldOrderInitialStatus.value !== 'procuring' ||
          oldOrderRates.value.conversion_rate !== 1 ||
          oldOrderRates.value.cargo_rate !== 0)),
  );

  const isBusy = computed(() => submitMutation.isPending.value);

  return {
    createTab,
    selectedShopId,
    selectedCustomerGroupId,
    itemSearch,
    debouncedSearch,
    submitItemSearch,
    recordedAtDate,
    hiddenFromCustomer,
    oldOrderInitialStatus,
    oldOrderRates,
    customerGroupOptions,
    booksCustomerGroupsQuery,
    browseQuery,
    listings,
    browseShopIds,
    items,
    lineItems,
    isOldOrderTab,
    addProduct,
    setLineQuantity,
    setLineCostPrice,
    setLineSellPrice,
    removeLine,
    applyBulkKeys,
    submitMutation,
    isBusy,
    canSubmit,
    submitBlocker,
    hasDraftChanges,
  };
}
