import {
  dropshipLedgerRepository,
  type PayoutLedgerRow,
  type CreatePayoutLedgerPayload,
} from '../repositories/dropshipLedgerRepository';
import type { ShopServiceResult } from '../types';

export const dropshipLedgerService = {
  async fetchLedgerEntries(tenantId: number): Promise<ShopServiceResult<PayoutLedgerRow[]>> {
    try {
      const entries = await dropshipLedgerRepository.listLedgerEntries(tenantId);
      return { success: true, data: entries };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to fetch payout ledger entries.',
      };
    }
  },

  async addLedgerEntry(payload: CreatePayoutLedgerPayload): Promise<ShopServiceResult<PayoutLedgerRow>> {
    try {
      const entry = await dropshipLedgerRepository.addLedgerEntry(payload);
      return { success: true, data: entry };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to add ledger entry.',
      };
    }
  },
};
