import { computed } from 'vue';
import type { Ref } from 'vue';
import type { ThriftShipment } from '../../shipment/types';
import type { ThriftStock } from '../../stock/types';
import type { ThriftSettings } from '../../settings/types';
import {
  computeShipmentUnitCount,
  computeShipmentCargoCost,
  computeShipmentOpsCost,
  computeShipmentTotalWeightKg,
  buildThriftCostBreakdownByStockId,
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

  const cargoSharePerUnit = computed(() => {
    const breakdowns = costingBreakdowns.value;
    let weightedCargo = 0;
    let qty = 0;
    for (const stock of stocksRef.value) {
      const breakdown = breakdowns[stock.id];
      if (!breakdown) continue;
      const stockQty = stock.quantity || 0;
      weightedCargo += breakdown.cargo_share_per_unit * stockQty;
      qty += stockQty;
    }
    if (qty > 0) return weightedCargo / qty;
    return cargoCost.value / Math.max(U.value, 1);
  });

  const shipmentTotalWeightKg = computed(() => {
    return computeShipmentTotalWeightKg(
      stocksRef.value.map((stock) => ({
        id: stock.id,
        quantity: stock.quantity || 0,
        product_weight: stock.product_weight ?? null,
        extra_weight: stock.extra_weight ?? null,
      })),
    );
  });

  const usesWeightBasedCargo = computed(() => shipmentTotalWeightKg.value > 0);

  const opsSharePerUnit = computed(() => {
    return opsCost.value / Math.max(U.value, 1);
  });

  const handTagTotal = computed(() => {
    const settings = settingsRef.value;
    if (!settings) return 0;
    return (Number(settings.hand_tag_unit_cost) || 0) * U.value;
  });

  const stickerTotal = computed(() => {
    const settings = settingsRef.value;
    if (!settings) return 0;
    return (Number(settings.sticker_unit_cost) || 0) * U.value;
  });

  const costingBreakdowns = computed(() => {
    const shipment = shipmentRef.value;
    const settings = settingsRef.value;
    if (!shipment || !settings) return {};

    const shipmentById = new Map<number, ThriftShipment>([[shipment.id, shipment]]);
    const stocksInput = stocksRef.value.map((stock) => ({
      id: stock.id,
      shipment_id: shipment.id,
      quantity: stock.quantity || 0,
      product_weight: stock.product_weight ?? null,
      extra_weight: stock.extra_weight ?? null,
      origin_unit_price: stock.origin_unit_price ?? null,
      extra_origin_unit_price: stock.extra_origin_unit_price ?? null,
      additional_charges_cost: stock.additional_charges_cost ?? null,
      pricing: stock.pricing
        ? {
            listed_unit_price: stock.pricing.listed_unit_price,
            is_listed_price_manual: stock.pricing.is_listed_price_manual,
            markup_rate_override: stock.pricing.markup_rate_override ?? null,
          }
        : null,
    }));

    return buildThriftCostBreakdownByStockId(stocksInput, shipmentById, settings);
  });

  return {
    U,
    cargoCost,
    opsCost,
    cargoSharePerUnit,
    opsSharePerUnit,
    handTagTotal,
    stickerTotal,
    shipmentTotalWeightKg,
    usesWeightBasedCargo,
    costingBreakdowns,
  };
}
