import { defineStore } from 'pinia';
import type { InboundShipmentListCargoCompany } from '../repositories/globalShipmentRepository';
import { cargoCompanyRepository } from '../repositories/cargoCompanyRepository';
import type {
  CargoCompany,
  CargoCompanyCreateInput,
  CargoCompanyUpdateInput,
} from '../types/cargoCompany';

const sortCompanies = (rows: CargoCompany[]) =>
  [...rows].sort((a, b) => {
    if (a.is_default !== b.is_default) return a.is_default ? -1 : 1;
    return a.name.localeCompare(b.name);
  });

const mapReferenceToCompany = (
  tenantId: number,
  row: InboundShipmentListCargoCompany,
): CargoCompany => ({
  id: row.id,
  parent_tenant_id: tenantId,
  name: row.name,
  code: row.code,
  is_default: row.is_default,
  is_active: true,
  phone: null,
  email: null,
  address: null,
  notes: null,
  wallet_entity_id: null,
});

export const useCargoCompanyStore = defineStore('cargo_company', {
  state: () => ({
    items: [] as CargoCompany[],
    cachedParentTenantId: null as number | null,
    includeInactiveLoaded: false,
    loading: false,
    saving: false,
    error: null as string | null,
  }),

  getters: {
    defaultCompany(state): CargoCompany | null {
      return state.items.find((c) => c.is_default && c.is_active) ?? null;
    },
    activeItems(state): CargoCompany[] {
      return state.items.filter((c) => c.is_active);
    },
    selectOptions(state): Array<{ label: string; value: number }> {
      return state.items
        .filter((c) => c.is_active)
        .map((c) => ({
          label: `${c.name} (${c.code})`,
          value: c.id,
        }));
    },
  },

  actions: {
    seedFromListReference(tenantId: number, rows: InboundShipmentListCargoCompany[]) {
      if (this.items.length > 0 || rows.length === 0) return;
      this.cachedParentTenantId = tenantId;
      this.includeInactiveLoaded = false;
      this.items = sortCompanies(rows.map((row) => mapReferenceToCompany(tenantId, row)));
    },

    async fetchCompanies(tenantId: number, includeInactive = true, force = false) {
      if (tenantId !== this.cachedParentTenantId) {
        this.items = [];
        this.cachedParentTenantId = tenantId;
        this.includeInactiveLoaded = false;
      }

      const needsFullList = includeInactive;
      const cacheValid =
        !force &&
        this.items.length > 0 &&
        this.cachedParentTenantId === tenantId &&
        (!needsFullList || this.includeInactiveLoaded);

      if (cacheValid) {
        return;
      }

      this.loading = true;
      this.error = null;
      try {
        this.items = await cargoCompanyRepository.listCargoCompanies(tenantId, includeInactive);
        this.cachedParentTenantId = tenantId;
        this.includeInactiveLoaded = includeInactive;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load cargo companies';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async ensureCompaniesLoaded(
      tenantId: number | null | undefined,
      options?: { includeInactive?: boolean; force?: boolean },
    ) {
      if (!tenantId) return;
      const includeInactive = options?.includeInactive ?? false;
      await this.fetchCompanies(tenantId, includeInactive, options?.force ?? false);
    },

    async createCompany(payload: CargoCompanyCreateInput) {
      this.saving = true;
      this.error = null;
      try {
        const row = await cargoCompanyRepository.createCargoCompany(payload);
        this.cachedParentTenantId = payload.parent_tenant_id;
        this.items = sortCompanies([row, ...this.items.filter((c) => c.id !== row.id)]);
        return row;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create cargo company';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async updateCompany(payload: CargoCompanyUpdateInput) {
      this.saving = true;
      this.error = null;
      try {
        const row = await cargoCompanyRepository.updateCargoCompany(payload);
        this.cachedParentTenantId = payload.parent_tenant_id;
        this.items = sortCompanies(this.items.map((c) => (c.id === row.id ? row : c)));
        return row;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update cargo company';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async deleteCompany(id: number, tenantId: number) {
      this.saving = true;
      this.error = null;
      try {
        await cargoCompanyRepository.deleteCargoCompany(id, tenantId);
        this.items = this.items.filter((c) => c.id !== id);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete cargo company';
        throw err;
      } finally {
        this.saving = false;
      }
    },
  },
});
