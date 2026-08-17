import { defineStore } from 'pinia';
import { cargoCompanyRepository } from '../repositories/cargoCompanyRepository';
import type {
  CargoCompany,
  CargoCompanyCreateInput,
  CargoCompanyUpdateInput,
} from '../types/cargoCompany';

export const useCargoCompanyStore = defineStore('cargo_company', {
  state: () => ({
    items: [] as CargoCompany[],
    loading: false,
    saving: false,
    error: null as string | null,
  }),

  getters: {
    defaultCompany(state): CargoCompany | null {
      return state.items.find((c) => c.is_default) ?? null;
    },
  },

  actions: {
    async fetchCompanies(tenantId: number, includeInactive = true) {
      this.loading = true;
      this.error = null;
      try {
        this.items = await cargoCompanyRepository.listCargoCompanies(tenantId, includeInactive);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load cargo companies';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async createCompany(payload: CargoCompanyCreateInput) {
      this.saving = true;
      this.error = null;
      try {
        const row = await cargoCompanyRepository.createCargoCompany(payload);
        this.items = [row, ...this.items.filter((c) => c.id !== row.id)].sort((a, b) => {
          if (a.is_default !== b.is_default) return a.is_default ? -1 : 1;
          return a.name.localeCompare(b.name);
        });
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
        this.items = this.items
          .map((c) => (c.id === row.id ? row : c))
          .sort((a, b) => {
            if (a.is_default !== b.is_default) return a.is_default ? -1 : 1;
            return a.name.localeCompare(b.name);
          });
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
