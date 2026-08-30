import { computed } from 'vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';
import { calculateShipmentCostSummary, costingShipmentFromEntries } from 'src/shared/shipment-engine';
import {
  isShipmentStockPosted,
  isShipmentCostsLocked,
  sumProductEntryAmount,
} from '../utils/costEntriesCosting';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import type { GlobalCurrency } from 'src/modules/global_reference/types';
export function useInboundShipmentCalculations() {
  const shipmentStore = useGlobalShipmentStore();
  const { data: currenciesData, isLoading: loadingCurrencies } = useGlobalCurrenciesQuery();

  const currenciesList = computed<GlobalCurrency[]>(() => currenciesData.value ?? []);

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

  const isStockPosted = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    return isShipmentStockPosted(shipment);
  });

  const isCostsLocked = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    return isShipmentCostsLocked(shipment);
  });

  /** @deprecated Use isStockPosted */
  const isCostFinalized = computed(() => isStockPosted.value);

  const canEditLineStructure = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    if (shipment.status === 'cancelled' || isCostsLocked.value) return false;
    return shipment.status !== 'received';
  });

  const isEditable = computed(() => canEditLineStructure.value);

  const canEditCosts = computed(() => {
    const shipment = shipmentStore.currentShipment;
    if (!shipment) return false;
    if (shipment.status === 'cancelled' || isCostsLocked.value) return false;
    return true;
  });

  const canEditLineCostFields = computed(() => canEditCosts.value);

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

  return {
    totals,
    cargoCostWeightLabel,
    transactionRateWeightLabel,
    shipmentForLiveCosting,
    currentShipmentBoxesTotal,
    hasCargoInvoiceWeight,
    isStockPosted,
    isCostsLocked,
    isEditable,
    isCostFinalized,
    canEditCosts,
    canEditLineStructure,
    canEditLineCostFields,
    hasLineItems,
    weightNeedsAttention,
    purchaseNeedsAttention,
    hasProductInvoiceTotal,
    balanceNeedsAttention,
    currentPurchaseCurrencySymbol,
    currentCostCurrencySymbol,
    loadingCurrencies,
  };
}
