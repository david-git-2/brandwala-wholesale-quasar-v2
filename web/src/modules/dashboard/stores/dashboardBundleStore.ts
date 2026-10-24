import { defineStore } from 'pinia';

import { showErrorNotification } from 'src/utils/appFeedback';

import { appDashboardBundleRepository } from '../repositories/appDashboardBundleRepository';
import type { AppDashboardBundle, StoredAppDashboardBundle } from '../types/appDashboardBundle';

const STORAGE_PREFIX = 'brandwala.app.dashboard.bundle.v1';

const storageKey = (tenantId: number) => `${STORAGE_PREFIX}.${tenantId}`;

const readStorage = (tenantId: number): StoredAppDashboardBundle | null => {
  if (typeof window === 'undefined' || !tenantId) {
    return null;
  }

  const raw = window.localStorage.getItem(storageKey(tenantId));
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw) as StoredAppDashboardBundle;
    if (parsed?.schemaVersion !== 1 || parsed.tenantId !== tenantId) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
};

const writeStorage = (payload: StoredAppDashboardBundle) => {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(storageKey(payload.tenantId), JSON.stringify(payload));
};

export const useDashboardBundleStore = defineStore('dashboardBundle', {
  state: () => ({
    bundle: appDashboardBundleRepository.empty() as AppDashboardBundle,
    loadedTenantId: null as number | null,
    loading: false,
  }),

  getters: {
    lastRefreshedAt(state): string | null {
      return state.bundle.refreshedAt;
    },
    hasData(state): boolean {
      return state.bundle.refreshedAt !== null;
    },
  },

  actions: {
    loadCached(tenantId: number | null) {
      if (!tenantId) {
        this.reset();
        return;
      }

      if (this.loadedTenantId === tenantId && this.hasData) {
        return;
      }

      const stored = readStorage(tenantId);
      if (stored) {
        this.bundle = stored.bundle;
        this.loadedTenantId = tenantId;
        return;
      }

      this.reset();
      this.loadedTenantId = tenantId;
    },

    reset() {
      this.bundle = appDashboardBundleRepository.empty();
      this.loadedTenantId = null;
      this.loading = false;
    },

    async refresh(tenantId: number, parentTenantIds: number[]) {
      this.loading = true;
      try {
        const bundle = await appDashboardBundleRepository.fetchBundle(tenantId, parentTenantIds);
        this.bundle = bundle;
        this.loadedTenantId = tenantId;
        writeStorage({
          schemaVersion: 1,
          tenantId,
          refreshedAt: bundle.refreshedAt ?? new Date().toISOString(),
          bundle,
        });
        return bundle;
      } catch (error: unknown) {
        showErrorNotification((error as Error).message || 'Failed to refresh dashboard');
        throw error;
      } finally {
        this.loading = false;
      }
    },
  },
});
