import { dropshipCourierRepository, type CourierServiceRow, type CreateCourierServicePayload, type UpdateCourierServicePayload } from '../repositories/dropshipCourierRepository';
import type { ShopServiceResult } from '../types';

let cachedCouriers: CourierServiceRow[] | null = null;

export const dropshipCourierService = {
  async fetchCouriers(opts?: { forceRefresh?: boolean }): Promise<ShopServiceResult<CourierServiceRow[]>> {
    if (cachedCouriers && !opts?.forceRefresh) {
      return { success: true, data: cachedCouriers };
    }
    try {
      const couriers = await dropshipCourierRepository.listCouriers();
      cachedCouriers = couriers;
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
      cachedCouriers = null;
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
      cachedCouriers = null;
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
      cachedCouriers = null;
      return { success: true, data: undefined };
    } catch (err: any) {
      return {
        success: false,
        error: err?.message || 'Failed to delete courier service.',
      };
    }
  },
};
