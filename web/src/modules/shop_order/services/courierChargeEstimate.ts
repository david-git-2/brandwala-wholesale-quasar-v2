import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import { dropshipCourierService } from './dropshipCourierService';

export interface CourierChargeEstimate {
  deliveryMin: number;
  deliveryMax: number;
  codPercentMin: number | null;
  codPercentMax: number | null;
  codFlatMin: number | null;
  codFlatMax: number | null;
}

const FALLBACK: CourierChargeEstimate = {
  deliveryMin: 60,
  deliveryMax: 130,
  codPercentMin: 1,
  codPercentMax: 1,
  codFlatMin: null,
  codFlatMax: null,
};

export function estimateFromCouriers(couriers: CourierServiceRow[]): CourierChargeEstimate {
  const active = couriers.filter((c) => c.is_active);
  const list = active.length ? active : couriers;
  if (!list.length) return { ...FALLBACK };

  const insides = list.map((c) => Number(c.inside_dhaka_fee || 0));
  const outsides = list.map((c) => Number(c.outside_dhaka_fee || 0));
  const deliveryMin = Math.min(...insides, ...outsides);
  const deliveryMax = Math.max(...insides, ...outsides);

  const percentRates = list
    .filter((c) => c.cod_fee_mode === 'percent_of_collect')
    .map((c) => Number(c.cod_fee_percent || 0));
  const flatRates = list
    .filter((c) => c.cod_fee_mode === 'flat')
    .map((c) => Number(c.cod_fee_flat_amount || 0));

  return {
    deliveryMin,
    deliveryMax,
    codPercentMin: percentRates.length ? Math.min(...percentRates) : null,
    codPercentMax: percentRates.length ? Math.max(...percentRates) : null,
    codFlatMin: flatRates.length ? Math.min(...flatRates) : null,
    codFlatMax: flatRates.length ? Math.max(...flatRates) : null,
  };
}

export async function fetchCourierChargeEstimate(): Promise<CourierChargeEstimate> {
  const res = await dropshipCourierService.fetchCouriers();
  if (!res.success || !res.data?.length) return { ...FALLBACK };
  return estimateFromCouriers(res.data);
}

export type DeliveryZone = 'inside_dhaka' | 'outside_dhaka';

export function resolveDeliveryZone(district: string): DeliveryZone {
  return district.trim().toLowerCase().includes('dhaka') ? 'inside_dhaka' : 'outside_dhaka';
}

export function suggestDeliveryFee(
  courier: Pick<CourierServiceRow, 'inside_dhaka_fee' | 'outside_dhaka_fee'>,
  zone: DeliveryZone,
): number {
  const fee = zone === 'inside_dhaka' ? courier.inside_dhaka_fee : courier.outside_dhaka_fee;
  return Number(fee || 0);
}

export interface SuggestCodFeeInput {
  faceSubtotal: number;
  deliveryCharge: number;
  deductDeliveryFromMargin: boolean;
  prepaid: boolean;
}

export function suggestCodFee(
  courier: Pick<CourierServiceRow, 'cod_fee_mode' | 'cod_fee_percent' | 'cod_fee_flat_amount'>,
  input: SuggestCodFeeInput,
): number {
  if (input.prepaid) return 0;

  const collectBase = input.faceSubtotal
    + (input.deductDeliveryFromMargin ? 0 : input.deliveryCharge);
  if (collectBase <= 0) return 0;

  switch (courier.cod_fee_mode) {
    case 'percent_of_collect':
      return Math.round(collectBase * Number(courier.cod_fee_percent || 0) / 100 * 100) / 100;
    case 'flat':
      return Number(courier.cod_fee_flat_amount || 0);
    case 'none':
    case 'tiered_manual':
    default:
      return 0;
  }
}
