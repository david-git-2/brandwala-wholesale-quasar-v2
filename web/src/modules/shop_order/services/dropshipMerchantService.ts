import {
  dropshipMerchantRepository,
  type MerchantProfileRow,
  type CreateMerchantProfilePayload,
  type UpdateMerchantProfilePayload,
} from '../repositories/dropshipMerchantRepository';
import type { ShopServiceResult } from '../types';

export const dropshipMerchantService = {
  async fetchMerchants(): Promise<ShopServiceResult<MerchantProfileRow[]>> {
    try {
      const merchants = await dropshipMerchantRepository.listMerchants();
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
      return { success: true, data: undefined };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to delete merchant profile.',
      };
    }
  },
};
