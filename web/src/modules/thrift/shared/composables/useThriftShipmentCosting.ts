import { computed } from 'vue';
import type { Ref } from 'vue';
import type { ThriftShipment } from '../../shipment/types';
import type { ThriftStock } from '../../stock/types';
import type { ThriftSettings } from '../../settings/types';
import {
  computeShipmentUnitCount,
  computeShipmentCargoCost,
  computeShipmentOpsCost,
  computeThriftUnitCostsForShipment,
  type ThriftStockPricingInput,
} from '../utils/computeThriftUnitCosts';

export function useThriftShipmentCosting(
  shipmentRef: Ref<ThriftShipment | null | undefined>,
  stocksRef: Ref<ThriftStock[]>,
  settingsRef: Ref<ThriftSettings | null | undefined>,
) {
  const U = computed(() => {
    return computeShipmentUnitCount(stocksRef.value);
  });

  const cargoCost = computed(() => {
    const shipment = shipmentRef.value;
    if (!shipment) return 0;
    return computeShipmentCargoCost(shipment);
  });

  const opsCost = computed(() => {
    const shipment = shipmentRef.value;
    const settings = settingsRef.value;
    if (!shipment || !settings) return 0;
    return computeShipmentOpsCost(shipment, settings, U.value);
  });

  const costingBreakdowns = computed(() => {
    const shipment = shipmentRef.value;
    const settings = settingsRef.value;
    if (!shipment || !settings) return {};

    const pricingMap: Record<number, ThriftStockPricingInput> = {};
    for (const stock of stocksRef.value) {
      if (stock.pricing) {
        pricingMap[stock.id] = {
          listed_unit_price: stock.pricing.listed_unit_price,
          is_listed_price_manual: stock.pricing.is_listed_price_manual,
        };
      }
    }

    return computeThriftUnitCostsForShipment(
      stocksRef.value,
      shipment,
      settings,
      pricingMap,
    );
  });

  return {
    U,
    cargoCost,
    opsCost,
    costingBreakdowns,
  };
}
