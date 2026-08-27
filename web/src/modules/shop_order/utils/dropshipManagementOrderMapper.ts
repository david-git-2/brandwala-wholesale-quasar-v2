import type {
  DropshipManagementOrderResponse,
  DropshipManagementOrderView,
  DropshipSettlementChargeLine,
  DropshipSettlementChargePayer,
  DropshipSettlementChargeType,
  DropshipSettlementDraftPayload,
  DropshipSettlementStatus,
} from '../types/dropshipManagementOrder';
import type { ShopOrderStatus } from '../types';

const num = (value: unknown, fallback = 0): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const str = (value: unknown, fallback = ''): string =>
  value == null ? fallback : String(value);

const payer = (value: unknown): DropshipSettlementChargePayer => {
  const v = str(value, 'recipient');
  if (v === 'merchant' || v === 'company') return v;
  return 'recipient';
};

const chargeType = (value: unknown): DropshipSettlementChargeType => {
  const v = str(value, 'delivery');
  if (v === 'print' || v === 'packing' || v === 'return' || v === 'cod') return v;
  return 'delivery';
};

function mapChargeLines(raw: unknown): DropshipSettlementChargeLine[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((line) => {
    const row = (line ?? {}) as Record<string, unknown>;
    return {
      charge_type: chargeType(row.charge_type),
      amount: num(row.amount),
      payer: payer(row.payer),
    };
  });
}

function defaultChargeLine(type: DropshipSettlementChargeType): DropshipSettlementChargeLine {
  return { charge_type: type, amount: 0, payer: type === 'return' ? 'company' : 'recipient' };
}

export function getChargeLineAmount(
  lines: DropshipSettlementChargeLine[],
  type: DropshipSettlementChargeType,
): DropshipSettlementChargeLine {
  return lines.find((l) => l.charge_type === type) ?? defaultChargeLine(type);
}

export function mapDropshipManagementOrderResponse(raw: unknown): DropshipManagementOrderView {
  const payload = (raw ?? {}) as DropshipManagementOrderResponse & Record<string, unknown>;
  if (payload.success === false) {
    throw new Error(String(payload.error ?? 'Failed to load dropship management order'));
  }

  const orderRaw = (payload.order ?? {}) as Record<string, unknown>;
  const computedRaw = (payload.computed ?? {}) as Record<string, unknown>;
  const settlementRaw = (payload.settlement ?? {}) as Record<string, unknown>;
  const stepRaw = (payload.step_state ?? {}) as Record<string, unknown>;

  const chargeLines = mapChargeLines(settlementRaw.charge_lines);

  return {
    order: {
      id: num(orderRaw.id),
      order_no: str(orderRaw.order_no),
      status: str(orderRaw.status, 'shipped') as ShopOrderStatus,
      customer_group_name: (orderRaw.customer_group_name as string | null) ?? null,
      recipient_name: (orderRaw.recipient_name as string | null) ?? null,
      recipient_phone: (orderRaw.recipient_phone as string | null) ?? null,
      courier_name: (orderRaw.courier_name as string | null) ?? null,
      courier_awb_number: (orderRaw.courier_awb_number as string | null) ?? null,
      created_at: str(orderRaw.created_at),
      payout_settlement_status: (orderRaw.payout_settlement_status as string | null) ?? null,
    },
    computed: {
      items_resell_total: num(computedRaw.items_resell_total),
      recipient_grand_total: num(computedRaw.recipient_grand_total),
    },
    settlement: {
      id: settlementRaw.id == null ? null : num(settlementRaw.id),
      status: str(settlementRaw.status, 'draft') as DropshipSettlementStatus,
      calculated_cod_amount: num(settlementRaw.calculated_cod_amount),
      collected_cod_amount: num(settlementRaw.collected_cod_amount),
      reseller_purchase_cost: num(settlementRaw.reseller_purchase_cost),
      discount_company_pay: num(settlementRaw.discount_company_pay),
      return_reason_note: str(settlementRaw.return_reason_note),
      charge_lines: chargeLines,
      total_cost: settlementRaw.total_cost == null ? null : num(settlementRaw.total_cost),
      reseller_profit: settlementRaw.reseller_profit == null ? null : num(settlementRaw.reseller_profit),
      company_profit: settlementRaw.company_profit == null ? null : num(settlementRaw.company_profit),
      courier_cod_booked_at: (settlementRaw.courier_cod_booked_at as string | null) ?? null,
      remittance_at: (settlementRaw.remittance_at as string | null) ?? null,
      merchant_payout_at: (settlementRaw.merchant_payout_at as string | null) ?? null,
    },
    step_state: {
      can_mark_delivered: stepRaw.can_mark_delivered === true,
      can_record_bank_transfer: stepRaw.can_record_bank_transfer === true,
      can_transfer_to_reseller: stepRaw.can_transfer_to_reseller === true,
    },
  };
}

export function buildSettlementDraftPayload(input: {
  collected_cod_amount: number;
  reseller_purchase_cost: number;
  discount_company_pay: number;
  return_reason_note: string;
  delivery: { amount: number; payer: DropshipSettlementChargePayer };
  print: { amount: number; payer: DropshipSettlementChargePayer };
  packing: { amount: number; payer: DropshipSettlementChargePayer };
  returnCost: { amount: number; payer: DropshipSettlementChargePayer };
}): DropshipSettlementDraftPayload {
  return {
    collected_cod_amount: input.collected_cod_amount,
    reseller_purchase_cost: input.reseller_purchase_cost,
    discount_company_pay: input.discount_company_pay,
    return_reason_note: input.return_reason_note,
    charge_lines: [
      { charge_type: 'delivery', amount: input.delivery.amount, payer: input.delivery.payer },
      { charge_type: 'print', amount: input.print.amount, payer: input.print.payer },
      { charge_type: 'packing', amount: input.packing.amount, payer: input.packing.payer },
      { charge_type: 'return', amount: input.returnCost.amount, payer: input.returnCost.payer },
    ],
  };
}

export function settlementToFormState(settlement: DropshipManagementOrderView['settlement']) {
  const line = (type: DropshipSettlementChargeType) => getChargeLineAmount(settlement.charge_lines, type);
  return {
    totalCollectedCod: settlement.collected_cod_amount,
    resellerPurchaseCost: settlement.reseller_purchase_cost,
    discountCompanyPay: settlement.discount_company_pay,
    returnReasonNote: settlement.return_reason_note,
    delivery: { amount: line('delivery').amount, payer: line('delivery').payer },
    print: { amount: line('print').amount, payer: line('print').payer },
    packing: { amount: line('packing').amount, payer: line('packing').payer },
    returnCost: { amount: line('return').amount, payer: line('return').payer },
  };
}
