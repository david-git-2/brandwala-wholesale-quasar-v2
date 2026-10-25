import { computed, ref, watch, type Ref } from 'vue';
import { useMutation, useQuery } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  staffManualDropshipOrderRepository,
  type StaffDropshipListingRow,
  type StaffDropshipOrderLineInput,
} from '../repositories/staffManualDropshipOrderRepository';
import { useBooksCustomerGroupsQuery } from './useBooksCustomerGroupsQuery';

export interface ManualDropshipLineItem {
  localId: string;
  product_id: number;
  listing_id: number;
  grade_tag_id: number;
  global_stock_id: number | null;
  name: string;
  image_url: string | null;
  quantity: number;
  customer_sell_price_amount: number;
  customer_sell_price_currency_id: number;
  unit_sell_price_amount: number;
  minimum_sell_price_amount: number | null;
  available_to_sell: number;
}

function defaultCustomerSell(row: StaffDropshipListingRow): number {
  const sell = Number(row.sell_price_amount);
  const min = row.minimum_sell_price_amount != null ? Number(row.minimum_sell_price_amount) : 0;
  if (
    row.minimum_sell_price_currency_id != null &&
    row.sell_price_currency_id === row.minimum_sell_price_currency_id
  ) {
    return Math.max(sell, min);
  }
  return sell;
}

function nextLocalId(): string {
  return `line-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export function useManualDropshipOrder(options: {
  tenantId: Ref<number>;
  parentTenantId: Ref<number | null | undefined>;
}) {
  const selectedShopId = ref<number | null>(null);
  const selectedCustomerGroupId = ref<number | null>(null);
  const itemSearch = ref('');
  const debouncedSearch = ref('');
  const lineItems = ref<ManualDropshipLineItem[]>([]);

  const recipientName = ref('');
  const recipientPhone = ref('');
  const recipientPhoneSecondary = ref('');
  const shippingAddress = ref('');
  const shippingDistrict = ref('');
  const shippingThana = ref('');
  const deliveryInstructions = ref('');

  const submitItemSearch = () => {
    debouncedSearch.value = itemSearch.value.trim();
  };

  const clearItemSearch = () => {
    itemSearch.value = '';
    debouncedSearch.value = '';
  };

  const booksCustomerGroupsQuery = useBooksCustomerGroupsQuery(
    options.tenantId,
    options.parentTenantId,
  );

  const customerGroupOptions = computed(() => {
    const groups = booksCustomerGroupsQuery.data.value ?? [];
    return groups.filter((g) => g.is_active);
  });

  const contextReady = computed(
    () => (selectedShopId.value ?? 0) > 0 && (selectedCustomerGroupId.value ?? 0) > 0,
  );

  const browseQuery = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.staffManualDropshipBrowse(
        options.tenantId.value,
        selectedShopId.value ?? 0,
        selectedCustomerGroupId.value ?? 0,
        debouncedSearch.value,
      ),
    ),
    queryFn: () =>
      staffManualDropshipOrderRepository.browseListings(
        options.tenantId.value,
        selectedShopId.value!,
        selectedCustomerGroupId.value!,
        debouncedSearch.value,
      ),
    enabled: computed(() => contextReady.value && debouncedSearch.value.length >= 2),
    refetchOnWindowFocus: false,
  });

  const listings = computed<StaffDropshipListingRow[]>(() => browseQuery.data.value ?? []);

  const items = computed(() => lineItems.value);

  const currencySymbol = computed(() => '৳');

  const getLineUnitPrice = (item: ManualDropshipLineItem) => item.customer_sell_price_amount;

  const totalQtyForListing = (listingId: number, excludeLocalId?: string) =>
    lineItems.value
      .filter((l) => l.listing_id === listingId && l.localId !== excludeLocalId)
      .reduce((sum, l) => sum + l.quantity, 0);

  const addListing = (row: StaffDropshipListingRow) => {
    const existing = lineItems.value.find((l) => l.listing_id === row.listing_id);
    const nextQty = (existing?.quantity ?? 0) + 1;
    if (nextQty > row.available_to_sell) {
      throw new Error(`Only ${row.available_to_sell} available`);
    }
    if (existing) {
      lineItems.value = lineItems.value.map((l) =>
        l.localId === existing.localId ? { ...l, quantity: nextQty } : l,
      );
      clearItemSearch();
      return;
    }
    const sell = defaultCustomerSell(row);
    lineItems.value = [
      ...lineItems.value,
      {
        localId: nextLocalId(),
        product_id: row.product_id,
        listing_id: row.listing_id,
        grade_tag_id: row.grade_tag_id,
        global_stock_id: row.global_stock_id,
        name: row.product_name,
        image_url: row.product_image_url,
        quantity: 1,
        customer_sell_price_amount: sell,
        customer_sell_price_currency_id: row.sell_price_currency_id,
        unit_sell_price_amount: Number(row.sell_price_amount),
        minimum_sell_price_amount: row.minimum_sell_price_amount,
        available_to_sell: row.available_to_sell,
      },
    ];
    clearItemSearch();
  };

  const setLineQuantity = (localId: string, quantity: number) => {
    const line = lineItems.value.find((l) => l.localId === localId);
    if (!line) return;
    if (quantity <= 0) {
      removeLine(localId);
      return;
    }
    const otherQty = totalQtyForListing(line.listing_id, localId);
    if (otherQty + quantity > line.available_to_sell) {
      throw new Error(`Only ${line.available_to_sell} available`);
    }
    lineItems.value = lineItems.value.map((l) =>
      l.localId === localId ? { ...l, quantity } : l,
    );
  };

  const removeLine = (localId: string) => {
    lineItems.value = lineItems.value.filter((l) => l.localId !== localId);
  };

  const setLineSellPrice = (localId: string, amount: number) => {
    if (!Number.isFinite(amount) || amount < 0) return;
    lineItems.value = lineItems.value.map((l) =>
      l.localId === localId ? { ...l, customer_sell_price_amount: amount } : l,
    );
  };

  const lineResellBelowMin = (item: ManualDropshipLineItem) => {
    const min = item.minimum_sell_price_amount;
    if (min == null || min <= 0) return false;
    return item.customer_sell_price_amount < min;
  };

  const toSubmitItems = (): StaffDropshipOrderLineInput[] =>
    lineItems.value.map((l) => ({
      product_id: l.product_id,
      listing_id: l.listing_id,
      grade_tag_id: l.grade_tag_id,
      global_stock_id: l.global_stock_id,
      quantity: l.quantity,
      customer_sell_price_amount: l.customer_sell_price_amount,
      customer_sell_price_currency_id: l.customer_sell_price_currency_id,
    }));

  const submitMutation = useMutation({
    mutationFn: () =>
      staffManualDropshipOrderRepository.createOrder(
        selectedShopId.value!,
        selectedCustomerGroupId.value!,
        toSubmitItems(),
        {
          recipientName: recipientName.value.trim(),
          recipientPhone: recipientPhone.value.trim(),
          shippingAddress: shippingAddress.value.trim(),
          recipientPhoneSecondary: recipientPhoneSecondary.value.trim() || null,
          shippingDistrict: shippingDistrict.value.trim() || null,
          shippingThana: shippingThana.value.trim() || null,
          deliveryInstructions: deliveryInstructions.value.trim() || null,
        },
      ),
  });

  const clearLines = () => {
    lineItems.value = [];
  };

  watch(selectedShopId, () => {
    selectedCustomerGroupId.value = null;
    clearLines();
  });

  watch(selectedCustomerGroupId, () => {
    clearLines();
  });

  const isBusy = computed(() => submitMutation.isPending.value);

  const canSubmit = computed(
    () =>
      contextReady.value &&
      lineItems.value.length > 0 &&
      !lineItems.value.some(lineResellBelowMin) &&
      recipientName.value.trim() &&
      recipientPhone.value.trim() &&
      shippingAddress.value.trim() &&
      !isBusy.value,
  );

  return {
    selectedShopId,
    selectedCustomerGroupId,
    itemSearch,
    activeSearch: debouncedSearch,
    submitItemSearch,
    recipientName,
    recipientPhone,
    recipientPhoneSecondary,
    shippingAddress,
    shippingDistrict,
    shippingThana,
    deliveryInstructions,
    customerGroupOptions,
    booksCustomerGroupsQuery,
    browseQuery,
    listings,
    items,
    currencySymbol,
    getLineUnitPrice,
    addListing,
    setLineQuantity,
    setLineSellPrice,
    removeLine,
    submitMutation,
    isBusy,
    canSubmit,
  };
}
