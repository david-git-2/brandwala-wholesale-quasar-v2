import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { shopPermissionsService } from '../services/shopPermissionsService';
import type {
  CustomerGroupShopProfile,
  ShopCustomerGroupAccess,
  UpsertProfilePayload,
  UpsertAccessPayload,
} from '../types';

interface CustomerGroup {
  id: number;
  name: string;
  is_active: boolean;
  accent_color: string | null;
}

interface Currency {
  id: number;
  code: string;
  name: string;
}

export interface ShopPermissionsState {
  customerGroups: CustomerGroup[];
  loadingGroups: boolean;
  activeProfile: CustomerGroupShopProfile | null;
  loadingProfile: boolean;
  accessOverrides: ShopCustomerGroupAccess[];
  loadingAccess: boolean;
  currencies: Currency[];
  loadingCurrencies: boolean;
  saving: boolean;
  error: string | null;
}

export const useShopPermissionsStore = defineStore('shopPermissions', {
  state: (): ShopPermissionsState => ({
    customerGroups: [],
    loadingGroups: false,
    activeProfile: null,
    loadingProfile: false,
    accessOverrides: [],
    loadingAccess: false,
    currencies: [],
    loadingCurrencies: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null;
    },

    async fetchCustomerGroups(tenantId: number) {
      this.loadingGroups = true;
      this.error = null;
      try {
        const res = await shopPermissionsService.listCustomerGroups(tenantId);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.customerGroups = res.data ?? [];
        return res;
      } finally {
        this.loadingGroups = false;
      }
    },

    async fetchProfile(tenantId: number, customerGroupId: number) {
      this.loadingProfile = true;
      this.error = null;
      this.activeProfile = null;
      try {
        const res = await shopPermissionsService.getProfile(tenantId, customerGroupId);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.activeProfile = res.data ?? null;
        return res;
      } finally {
        this.loadingProfile = false;
      }
    },

    async saveProfile(payload: UpsertProfilePayload) {
      this.saving = true;
      this.error = null;
      try {
        const res = await shopPermissionsService.upsertProfile(payload);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.activeProfile = res.data;
        showSuccessNotification('Group default profile saved successfully.');
        return res;
      } finally {
        this.saving = false;
      }
    },

    async fetchAccessOverrides(shopId: number) {
      this.loadingAccess = true;
      this.error = null;
      try {
        const res = await shopPermissionsService.listAccessOverrides(shopId);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.accessOverrides = res.data ?? [];
        return res;
      } finally {
        this.loadingAccess = false;
      }
    },

    async saveAccessOverride(payload: UpsertAccessPayload) {
      this.saving = true;
      this.error = null;
      try {
        const res = await shopPermissionsService.upsertAccessOverride(payload);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        // Update local state item if exists, otherwise push
        const idx = this.accessOverrides.findIndex(
          (o) => o.customer_group_id === payload.customer_group_id && o.shop_id === payload.shop_id,
        );
        if (idx !== -1) {
          this.accessOverrides[idx] = res.data;
        } else {
          this.accessOverrides.push(res.data);
        }
        showSuccessNotification('Shop access override saved.');
        return res;
      } finally {
        this.saving = false;
      }
    },

    async fetchCurrencies() {
      if (this.currencies.length > 0) return;
      this.loadingCurrencies = true;
      try {
        const res = await shopPermissionsService.listCurrencies();
        if (!res.success) {
          this.error = res.error;
          return res;
        }
        this.currencies = res.data ?? [];
        return res;
      } finally {
        this.loadingCurrencies = false;
      }
    },
  },
});
