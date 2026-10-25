import {
  type PickupLocationRow,
  type CreatePickupLocationPayload,
  type UpdatePickupLocationPayload,
} from '../repositories/pickupLocationRepository';
import { usePickupLocationsStore } from '../stores/pickupLocationsStore';
import type { ShopServiceResult } from '../types';

export const pickupLocationService = {
  async fetchLocations(opts?: { forceRefresh?: boolean }): Promise<ShopServiceResult<PickupLocationRow[]>> {
    const store = usePickupLocationsStore();
    try {
      const locations = await store.ensureLocations(opts?.forceRefresh ?? false);
      return { success: true, data: locations };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to fetch pickup locations.';
      return { success: false, error: message };
    }
  },

  async createLocation(
    payload: CreatePickupLocationPayload,
  ): Promise<ShopServiceResult<PickupLocationRow>> {
    const store = usePickupLocationsStore();
    try {
      const location = await store.createLocation(payload);
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
    const store = usePickupLocationsStore();
    try {
      const location = await store.updateLocation(id, payload);
      return { success: true, data: location };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to update pickup location.';
      return { success: false, error: message };
    }
  },

  async deleteLocation(id: string): Promise<ShopServiceResult<void>> {
    const store = usePickupLocationsStore();
    try {
      await store.deleteLocation(id);
      return { success: true, data: undefined };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to delete pickup location.';
      return { success: false, error: message };
    }
  },
};
