import { defineStore } from 'pinia';

import type { ApplyDepositCacheInput } from '../types/applyDepositCacheInput';
import { patchBillPayCashbookLegs } from '../composables/patchBillPayCashbookLegs';
import type { BillPayCashbookLegs } from '../types/billPayCashbookLegs';

export const useBillPayCashbookLegsStore = defineStore('billPayCashbookLegs', {
  state: () => ({
    billId: null as number | null,
    payCashbookLegs: null as BillPayCashbookLegs | null,
  }),

  actions: {
    setFromBundle(billId: number | null, legs: BillPayCashbookLegs | null) {
      if (billId == null || billId <= 0) {
        this.clear();
        return;
      }
      this.billId = billId;
      this.payCashbookLegs = legs;
    },

    /** Hydrate from Vue Query without clobbering deposit patches already on the store. */
    syncFromBundleQuery(billId: number | null, legs: BillPayCashbookLegs | null | undefined) {
      if (billId == null || billId <= 0) {
        this.clear();
        return;
      }
      if (this.billId !== billId) {
        this.setFromBundle(billId, legs ?? null);
        return;
      }
      if (this.payCashbookLegs == null) {
        this.setFromBundle(billId, legs ?? null);
      }
    },

    /** Replace legs after server refetch (e.g. payment recorded). */
    replaceFromBundleQuery(billId: number | null, legs: BillPayCashbookLegs | null | undefined) {
      if (billId == null || billId <= 0) {
        this.clear();
        return;
      }
      this.setFromBundle(billId, legs ?? null);
    },

    clear() {
      this.billId = null;
      this.payCashbookLegs = null;
    },

    applyDepositPatch(input: ApplyDepositCacheInput) {
      const billId = input.billId;
      if (billId == null || billId <= 0) return;
      if (this.billId == null) {
        this.billId = billId;
      }
      if (this.billId !== billId) return;
      this.payCashbookLegs = patchBillPayCashbookLegs(this.payCashbookLegs, input);
    },
  },
});