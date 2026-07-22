import {
  dropshipLedgerRepository,
  type CreateMiddleManPayoutPayload,
  type LedgerListFilters,
  type PayoutLedgerRow,
  type RecordCourierRemittancePayload,
  type RemittanceEligibleOrder,
} from '../repositories/dropshipLedgerRepository';
import type { ShopServiceResult } from '../types';

export const dropshipLedgerService = {
  async fetchLedgerEntries(
    tenantId: number,
    filters: LedgerListFilters = {},
  ): Promise<ShopServiceResult<PayoutLedgerRow[]>> {
    try {
      const entries = await dropshipLedgerRepository.listLedgerEntries(tenantId, filters);
      return { success: true, data: entries };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to fetch payout ledger entries.',
      };
    }
  },

  async fetchDeliveredOrdersForRemittance(
    tenantId: number,
  ): Promise<ShopServiceResult<RemittanceEligibleOrder[]>> {
    try {
      const orders = await dropshipLedgerRepository.listDeliveredOrdersForRemittance(tenantId);
      return { success: true, data: orders };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to load delivered orders.',
      };
    }
  },

  async fetchPendingCodTotal(tenantId: number): Promise<ShopServiceResult<number>> {
    try {
      const total = await dropshipLedgerRepository.sumPendingCodRemittance(tenantId);
      return { success: true, data: total };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to load pending COD total.',
      };
    }
  },

  async recordRemittance(
    payload: RecordCourierRemittancePayload,
  ): Promise<ShopServiceResult<{ success: boolean; invoice_id?: number; payment_id?: number }>> {
    try {
      const result = await dropshipLedgerRepository.recordCourierRemittance(payload);
      return { success: true, data: result };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to record courier remittance.',
      };
    }
  },

  async settlePayout(
    payload: CreateMiddleManPayoutPayload,
  ): Promise<ShopServiceResult<unknown>> {
    try {
      const result = await dropshipLedgerRepository.createMiddleManPayout(payload);
      return { success: true, data: result };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to settle middle-man payout.',
      };
    }
  },

  async settlePayoutForLedgerEntry(
    tenantId: number,
    entry: PayoutLedgerRow,
  ): Promise<ShopServiceResult<unknown>> {
    if (!entry.global_invoice_id) {
      return { success: false, error: 'Ledger entry has no linked accounting invoice.' };
    }
    try {
      const invoice = await dropshipLedgerRepository.getInvoicePayoutContext(entry.global_invoice_id);
      if (!invoice.billing_profile_id) {
        return { success: false, error: 'Invoice has no billing profile for payout.' };
      }
      if (invoice.middle_man_payout_status === 'paid') {
        return { success: false, error: 'Middle-man payout is already settled for this invoice.' };
      }
      const amount =
        Number(invoice.middle_man_payout_amount ?? 0) > 0
          ? Number(invoice.middle_man_payout_amount)
          : Math.abs(Number(entry.amount));
      if (amount <= 0) {
        return { success: false, error: 'Nothing to settle for this invoice.' };
      }
      const result = await dropshipLedgerRepository.createMiddleManPayout({
        tenant_id: tenantId,
        billing_profile_id: invoice.billing_profile_id,
        global_invoice_id: invoice.id,
        amount,
        note: `Payout settled for order #${entry.shop_orders?.order_no || entry.shop_order_id || 'N/A'}`,
      });
      return { success: true, data: result };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to settle middle-man payout.',
      };
    }
  },

  async settlePayoutForInvoice(
    tenantId: number,
    globalInvoiceId: number,
    orderNo?: string | null,
  ): Promise<ShopServiceResult<unknown>> {
    try {
      const invoice = await dropshipLedgerRepository.getInvoicePayoutContext(globalInvoiceId);
      if (!invoice.billing_profile_id) {
        return { success: false, error: 'Invoice has no billing profile for payout.' };
      }
      if (invoice.middle_man_payout_status === 'paid') {
        return { success: false, error: 'Middle-man payout is already settled for this invoice.' };
      }
      const amount = Number(invoice.middle_man_payout_amount ?? 0);
      if (amount <= 0) {
        return { success: false, error: 'Nothing to settle for this invoice.' };
      }
      const result = await dropshipLedgerRepository.createMiddleManPayout({
        tenant_id: tenantId,
        billing_profile_id: invoice.billing_profile_id,
        global_invoice_id: invoice.id,
        amount,
        note: `Payout settled for order #${orderNo || 'N/A'}`,
      });
      return { success: true, data: result };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to settle middle-man payout.',
      };
    }
  },
};
