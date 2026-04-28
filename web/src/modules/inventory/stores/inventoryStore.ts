import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { inventoryService } from '../services/inventoryService'
import type {
  CreateInventoryItemInput,
  CreateInventoryMovementInput,
  CreateInventoryStockInput,
  DeleteInventoryItemInput,
  DeleteInventoryMovementInput,
  DeleteInventoryStockInput,
  InventoryListQuery,
  InventoryStoreState,
  UpdateInventoryItemInput,
  UpdateInventoryMovementInput,
  UpdateInventoryStockInput,
} from '../types'

const DEFAULT_PAGINATION = { total: 0, page: 1, pageSize: 20 }

export const useInventoryStore = defineStore('inventory', {
  state: (): InventoryStoreState => ({
    items: [],
    stocks: [],
    movements: [],
    selectedItem: null,
    selectedStock: null,
    selectedMovement: null,
    itemPagination: { ...DEFAULT_PAGINATION },
    stockPagination: { ...DEFAULT_PAGINATION },
    movementPagination: { ...DEFAULT_PAGINATION },
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchInventoryItems(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listInventoryItems(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory items.'
          handleApiFailure(result, this.error)
          return result
        }

        const page = result.data ?? { rows: [], ...DEFAULT_PAGINATION }
        this.items = page.rows
        this.itemPagination = {
          total: page.total,
          page: page.page,
          pageSize: page.pageSize,
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async fetchInventoryItemById(id: number) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.getInventoryItemById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selectedItem = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async createInventoryItem(payload: CreateInventoryItemInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.createInventoryItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create inventory item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.unshift({
            ...result.data,
            stock: null,
            quantities: {
              available: 0,
              reserved: 0,
              damaged: 0,
              stolen: 0,
              expired: 0,
            },
          })
        }

        showSuccessNotification('Inventory item created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInventoryItem(payload: UpdateInventoryItemInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.updateInventoryItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update inventory item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            const existingStock = this.items[index]?.stock ?? null
            const existingQuantities = this.items[index]?.quantities ?? {
              available: 0,
              reserved: 0,
              damaged: 0,
              stolen: 0,
              expired: 0,
            }
            this.items.splice(index, 1, {
              ...result.data,
              stock: existingStock,
              quantities: existingQuantities,
            })
          }

          if (this.selectedItem?.id === result.data.id) {
            this.selectedItem = result.data
          }
        }

        showSuccessNotification('Inventory item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInventoryItem(payload: DeleteInventoryItemInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.deleteInventoryItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete inventory item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((row) => row.id !== payload.id)
        if (this.selectedItem?.id === payload.id) {
          this.selectedItem = null
        }

        showSuccessNotification('Inventory item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInventoryStocks(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listInventoryStocks(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory stocks.'
          handleApiFailure(result, this.error)
          return result
        }

        const page = result.data ?? { rows: [], ...DEFAULT_PAGINATION }
        this.stocks = page.rows
        this.stockPagination = {
          total: page.total,
          page: page.page,
          pageSize: page.pageSize,
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async fetchInventoryStockById(id: number) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.getInventoryStockById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory stock.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selectedStock = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async createInventoryStock(payload: CreateInventoryStockInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.createInventoryStock(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create inventory stock.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.stocks.unshift(result.data)
        }

        showSuccessNotification('Inventory stock created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInventoryStock(payload: UpdateInventoryStockInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.updateInventoryStock(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update inventory stock.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.stocks.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.stocks.splice(index, 1, result.data)
          }

          if (this.selectedStock?.id === result.data.id) {
            this.selectedStock = result.data
          }
        }

        showSuccessNotification('Inventory stock updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInventoryStock(payload: DeleteInventoryStockInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.deleteInventoryStock(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete inventory stock.'
          handleApiFailure(result, this.error)
          return result
        }

        this.stocks = this.stocks.filter((row) => row.id !== payload.id)
        if (this.selectedStock?.id === payload.id) {
          this.selectedStock = null
        }

        showSuccessNotification('Inventory stock deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInventoryMovements(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listInventoryMovements(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory movements.'
          handleApiFailure(result, this.error)
          return result
        }

        const page = result.data ?? { rows: [], ...DEFAULT_PAGINATION }
        this.movements = page.rows
        this.movementPagination = {
          total: page.total,
          page: page.page,
          pageSize: page.pageSize,
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async fetchInventoryMovementById(id: number) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.getInventoryMovementById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory movement.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selectedMovement = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async createInventoryMovement(payload: CreateInventoryMovementInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.createInventoryMovement(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create inventory movement.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.movements.unshift(result.data)
        }

        showSuccessNotification('Inventory movement created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInventoryMovement(payload: UpdateInventoryMovementInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.updateInventoryMovement(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update inventory movement.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.movements.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.movements.splice(index, 1, result.data)
          }

          if (this.selectedMovement?.id === result.data.id) {
            this.selectedMovement = result.data
          }
        }

        showSuccessNotification('Inventory movement updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInventoryMovement(payload: DeleteInventoryMovementInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.deleteInventoryMovement(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete inventory movement.'
          handleApiFailure(result, this.error)
          return result
        }

        this.movements = this.movements.filter((row) => row.id !== payload.id)
        if (this.selectedMovement?.id === payload.id) {
          this.selectedMovement = null
        }

        showSuccessNotification('Inventory movement deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
