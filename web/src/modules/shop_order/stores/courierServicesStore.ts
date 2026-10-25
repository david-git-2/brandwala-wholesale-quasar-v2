import { defineStore } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  dropshipCourierRepository,
  type CourierServiceRow,
} from '../repositories/dropshipCourierRepository';

export const useCourierServicesStore = defineStore('courierServices', {
  state: () => ({
    couriers: [] as CourierServiceRow[],
    loading: false,
    loaded: false,
    cachedTenantId: null as number | null,
  }),

  actions: {
    clear() {
      this.couriers = [];
      this.loaded = false;
    },

    setCouriers(couriers: CourierServiceRow[]) {
      this.couriers = couriers;
      this.loaded = true;
    },

    syncTenantScope() {
      const tenantId = useAuthStore().tenantId ?? null;
      if (this.cachedTenantId !== tenantId) {
        this.cachedTenantId = tenantId;
        this.clear();
      }
    },

    async ensureCouriers(forceRefresh = false): Promise<CourierServiceRow[]> {
      this.syncTenantScope();

      if (!forceRefresh && this.couriers.length > 0) {
        return this.couriers;
      }
      if (!forceRefresh && this.loaded) {
        return this.couriers;
      }

      this.loading = true;
      try {
        const rows = await dropshipCourierRepository.listCouriers();
        this.couriers = rows;
        this.loaded = true;
        return rows;
      } finally {
        this.loading = false;
      }
    },
  },
});
