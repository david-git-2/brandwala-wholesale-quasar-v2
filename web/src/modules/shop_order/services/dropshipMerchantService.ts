import {
  dropshipMerchantRepository,
  type MerchantProfileRow,
  type CreateMerchantProfilePayload,
  type UpdateMerchantProfilePayload,
} from '../repositories/dropshipMerchantRepository';
import type { ShopServiceResult } from '../types';

let cachedMerchants: MerchantProfileRow[] | null = null;

export const dropshipMerchantService = {
  async fetchMerchants(opts?: { forceRefresh?: boolean }): Promise<ShopServiceResult<MerchantProfileRow[]>> {
    if (cachedMerchants && !opts?.forceRefresh) {
      return { success: true, data: cachedMerchants };
    }
    try {
      const merchants = await dropshipMerchantRepository.listMerchants();
      cachedMerchants = merchants;
      return { success: true, data: merchants };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to fetch merchant profiles.',
      };
    }
  },

  async createMerchant(payload: CreateMerchantProfilePayload): Promise<ShopServiceResult<MerchantProfileRow>> {
    try {
      const merchant = await dropshipMerchantRepository.createMerchant(payload);
      cachedMerchants = null;
      return { success: true, data: merchant };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to create merchant profile.',
      };
    }
  },

  async updateMerchant(id: string, payload: UpdateMerchantProfilePayload): Promise<ShopServiceResult<MerchantProfileRow>> {
    try {
      const merchant = await dropshipMerchantRepository.updateMerchant(id, payload);
      cachedMerchants = null;
      return { success: true, data: merchant };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to update merchant profile.',
      };
    }
  },

  async deleteMerchant(id: string): Promise<ShopServiceResult<void>> {
    try {
      await dropshipMerchantRepository.deleteMerchant(id);
      cachedMerchants = null;
      return { success: true, data: undefined };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to delete merchant profile.',
      };
    }
  },
};
