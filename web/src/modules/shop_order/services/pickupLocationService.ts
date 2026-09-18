import {
  pickupLocationRepository,
  type PickupLocationRow,
  type CreatePickupLocationPayload,
  type UpdatePickupLocationPayload,
} from '../repositories/pickupLocationRepository';
import type { ShopServiceResult } from '../types';

let cachedLocations: PickupLocationRow[] | null = null;

export const pickupLocationService = {
  async fetchLocations(opts?: { forceRefresh?: boolean }): Promise<ShopServiceResult<PickupLocationRow[]>> {
    if (cachedLocations && !opts?.forceRefresh) {
      return { success: true, data: cachedLocations };
    }
    try {
      const locations = await pickupLocationRepository.listLocations();
      cachedLocations = locations;
      return { success: true, data: locations };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to fetch pickup locations.';
      return { success: false, error: message };
    }
  },

  async createLocation(
    payload: CreatePickupLocationPayload,
  ): Promise<ShopServiceResult<PickupLocationRow>> {
    try {
      const location = await pickupLocationRepository.createLocation(payload);
      cachedLocations = null;
      return { success: true, data: location };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to create pickup location.';
      return { success: false, error: message };
    }
  },

  async updateLocation(
    id: string,
    payload: UpdatePickupLocationPayload,
  ): Promise<ShopServiceResult<PickupLocationRow>> {
    try {
      const location = await pickupLocationRepository.updateLocation(id, payload);
      cachedLocations = null;
      return { success: true, data: location };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to update pickup location.';
      return { success: false, error: message };
    }
  },

  async deleteLocation(id: string): Promise<ShopServiceResult<void>> {
    try {
      await pickupLocationRepository.deleteLocation(id);
      cachedLocations = null;
      return { success: true, data: undefined };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to delete pickup location.';
      return { success: false, error: message };
    }
  },
};
