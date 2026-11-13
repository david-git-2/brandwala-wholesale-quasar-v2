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
  const { data, error } = await db.rpc('list_money_kernel_currencies');
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
): Promise<{ cashbook_account_id?: number; pot_id?: number; cashbook_point_id?: number }> => {
  const { data, error } = await db.rpc('rpc_provision_cashbook_currency', {
    p_tenant_id: tenantId,
    p_profile_id: profileId,
    p_currency_code: currencyCode,
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

export const moneyKernelRepository = {
  createBill,
  issueBill,
  listCurrencies,
  provisionCashbookCurrency,
  getPotBalances,
  getPotBalanceById,
};
