import { defineStore } from 'pinia'
import { globalStockTypeRepository, type GlobalStockType } from '../repositories/globalStockTypeRepository'

export const useGlobalStockTypeStore = defineStore('global_stock_type', {
  state: () => ({
    items: [] as GlobalStockType[],
    loading: false,
    saving: false,
    error: null as string | null,
  }),

  actions: {
    async fetchStockTypes(parentTenantId: number | null) {
      this.loading = true
      this.error = null
      try {
        const data = await globalStockTypeRepository.listStockTypes(parentTenantId)
        this.items = data
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load stock types'
      } finally {
        this.loading = false
      }
    },

    async createStockType(
      parentTenantId: number | null,
      payload: {
        description: string
        is_sellable: boolean
        sort_order: number
      },
    ) {
      this.saving = true
      this.error = null
      try {
        const newType = await globalStockTypeRepository.createStockType(parentTenantId, payload)
        this.items.push(newType)
        this.items.sort((a, b) => a.sort_order - b.sort_order)
        return newType
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create stock type'
        throw err
      } finally {
        this.saving = false
      }
    },

    async updateStockType(
      id: number,
      payload: {
        description: string
        is_sellable: boolean
        sort_order: number
      },
    ) {
      this.saving = true
      this.error = null
      try {
        const updated = await globalStockTypeRepository.updateStockType(id, payload)
        const index = this.items.findIndex((item) => item.id === id)
        if (index !== -1) {
          this.items[index] = updated
        }
        this.items.sort((a, b) => a.sort_order - b.sort_order)
        return updated
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update stock type'
        throw err
      } finally {
        this.saving = false
      }
    },

    async deleteStockType(id: number) {
      this.saving = true
      this.error = null
      try {
        const isReferenced = await globalStockTypeRepository.checkStockTypeReferences(id)
        if (isReferenced) {
          throw new Error('Cannot delete stock type. It is currently referenced in Warehouse Stock.')
        }

        await globalStockTypeRepository.deleteStockType(id)
        this.items = this.items.filter((item) => item.id !== id)
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete stock type'
        throw err
      } finally {
        this.saving = false
      }
    },
  },
})
