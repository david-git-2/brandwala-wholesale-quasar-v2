import { supabase } from 'src/boot/supabase';
import type { WholesalePaymentInstrumentInput } from '../utils/paymentInstrumentFields';
import { resolveShipmentIdsForApPayout } from '../utils/shipmentApBillSource';

const localToday = () => new Date().toISOString().slice(0, 10);

export type ApPayoutWithAllocationsPayload = {
  tenant_id: number;
  profile_id: number;
  cashbook_point_id: number;
  paid_on?: string;
  note?: string | null;
  reference?: string | null;
  instruments: WholesalePaymentInstrumentInput[];
  allocations: Array<{ bill_id: number; amount: number }>;
  settlement_currency_code?: string;
  foreign_amount?: number | null;
  exchange_rate?: number | null;
  source_currency_code?: string | null;
  transaction_rate?: number | null;
  cashbook_point_pot_id?: number | null;
  /** Sum of instruments when omitted */
  amount?: number;
  shipment_id?: number | null;
  idempotency_key: string;
};

export type ApPayoutBillDetailSnapshot = {
  pay: unknown;
  bill: Record<string, unknown> | null;
  net_balances: Record<string, unknown> | null;
  payment_history: unknown;
};

const instrumentTotal = (instruments: WholesalePaymentInstrumentInput[]): number =>
  instruments.reduce((s, i) => s + (Number(i.amount) || 0), 0);

const apPayoutRpcArgs = (payload: ApPayoutWithAllocationsPayload) => ({
  p_tenant_id: payload.tenant_id,
  p_profile_id: payload.profile_id,
  p_paid_on: payload.paid_on ?? localToday(),
  p_cashbook_point_id: payload.cashbook_point_id,
  p_note: payload.note ?? null,
  p_reference: payload.reference ?? null,
  p_instruments: payload.instruments,
  p_allocations: payload.allocations.map((a) => ({ bill_id: a.bill_id, amount: a.amount })),
  p_settlement_currency_code: payload.settlement_currency_code ?? 'BDT',
  p_foreign_amount: payload.foreign_amount ?? null,
  p_exchange_rate: payload.exchange_rate ?? null,
  p_source_currency_code: payload.source_currency_code ?? null,
  p_transaction_rate: payload.transaction_rate ?? null,
  p_cashbook_point_pot_id: payload.cashbook_point_pot_id ?? null,
  p_idempotency_key: payload.idempotency_key,
});

const allocationBillIds = (payload: ApPayoutWithAllocationsPayload): number[] =>
  payload.allocations.map((a) => a.bill_id).filter((id) => id > 0);

export async function resolveShipmentIdsForPayoutPayload(
  payload: ApPayoutWithAllocationsPayload,
): Promise<number[]> {
  return resolveShipmentIdsForApPayout({
    shipmentId: payload.shipment_id,
    allocationBillIds: allocationBillIds(payload),
  });
}

export async function postApPayout(payload: ApPayoutWithAllocationsPayload) {
  const shipmentIds = await resolveShipmentIdsForPayoutPayload(payload);
  const args = apPayoutRpcArgs(payload);
  const amount = payload.amount ?? instrumentTotal(payload.instruments);

  if (shipmentIds.length > 0) {
    const { data, error } = await supabase.rpc('post_shipment_ap_money_out', {
      p_shipment_ids: shipmentIds,
      p_tenant_id: args.p_tenant_id,
      p_profile_id: args.p_profile_id,
      p_paid_on: args.p_paid_on,
      p_amount: amount,
      p_note: args.p_note,
      p_reference: args.p_reference,
      p_cashbook_point_id: args.p_cashbook_point_id,
      p_instruments: args.p_instruments,
      p_allocations: args.p_allocations,
      p_settlement_currency_code: args.p_settlement_currency_code,
      p_foreign_amount: args.p_foreign_amount,
      p_exchange_rate: args.p_exchange_rate,
      p_idempotency_key: payload.idempotency_key,
    });
    if (error) throw error;
    return { shipmentIds, pay: data };
  }

  const { data, error } = await supabase.rpc('post_ap_payout_with_allocations', args);
  if (error) throw error;
  return { shipmentIds: [] as number[], pay: data };
}

export async function postApPayoutSnapshot(
  payload: ApPayoutWithAllocationsPayload,
): Promise<ApPayoutBillDetailSnapshot & { shipmentIds: number[] }> {
  const shipmentIds = await resolveShipmentIdsForPayoutPayload(payload);
  const args = apPayoutRpcArgs(payload);

  if (shipmentIds.length > 0) {
    const { data, error } = await supabase.rpc('post_shipment_ap_money_out_snapshot', {
      p_shipment_ids: shipmentIds,
      p_tenant_id: args.p_tenant_id,
      p_profile_id: args.p_profile_id,
      p_paid_on: args.p_paid_on,
      p_cashbook_point_id: args.p_cashbook_point_id,
      p_note: args.p_note,
      p_reference: args.p_reference,
      p_instruments: args.p_instruments,
      p_allocations: args.p_allocations,
      p_settlement_currency_code: args.p_settlement_currency_code,
      p_foreign_amount: args.p_foreign_amount,
      p_exchange_rate: args.p_exchange_rate,
      p_source_currency_code: args.p_source_currency_code,
      p_transaction_rate: args.p_transaction_rate,
      p_cashbook_point_pot_id: args.p_cashbook_point_pot_id,
    });
    if (error) throw error;
    const row = (data ?? {}) as Record<string, unknown>;
    return {
      shipmentIds,
      pay: row.pay,
      bill: (row.bill as Record<string, unknown> | null) ?? null,
      net_balances: (row.net_balances as Record<string, unknown> | null) ?? null,
      payment_history: row.payment_history ?? [],
    };
  }

  const { data, error } = await supabase.rpc('post_ap_payout_with_allocations_snapshot', args);
  if (error) throw error;
  const row = (data ?? {}) as Record<string, unknown>;
  return {
    shipmentIds: [],
    pay: row.pay,
    bill: (row.bill as Record<string, unknown> | null) ?? null,
    net_balances: (row.net_balances as Record<string, unknown> | null) ?? null,
    payment_history: row.payment_history ?? [],
  };
}
