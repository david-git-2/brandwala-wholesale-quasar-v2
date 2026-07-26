import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/supabase';

export type WalletLedgerEntry = Database['public']['Tables']['billing_profile_wallet_ledger']['Row'];

export interface BillingProfileWalletSummary {
  billing_profile_id: number;
  profile_name: string;
  customer_group_id: number | null;
  email: string | null;
  phone: string | null;
  total_billed: number;
  total_payments: number;
  total_dropship_profit: number;
  total_return_fees: number;
  total_payouts_paid: number;
  net_balance: number; // positive = company owes profile money (credit); negative = profile owes company money (debt)
}

export interface CreateWalletPayoutInput {
  tenant_id: number;
  billing_profile_id: number;
  amount: number;
  reference_notes?: string | null;
  created_by?: string | null;
}

const fetchWalletBalances = async (tenantId: number): Promise<BillingProfileWalletSummary[]> => {
  // Fetch all billing profiles for the tenant
  const { data: profiles, error: profileErr } = await supabase
    .from('billing_profiles')
    .select('id, name, customer_group_id, email, phone')
    .eq('tenant_id', tenantId);

  if (profileErr) throw profileErr;
  if (!profiles || profiles.length === 0) return [];

  // Fetch all wallet ledger records for the tenant
  const { data: ledger, error: ledgerErr } = await supabase
    .from('billing_profile_wallet_ledger')
    .select('*')
    .eq('tenant_id', tenantId);

  if (ledgerErr) throw ledgerErr;

  // Group ledger entries by billing profile
  const profileMap = new Map<number, BillingProfileWalletSummary>();
  profiles.forEach((p) => {
    profileMap.set(p.id, {
      billing_profile_id: p.id,
      profile_name: p.name,
      customer_group_id: p.customer_group_id,
      email: p.email,
      phone: p.phone,
      total_billed: 0,
      total_payments: 0,
      total_dropship_profit: 0,
      total_return_fees: 0,
      total_payouts_paid: 0,
      net_balance: 0,
    });
  });

  (ledger ?? []).forEach((entry) => {
    const summary = profileMap.get(entry.billing_profile_id);
    if (!summary) return;

    const amt = Number(entry.amount || 0);
    switch (entry.transaction_type) {
      case 'invoice_billed':
        summary.total_billed += amt;
        summary.net_balance -= amt;
        break;
      case 'payment_received':
        summary.total_payments += amt;
        summary.net_balance += amt;
        break;
      case 'dropship_profit':
        summary.total_dropship_profit += amt;
        summary.net_balance += amt;
        break;
      case 'dropship_return_fee':
        summary.total_return_fees += amt;
        summary.net_balance -= amt;
        break;
      case 'payout_paid':
        summary.total_payouts_paid += amt;
        summary.net_balance -= amt;
        break;
      case 'adjustment':
        // Positive or negative based on sign (default treated as addition if positive)
        summary.net_balance += amt;
        break;
    }
  });

  return Array.from(profileMap.values());
};

const fetchWalletLedger = async (
  tenantId: number,
  billingProfileId: number,
): Promise<WalletLedgerEntry[]> => {
  const { data, error } = await supabase
    .from('billing_profile_wallet_ledger')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('billing_profile_id', billingProfileId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

const createWalletPayout = async (input: CreateWalletPayoutInput): Promise<WalletLedgerEntry> => {
  const { data, error } = await supabase.rpc('create_bulk_wallet_payout', {
    p_tenant_id: input.tenant_id,
    p_billing_profile_id: input.billing_profile_id,
    p_amount: input.amount,
    p_reference_notes: input.reference_notes ?? 'Bulk wallet payout',
    p_created_by: input.created_by ?? null,
  });

  if (error) throw error;
  return data as WalletLedgerEntry;
};

export const billingWalletRepository = {
  fetchWalletBalances,
  fetchWalletLedger,
  createWalletPayout,
};
