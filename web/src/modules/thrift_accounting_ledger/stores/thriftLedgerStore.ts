import { defineStore } from 'pinia';
import { thriftLedgerRepository } from '../repositories/thriftLedgerRepository';
import type { ThriftLedgerEntry } from '../types';

export const useThriftLedgerStore = defineStore('thrift_accounting_ledger', {
  state: () => ({
    ledgerEntries: [] as ThriftLedgerEntry[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadLedger(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.ledgerEntries = await thriftLedgerRepository.fetchLedger(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load accounting ledger';
      } finally {
        this.loading = false;
      }
    },
  },
});
