import { computed, ref, onMounted } from 'vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';
import { STOCK_AVAILABILITY_OPTIONS } from '../constants/stockAvailability';
import { calculateShipmentCostSummary, costingShipmentFromEntries } from 'src/shared/shipment-engine';
import {
  isShipmentCostFinalized,
  sumProductEntryAmount,
} from '../utils/costEntriesCosting';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import type { GlobalCurrency } from 'src/modules/global_reference/types';
import type { ColumnKey } from '../components/ShipmentLineItemsTable.vue';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

const baseColumnOptions = [
  { label: 'Name', value: 'name' as ColumnKey },
  { label: 'Product Identifiers', value: 'product_codes' as ColumnKey },
  { label: 'Price GBP', value: 'purchase_price' as ColumnKey },
  { label: 'Cost BDT', value: 'cost_bdt' as ColumnKey },
  { label: 'Quantity', value: 'ordered_quantity' as ColumnKey },
  { label: 'Product Wt', value: 'product_weight' as ColumnKey },
  { label: 'Package Wt', value: 'package_weight' as ColumnKey },
  { label: 'Actions', value: 'actions' as ColumnKey },
];

const defaultColumns: ColumnKey[] = [
  'name',
  'product_codes',
  'purchase_price',
  'cost_bdt',
  'ordered_quantity',
  'product_weight',
  'package_weight',
  'actions',
];

const allColumnNames = baseColumnOptions.map((col) => col.value);
const alwaysVisibleColumns: ColumnKey[] = ['name', 'product_codes', 'actions'];

export function useInboundShipmentCalculations() {
  const shipmentStore = useGlobalShipmentStore();

  const currenciesList = ref<GlobalCurrency[]>([]);
  const loadingCurrencies = ref(false);

  const loadCurrencies = async () => {
    loadingCurrencies.value = true;
    try {
      currenciesList.value = await globalReferenceRepository.listCurrencies();
    } catch (err) {
      console.error('Failed to load currencies', err);
    } finally {
      loadingCurrencies.value = false;
    }
  };

  onMounted(() => {
    void loadCurrencies();
  });

  const currentPurchaseCurrency = computed(() => {
    const currencyId = shipmentStore.currentShipment?.shipment_purchase_currency_id;
    if (!currencyId) return null;
    return currenciesList.value.find((c) => c.id === currencyId) || null;
  });

  const currentPurchaseCurrencySymbol = computed(() => {
    return currentPurchaseCurrency.value?.symbol || '£';
  });

  const currentCostCurrency = computed(() => {
    const currencyId = shipmentStore.currentShipment?.shipment_cost_currency_id;
    if (!currencyId) return null;
    return currenciesList.value.find((c) => c.id === currencyId) || null;
  });

  const currentCostCurrencySymbol = computed(() => {
    return currentCostCurrency.value?.symbol || '৳';
  });

  const availableColumnOptions = computed(() => {
    const isIntl = shipmentStore.currentShipment?.type === 'international';
    return baseColumnOptions
      .filter((col) => {
        if (!isIntl) {
          return !['purchase_price', 'product_weight', 'package_weight'].includes(col.value);
        }
        return true;
      })
      .map((col) => {
        if (col.value === 'purchase_price') {
          return { ...col, label: `Price ${currentPurchaseCurrencySymbol.value}` };
        }
        if (col.value === 'cost_bdt') {
          return { ...col, label: `Cost ${currentCostCurrencySymbol.value}` };
        }
        return col;
      });
  });

  const { visibleColumns } = useMembershipColumnPreference<ColumnKey>({
    preferenceKey: 'ui.procurementShipment.detailsVisibleColumns',
    allColumnNames,
    alwaysVisibleColumns,
    defaultVisibleColumns: defaultColumns,
  });

  const allColumnsSelected = computed({
    get: () => availableColumnOptions.value.every((col) => visibleColumns.value.includes(col.value)),
    set: (val) => {
      visibleColumns.value = val
        ? availableColumnOptions.value.map((col) => col.value)
        : ['name', 'actions'];
    },
  });

  const currentShipmentBoxesTotal = computed(() => {
    return shipmentStore.currentShipmentBoxes.reduce((sum, box) => sum + (box.weight_kg || 0), 0);
  });

  const shipmentCargoWeightKg = computed(
    () =>
      shipmentStore.currentShipment?.total_weight_kg ??
      shipmentStore.currentShipment?.received_weight ??
      null,
  );

  const hasCargoInvoiceWeight = computed(() => {
    const rw = shipmentCargoWeightKg.value;
    return rw != null && rw > 0;
  });

  const totals = computed(() => {
    const shipment = shipmentStore.currentShipment;
    const items = shipmentStore.currentShipmentItems;
    if (!shipment) {
      return {
        quantity: 0,
        packagingWeightKg: 0,
        cargoWeightKg: 0,
        goodsPurchase: 0,
        cargoPurchase: 0,
        totalPurchase: 0,
        goodsCost: 0,
        cargoCost: 0,
        totalCost: 0,
        transactionRate: null,
        lineLandedCostTotal: 0,
      };
    }
    const forCosting = costingShipmentFromEntries(
      shipment,
      shipmentStore.currentCostEntries,
      items,
    );
    return calculateShipmentCostSummary(forCosting, items);
  });

  const cargoCostWeightLabel = computed(() => {
    if (hasCargoInvoiceWeight.value) {
      return `Based on ${totals.value.cargoWeightKg.toFixed(2)} kg cargo invoice weight`;
    }
    return `Based on ${totals.value.packagingWeightKg.toFixed(2)} kg estimated packaging weight`;
  });

  const transactionRateWeightLabel = computed(() => {
    if (totals.value.transactionRate === null) {
      return 'Add line items with prices to calculate';
    }
    if (hasCargoInvoiceWeight.value) {
      return `Based on ${totals.value.cargoWeightKg.toFixed(2)} kg cargo invoice weight · used for per-unit cost conversion`;
    }
    return 'Based on estimated packaging weight · used for per-unit cost conversion';
  });

  const shipmentForLiveCosting = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return null;
    const fromEntries = costingShipmentFromEntries(
      shipment,
      shipmentStore.currentCostEntries,
      shipmentStore.currentShipmentItems,
    );
    return {
      ...shipment,
      ...fromEntries,
    } as unknown as GlobalShipment;
  });

  const isEditable = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    return shipment.status !== 'received' && shipment.status !== 'cancelled';
  });

  const isCostFinalized = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    return isShipmentCostFinalized(shipment);
  });

  const canEditCosts = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    if (shipment.status === 'cancelled') return false;
    return isEditable.value || isCostFinalized.value;
  });

  const hasLineItems = computed(() => (shipmentStore.currentShipmentItems?.length ?? 0) > 0);

  const weightNeedsAttention = computed(() => {
    if (!hasCargoInvoiceWeight.value) return false;
    return Math.abs(totals.value.packagingWeightKg - totals.value.cargoWeightKg) > 0.01;
  });

  const purchaseNeedsAttention = computed(() => {
    const invoice = sumProductEntryAmount(shipmentStore.currentCostEntries);
    if (invoice <= 0) return false;
    return Math.abs(invoice - totals.value.goodsPurchase) > 0.05;
  });

  const hasProductInvoiceTotal = computed(
    () => sumProductEntryAmount(shipmentStore.currentCostEntries) > 0,
  );

  const balanceNeedsAttention = computed(
    () => weightNeedsAttention.value || purchaseNeedsAttention.value,
  );

  const showReceiveTab = computed(() => {
    const status = shipmentStore.currentShipment?.status;
    return status === 'received';
  });

  const isSplitsComplete = computed(() => {
    const items = shipmentStore.currentShipmentItems;
    const stocks = shipmentStore.currentShipmentStocks || [];
    if (!items.length) return false;
    return items.every((item) => {
      const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id);
      const sum = itemStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
      return sum === item.ordered_quantity;
    });
  });

  const receiveNeedsAttention = computed(() => {
    return (
      shipmentStore.currentShipment?.status === 'in_transit' && !isSplitsComplete.value
    );
  });

  const splitsSummary = computed(() => {
    const stocks = shipmentStore.currentShipmentStocks || [];

    const breakdown = STOCK_AVAILABILITY_OPTIONS.map((opt) => {
      const totalQty = stocks
        .filter((s) => (s.availability || 'sellable') === opt.value)
        .reduce((sum, s) => sum + (s.quantity || 0), 0);
      return {
        id: opt.value,
        description: opt.label,
        is_sellable: opt.value === 'sellable',
        quantity: totalQty,
      };
    });

    const totalAllocated = breakdown.reduce((sum, item) => sum + item.quantity, 0);
    const totalOrdered = shipmentStore.currentShipmentItems.reduce(
      (sum, item) => sum + (item.ordered_quantity || 0),
      0,
    );

    return {
      breakdown: breakdown.filter((item) => item.quantity > 0),
      totalAllocated,
      totalOrdered,
      isComplete: totalAllocated === totalOrdered && totalOrdered > 0,
    };
  });

  return {
    totals,
    cargoCostWeightLabel,
    transactionRateWeightLabel,
    shipmentForLiveCosting,
    currentShipmentBoxesTotal,
    hasCargoInvoiceWeight,
    isEditable,
    isCostFinalized,
    canEditCosts,
    hasLineItems,
    weightNeedsAttention,
    purchaseNeedsAttention,
    hasProductInvoiceTotal,
    balanceNeedsAttention,
    showReceiveTab,
    receiveNeedsAttention,
    isSplitsComplete,
    splitsSummary,
    availableColumnOptions,
    visibleColumns,
    allColumnsSelected,
    currentPurchaseCurrencySymbol,
    currentCostCurrencySymbol,
    loadingCurrencies,
  };
}
