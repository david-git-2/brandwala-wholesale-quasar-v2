import { dropshipCourierRepository, type CourierServiceRow, type CreateCourierServicePayload, type UpdateCourierServicePayload } from '../repositories/dropshipCourierRepository';
import type { ShopServiceResult } from '../types';

export const dropshipCourierService = {
  async fetchCouriers(): Promise<ShopServiceResult<CourierServiceRow[]>> {
    try {
      const couriers = await dropshipCourierRepository.listCouriers();
      return { success: true, data: couriers };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to fetch courier services.',
      };
    }
  },

  async createCourier(payload: CreateCourierServicePayload): Promise<ShopServiceResult<CourierServiceRow>> {
    try {
      const courier = await dropshipCourierRepository.createCourier(payload);
      return { success: true, data: courier };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to create courier service.',
      };
    }
  },

  async updateCourier(id: string, payload: UpdateCourierServicePayload): Promise<ShopServiceResult<CourierServiceRow>> {
    try {
      const courier = await dropshipCourierRepository.updateCourier(id, payload);
      return { success: true, data: courier };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to update courier service.',
      };
    }
  },

  async deleteCourier(id: string): Promise<ShopServiceResult<void>> {
    try {
      await dropshipCourierRepository.deleteCourier(id);
      return { success: true, data: undefined };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to delete courier service.',
      };
    }
  },
};
