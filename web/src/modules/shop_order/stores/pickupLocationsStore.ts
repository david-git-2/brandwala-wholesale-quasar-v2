import { defineStore } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  pickupLocationRepository,
  type CreatePickupLocationPayload,
  type PickupLocationRow,
  type UpdatePickupLocationPayload,
} from '../repositories/pickupLocationRepository';

export const usePickupLocationsStore = defineStore('pickupLocations', {
  state: () => ({
    locations: [] as PickupLocationRow[],
    loading: false,
    loaded: false,
    cachedTenantId: null as number | null,
  }),

  actions: {
    clear() {
      this.locations = [];
      this.loaded = false;
    },

    setLocations(locations: PickupLocationRow[]) {
      this.locations = locations;
      this.loaded = true;
    },

    syncTenantScope() {
      const tenantId = useAuthStore().tenantId ?? null;
      if (this.cachedTenantId !== tenantId) {
        this.cachedTenantId = tenantId;
        this.clear();
      }
    },

    async ensureLocations(forceRefresh = false): Promise<PickupLocationRow[]> {
      this.syncTenantScope();

      if (!forceRefresh && this.locations.length > 0) {
        return this.locations;
      }
      if (!forceRefresh && this.loaded) {
        return this.locations;
      }

      this.loading = true;
      try {
        const rows = await pickupLocationRepository.listLocations();
        this.locations = rows;
        this.loaded = true;
        return rows;
      } finally {
        this.loading = false;
      }
    },

    async createLocation(payload: CreatePickupLocationPayload): Promise<PickupLocationRow> {
      const location = await pickupLocationRepository.createLocation(payload);
      this.locations = [location, ...this.locations];
      this.loaded = true;
      return location;
    },

    async updateLocation(id: string, payload: UpdatePickupLocationPayload): Promise<PickupLocationRow> {
      const location = await pickupLocationRepository.updateLocation(id, payload);
      const index = this.locations.findIndex((row) => row.id === id);
      if (index >= 0) {
        this.locations[index] = location;
      } else {
        this.locations = [location, ...this.locations];
      }
      this.loaded = true;
      return location;
    },

    async deleteLocation(id: string): Promise<void> {
      await pickupLocationRepository.deleteLocation(id);
      this.locations = this.locations.filter((row) => row.id !== id);
      this.loaded = true;
    },
  },
});
