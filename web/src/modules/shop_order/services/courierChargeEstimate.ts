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
