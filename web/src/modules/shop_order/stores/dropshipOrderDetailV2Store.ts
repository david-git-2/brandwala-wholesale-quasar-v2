import { defineStore } from 'pinia';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { StockPickMutationResult } from '../repositories/shopOrderRepository';
import {
  mapDropshipOrderDetailV2Response,
  type DropshipOrderDetailV2Response,
} from '../utils/dropshipOrderDetailV2Mapper';
import { applyStockPickOrderLineToDetail } from '../utils/dropshipOrderDetailStockPickPatch';

export function dropshipOrderDetailV2StoreKey(tenantId: number, orderId: number): string {
  return `${tenantId}:${orderId}`;
}

export const useDropshipOrderDetailV2Store = defineStore('dropshipOrderDetailV2', {
  state: () => ({
    byKey: {} as Record<string, DropshipOrderDetailV2Response>,
    loadingKeys: {} as Record<string, boolean>,
    errorKeys: {} as Record<string, string | null>,
  }),

  getters: {
    getDetail:
      (state) =>
      (tenantId: number, orderId: number): DropshipOrderDetailV2Response | null =>
        state.byKey[dropshipOrderDetailV2StoreKey(tenantId, orderId)] ?? null,
  },

  actions: {
    setDetail(tenantId: number, orderId: number, detail: DropshipOrderDetailV2Response) {
      const key = dropshipOrderDetailV2StoreKey(tenantId, orderId);
      this.byKey[key] = detail;
      this.errorKeys[key] = null;
    },

    setDetailFromRaw(tenantId: number, orderId: number, raw: unknown): DropshipOrderDetailV2Response {
      const mapped = mapDropshipOrderDetailV2Response(raw);
      this.setDetail(tenantId, orderId, mapped);
      return mapped;
    },

    clearDetail(tenantId: number, orderId: number) {
      const key = dropshipOrderDetailV2StoreKey(tenantId, orderId);
      delete this.byKey[key];
      delete this.loadingKeys[key];
      delete this.errorKeys[key];
    },

    patchDetail(
      tenantId: number,
      orderId: number,
      updater: (current: DropshipOrderDetailV2Response) => DropshipOrderDetailV2Response,
    ) {
      const key = dropshipOrderDetailV2StoreKey(tenantId, orderId);
      const current = this.byKey[key];
      if (!current) return;
      this.byKey[key] = updater(current);
    },

    applyStockPickMutation(
      tenantId: number,
      orderId: number,
      result: StockPickMutationResult,
    ): void {
      const orderLine = result.order_line;
      if (!orderLine?.id) return;
      this.patchDetail(tenantId, orderId, (detail) =>
        applyStockPickOrderLineToDetail(detail, orderLine, result.cod_collect_amount),
      );
    },

    async ensureDetail(
      tenantId: number,
      orderId: number,
      forceRefresh = false,
    ): Promise<DropshipOrderDetailV2Response> {
      const key = dropshipOrderDetailV2StoreKey(tenantId, orderId);
      if (!forceRefresh && this.byKey[key]) {
        return this.byKey[key];
      }

      this.loadingKeys[key] = true;
      this.errorKeys[key] = null;
      try {
        const mapped = await shopOrderRepository.getDropshipOrderDetailV2(tenantId, orderId);
        this.byKey[key] = mapped;
        return mapped;
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : 'Failed to load dropship order detail';
        this.errorKeys[key] = message;
        throw err;
      } finally {
        this.loadingKeys[key] = false;
      }
    },
  },
});
