import { ref, computed, watch, type Ref } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { thriftStockRepository, type ThriftStockPricingInput } from '../repositories/thriftStockRepository';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { ThriftStock } from '../types';
import ThriftStockMeasurementsDialog from '../components/ThriftStockMeasurementsDialog.vue';
import ThriftLandedCostBreakdownDialog from '../components/ThriftLandedCostBreakdownDialog.vue';
import {
  buildThriftCostBreakdownByStockId,
  type ThriftStockCostInput,
  type ThriftUnitCostBreakdown,
} from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';
import { isListedPriceLocked } from 'src/modules/thrift/shared/utils/thriftPricingLock';

export interface ShipmentOption {
  id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
  cargo_conversion_rate?: number | null;
  cargo_rate?: number | null;
  product_conversion_rate?: number | null;
  total_cargo_weight_kg?: number | null;
  labor_total_cost?: number | null;
  transportation_total_cost?: number | null;
  washing_total_cost?: number | null;
  default_markup_rate?: number | null;
}

export function useThriftStockCosting(
  stocks: Ref<ThriftStock[]>,
  shipmentById: Ref<Map<number, ShipmentOption>>,
  settings: Ref<any>,
  shipmentCostCurrency: (shipmentId: number | null | undefined) => ThriftCurrency | undefined,
) {
  const $q = useQuasar();
  const authStore = useAuthStore();

  const shipmentStocksCache = ref<Map<number, ThriftStock[]>>(new Map());

  function invalidateShipmentCache(shipmentId: number) {
    shipmentStocksCache.value.delete(shipmentId);
    shipmentStocksCache.value = new Map(shipmentStocksCache.value);
  }

  async function loadShipmentStocksForPage() {
    if (!authStore.tenantId) return;
    const shipmentIds = [...new Set(stocks.value.map((s) => s.shipment_id).filter(Boolean))];
    const promises = shipmentIds.map(async (id) => {
      if (shipmentStocksCache.value.has(id)) return;
      try {
        const list = await thriftStockRepository.fetchStocksForCostingByShipment(
          authStore.tenantId!,
          id,
        );
        shipmentStocksCache.value.set(id, list);
      } catch (err) {
        console.error(`Failed to load shipment stocks for shipment ${id}:`, err);
      }
    });
    await Promise.all(promises);
    shipmentStocksCache.value = new Map(shipmentStocksCache.value);
  }

  watch(stocks, () => {
    void loadShipmentStocksForPage();
  }, { immediate: true });

  const costBreakdownByStockId = computed<Record<number, ThriftUnitCostBreakdown>>(() => {
    const currentSettings = settings.value;
    if (!currentSettings) return {};

    const pageShipmentIds = new Set(stocks.value.map((s) => s.shipment_id).filter(Boolean));
    const pageStocksMap = new Map(stocks.value.map((s) => [s.id, s]));
    const mergedStocks: Array<ThriftStockCostInput & { id: number; shipment_id: number; pricing?: ThriftStockPricingInput | null }> = [];

    for (const shipmentId of pageShipmentIds) {
      const cached = shipmentStocksCache.value.get(shipmentId);
      if (cached && cached.length > 0) {
        for (const stock of cached) {
          const pageStock = pageStocksMap.get(stock.id);
          const targetStock = pageStock || stock;
          mergedStocks.push({
            id: targetStock.id,
            shipment_id: targetStock.shipment_id,
            quantity: targetStock.quantity || 0,
            product_weight: targetStock.product_weight ?? null,
            extra_weight: targetStock.extra_weight ?? null,
            origin_unit_price: targetStock.origin_unit_price ?? null,
            extra_origin_unit_price: targetStock.extra_origin_unit_price ?? null,
            additional_charges_cost: targetStock.additional_charges_cost ?? null,
            pricing: targetStock.pricing
              ? {
                  listed_unit_price: targetStock.pricing.listed_unit_price,
                  is_listed_price_manual: targetStock.pricing.is_listed_price_manual,
                  markup_rate_override: targetStock.pricing.markup_rate_override ?? null,
                }
              : null,
          });
        }
      } else {
        const shipmentPageStocks = stocks.value.filter((s) => s.shipment_id === shipmentId);
        for (const targetStock of shipmentPageStocks) {
          mergedStocks.push({
            id: targetStock.id,
            shipment_id: targetStock.shipment_id,
            quantity: targetStock.quantity || 0,
            product_weight: targetStock.product_weight ?? null,
            extra_weight: targetStock.extra_weight ?? null,
            origin_unit_price: targetStock.origin_unit_price ?? null,
            extra_origin_unit_price: targetStock.extra_origin_unit_price ?? null,
            additional_charges_cost: targetStock.additional_charges_cost ?? null,
            pricing: targetStock.pricing
              ? {
                  listed_unit_price: targetStock.pricing.listed_unit_price,
                  is_listed_price_manual: targetStock.pricing.is_listed_price_manual,
                  markup_rate_override: targetStock.pricing.markup_rate_override ?? null,
                }
              : null,
          });
        }
      }
    }

    return buildThriftCostBreakdownByStockId(mergedStocks, shipmentById.value, currentSettings);
  });

  function formatStockPrice(
    amount: number | null | undefined,
    currency: ThriftCurrency | undefined,
  ): string {
    if (amount == null) return '—';
    return formatThriftAmount(amount, currency);
  }

  function openMeasurementsDialog(row: ThriftStock) {
    $q.dialog({
      component: ThriftStockMeasurementsDialog,
      componentProps: {
        stock: row,
      },
    }).onOk((payload: { size: string; measurements: any }) => {
      row.size = payload.size;
      row.measurements = payload.measurements;
    });
  }

  function openLandedBreakdownDialog(row: ThriftStock) {
    const breakdown = costBreakdownByStockId.value[row.id];
    if (!breakdown) return;
    const shipment = shipmentById.value.get(row.shipment_id);
    $q.dialog({
      component: ThriftLandedCostBreakdownDialog,
      componentProps: {
        stock: row,
        breakdown,
        shipmentName: shipment?.name || '',
        formatCost: (amount: number) =>
          formatStockPrice(amount, shipmentCostCurrency(row.shipment_id)),
      },
    });
  }

  function itemMarkupPctForRow(row: ThriftStock): number | null {
    if (isListedPriceLocked(row.pricing)) return null;
    if (row.pricing?.markup_rate_override != null) {
      return Math.round(row.pricing.markup_rate_override * 1000) / 10;
    }
    const breakdown = costBreakdownByStockId.value[row.id];
    if (!breakdown) return null;
    return Math.round(breakdown.applied_markup_rate * 1000) / 10;
  }

  function effectiveMarkupLabel(row: ThriftStock): string {
    const breakdown = costBreakdownByStockId.value[row.id];
    if (!breakdown || breakdown.effective_markup_pct == null) return '—';
    return `${Math.round(breakdown.effective_markup_pct * 10) / 10}%`;
  }

  return {
    shipmentStocksCache,
    invalidateShipmentCache,
    costBreakdownByStockId,
    formatStockPrice,
    openMeasurementsDialog,
    openLandedBreakdownDialog,
    itemMarkupPctForRow,
    effectiveMarkupLabel,
  };
}
