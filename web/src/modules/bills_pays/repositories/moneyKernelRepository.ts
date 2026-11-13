import { supabase } from 'src/boot/supabase';
import type { Json } from 'src/types/database.types';
import type { MoneyKernelCurrency } from '../types/moneyKernelCurrency';
import { MONEY_KERNEL_WRITE_RPC } from './moneyKernelTargets';

const db = supabase as any;

export type RpcCreateBillResponse = {
  bill_id?: number;
  invoice_no?: string;
  status?: string;
  kind?: string;
  total_amount?: number;
  due_amount?: number;
  idempotent?: boolean;
  error?: string;
};

/** Money spine v2 — create bill (optional `auto_issue` on payload). */
const createBill = async (payload: Json): Promise<RpcCreateBillResponse> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.createBill, {
    p_payload: payload,
  });
  if (error) throw error;
  return (data as RpcCreateBillResponse | null) ?? {};
};

const issueBill = async (
  tenantId: number,
  billId: number,
): Promise<RpcCreateBillResponse> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.issueBill, {
    p_tenant_id: tenantId,
    p_bill_id: billId,
  });
  if (error) throw error;
  return (data as RpcCreateBillResponse | null) ?? {};
};

const listCurrencies = async (): Promise<MoneyKernelCurrency[]> => {
  const { data, error } = await db.rpc('list_global_currencies');
  if (error) throw error;
  return Array.isArray(data) ? (data as MoneyKernelCurrency[]) : [];
};

type PotBalancesRpc = {
  rows?: Array<{
    pot_id?: number;
    currency_code?: string;
    amount?: number;
  }>;
};

type PotBalanceRpc = {
  pot_id?: number;
  cashbook_point_id?: number;
  currency_code?: string;
  amount?: number;
  entity_id?: number;
};

const provisionCashbookCurrency = async (
  tenantId: number,
  profileId: number,
  currencyCode: string,
  pointCode = 'main',
  booksRate?: number | null,
): Promise<{ cashbook_account_id?: number; pot_id?: number; cashbook_point_id?: number }> => {
  const { data, error } = await db.rpc('rpc_provision_cashbook_currency', {
    p_tenant_id: tenantId,
    p_profile_id: profileId,
    p_currency_code: currencyCode,
    p_point_code: pointCode,
    p_books_rate: booksRate != null && booksRate > 0 ? booksRate : undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const getPotBalances = async (
  tenantId: number,
  profileIds: number[],
  currencies: string[] | null,
): Promise<PotBalancesRpc> => {
  const { data, error } = await db.rpc('rpc_get_pot_balances', {
    p_tenant_id: tenantId,
    p_entity_type: 'profile',
    p_entity_ids: profileIds,
    p_currencies: currencies ?? undefined,
  });
  if (error) throw error;
  const payload = data as PotBalancesRpc | null;
  return payload ?? { rows: [] };
};

export type ProfileCashbookBundleRpc = {
  bundle_id?: number;
  cash_location_id?: number;
  location_code?: string;
  location_name?: string;
  desk_point_id?: number | null;
  currency_code?: string;
  amount?: number;
  books_rate?: number;
};

const listProfileCashbookBundles = async (
  tenantId: number,
  profileId: number,
): Promise<{ profile_id?: number; bundles?: ProfileCashbookBundleRpc[] }> => {
  const { data, error } = await db.rpc('rpc_list_profile_cashbook_bundles', {
    p_tenant_id: tenantId,
    p_profile_id: profileId,
  });
  if (error) throw error;
  return (data as { profile_id?: number; bundles?: ProfileCashbookBundleRpc[] } | null) ?? {};
};

const closeCashBundle = async (input: {
  tenantId: number;
  profileId: number;
  bundleId: number;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc('rpc_close_cash_bundle', {
    p_tenant_id: input.tenantId,
    p_profile_id: input.profileId,
    p_bundle_id: input.bundleId,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const getPotBalanceById = async (
  tenantId: number,
  potId: number,
): Promise<PotBalanceRpc> => {
  const { data, error } = await db.rpc('rpc_get_pot_balance', {
    p_tenant_id: tenantId,
    p_pot_id: potId,
  });
  if (error) throw error;
  return (data as PotBalanceRpc | null) ?? {};
};

export type PayBillsAllocation = { bill_id: number; amount: number };

export type PayBillsInput = {
  tenantId: number;
  payerProfileId: number;
  fromPotId: number;
  amount: number;
  allocations: PayBillsAllocation[];
  toPotId?: number | null;
  bundleDebits?: Json | null;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
};

const payBills = async (input: PayBillsInput): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.payBills, {
    p_tenant_id: input.tenantId,
    p_payer_profile_id: input.payerProfileId,
    p_from_pot_id: input.fromPotId,
    p_amount: input.amount,
    p_allocations: input.allocations,
    p_to_pot_id: input.toPotId ?? undefined,
    p_bundle_debits: input.bundleDebits ?? null,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

export type DepositRpcResult = {
  pays_id?: number;
  kind?: string;
  pot_id: number;
  cash_bundle_id: number;
  amount: number;
  currency_code: string;
  books_amount?: number;
  balance_after: number;
  payment_date?: string;
  status?: string;
  idempotent?: boolean;
};

export function parseDepositRpcResult(data: Record<string, unknown>): DepositRpcResult {
  const potId = Number(data.pot_id ?? data.cash_bundle_id);
  if (!Number.isFinite(potId) || potId <= 0) {
    throw new Error('Deposit response missing bundle id.');
  }
  const balanceAfter = Number(data.balance_after);
  if (!Number.isFinite(balanceAfter)) {
    throw new Error('Deposit response missing balance.');
  }
  const amount = Number(data.amount);
  const currencyCode = String(data.currency_code ?? 'BDT').trim().toUpperCase() || 'BDT';
  return {
    pays_id: data.pays_id != null ? Number(data.pays_id) : undefined,
    kind: data.kind != null ? String(data.kind) : undefined,
    pot_id: potId,
    cash_bundle_id: potId,
    amount: Number.isFinite(amount) ? amount : 0,
    currency_code: currencyCode,
    books_amount:
      data.books_amount != null && Number.isFinite(Number(data.books_amount))
        ? Number(data.books_amount)
        : undefined,
    balance_after: balanceAfter,
    payment_date: data.payment_date != null ? String(data.payment_date) : undefined,
    status: data.status != null ? String(data.status) : undefined,
    idempotent: data.idempotent === true,
  };
}

const deposit = async (input: {
  tenantId: number;
  profileId: number;
  amount: number;
  currencyCode: string;
  potId?: number | null;
  locationCode?: string | null;
  booksRate?: number | null;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
}): Promise<DepositRpcResult> => {
  const loc =
    input.potId == null && input.locationCode?.trim()
      ? input.locationCode.trim()
      : undefined;
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.deposit, {
    p_tenant_id: input.tenantId,
    p_profile_id: input.profileId,
    p_amount: input.amount,
    p_currency_code: input.currencyCode,
    p_pot_id: input.potId ?? undefined,
    p_location_code: loc,
    p_books_rate:
      input.booksRate != null && input.booksRate > 0 ? input.booksRate : undefined,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return parseDepositRpcResult((data as Record<string, unknown> | null) ?? {});
};

const withdraw = async (input: {
  tenantId: number;
  profileId: number;
  amount: number;
  currencyCode: string;
  potId?: number | null;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.withdraw, {
    p_tenant_id: input.tenantId,
    p_profile_id: input.profileId,
    p_amount: input.amount,
    p_currency_code: input.currencyCode,
    p_pot_id: input.potId ?? undefined,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const revertPays = async (input: {
  tenantId: number;
  paysId: number;
  reason: string;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.revertPays, {
    p_tenant_id: input.tenantId,
    p_pays_id: input.paysId,
    p_reason: input.reason,
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const transferP2p = async (input: {
  tenantId: number;
  fromPotId: number;
  toPotId: number;
  amount: number;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.transferP2p, {
    p_tenant_id: input.tenantId,
    p_from_pot_id: input.fromPotId,
    p_to_pot_id: input.toPotId,
    p_amount: input.amount,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const transferSameProfile = async (input: {
  tenantId: number;
  fromPotId: number;
  toPotId: number;
  amount: number;
  meta?: Record<string, unknown>;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.transferSameProfile, {
    p_tenant_id: input.tenantId,
    p_from_pot_id: input.fromPotId,
    p_to_pot_id: input.toPotId,
    p_amount: input.amount,
    p_meta: input.meta ?? {},
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const applyDocumentSettlement = async (input: {
  tenantId: number;
  sourceBillId: number;
  targetBillId: number;
  amount: number;
  idempotencyKey?: string | null;
}): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.applyDocumentSettlement, {
    p_tenant_id: input.tenantId,
    p_source_bill_id: input.sourceBillId,
    p_target_bill_id: input.targetBillId,
    p_amount: input.amount,
    p_idempotency_key: input.idempotencyKey ?? undefined,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const voidKernelBill = async (
  tenantId: number,
  billId: number,
  reason?: string | null,
  reversePayments = true,
): Promise<Record<string, unknown>> => {
  const { data, error } = await db.rpc(MONEY_KERNEL_WRITE_RPC.voidBill, {
    p_tenant_id: tenantId,
    p_bill_id: billId,
    p_reason: reason ?? undefined,
    p_reverse_payments: reversePayments,
  });
  if (error) throw error;
  return (data as Record<string, unknown> | null) ?? {};
};

const updateDraftBillV2 = async (
  tenantId: number,
  billId: number,
  payload: Json,
): Promise<RpcCreateBillResponse> => {
  const { data, error } = await db.rpc('rpc_update_draft_bill_v2', {
    p_tenant_id: tenantId,
    p_bill_id: billId,
    p_payload: payload,
  });
  if (error) throw error;
  return (data as RpcCreateBillResponse | null) ?? {};
};

export const moneyKernelRepository = {
  createBill,
  issueBill,
  updateDraftBillV2,
  listCurrencies,
  provisionCashbookCurrency,
  getPotBalances,
  getPotBalanceById,
  payBills,
  deposit,
  withdraw,
  revertPays,
  listProfileCashbookBundles,
  closeCashBundle,
  transferP2p,
  transferSameProfile,
  applyDocumentSettlement,
  voidKernelBill,
};
