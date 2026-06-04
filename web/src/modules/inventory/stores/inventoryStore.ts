import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
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
  CreateInventoryNoteInput,
  UpdateInventoryNoteInput,
  DeleteInventoryNoteInput,
  InventoryStock,
  InventoryItemWithStock,
} from '../types'

export const useInventoryStore = defineStore('inventory', {
  state: (): InventoryStoreState => ({
    items: [],
    stocks: [],
    movements: [],
    notes: [],
    shipmentInventoryAccountingSummaries: [],
    accountingEntries: [],
    accountingPayments: [],
    selectedItem: null,
    selectedStock: null,
    selectedMovement: null,
    selectedNote: null,
    selectedAccountingEntry: null,
    selectedAccountingPayment: null,
    total: 0,
    page: 1,
    page_size: 20,
    total_pages: 1,
    stock_total: 0,
    stock_page: 1,
    stock_page_size: 20,
    stock_total_pages: 1,
    movement_total: 0,
    movement_page: 1,
    movement_page_size: 20,
    movement_total_pages: 1,
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

        this.items = result.data?.data ?? []
        this.total = result.data?.meta.total ?? 0
        this.page = result.data?.meta.page ?? (payload.page ?? 1)
        this.page_size = result.data?.meta.page_size ?? (payload.page_size ?? payload.pageSize ?? 20)
        this.total_pages = result.data?.meta.total_pages ?? 1

        return result
      } finally {
        this.loading = false
      }
    },

    async fetchGlobalInventoryItems(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listGlobalInventoryItems(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load global inventory items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data?.data ?? []
        this.total = result.data?.meta.total ?? 0
        this.page = result.data?.meta.page ?? (payload.page ?? 1)
        this.page_size = result.data?.meta.page_size ?? (payload.page_size ?? payload.pageSize ?? 20)
        this.total_pages = result.data?.meta.total_pages ?? 1

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
            shipment: null,
            quantities: {
              available: 0,
              usable: 0,
              reserved: 0,
              damaged: 0,
              stolen: 0,
              expired: 0,
              open_box: 0,
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
            const existingShipment = this.items[index]?.shipment ?? null
            const existingQuantities = this.items[index]?.quantities ?? {
              available: 0,
              usable: 0,
              reserved: 0,
              damaged: 0,
              stolen: 0,
              expired: 0,
              open_box: 0,
            }
            this.items.splice(index, 1, {
              ...result.data,
              stock: existingStock,
              shipment: existingShipment,
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

        this.stocks = result.data?.data ?? []
        this.stock_total = result.data?.meta.total ?? 0
        this.stock_page = result.data?.meta.page ?? (payload.page ?? 1)
        this.stock_page_size = result.data?.meta.page_size ?? (payload.page_size ?? payload.pageSize ?? 20)
        this.stock_total_pages = result.data?.meta.total_pages ?? 1

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

        this.movements = result.data?.data ?? []
        this.movement_total = result.data?.meta.total ?? 0
        this.movement_page = result.data?.meta.page ?? (payload.page ?? 1)
        this.movement_page_size = result.data?.meta.page_size ?? (payload.page_size ?? payload.pageSize ?? 20)
        this.movement_total_pages = result.data?.meta.total_pages ?? 1

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

    async fetchShipmentInventoryAccountingSummaries(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listShipmentInventoryAccountingSummaries(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment inventory accounting summaries.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentInventoryAccountingSummaries = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async refreshShipmentInventoryAccountingSummaries(payload: {
      tenant_id: number
      shipment_id?: number | null
    }) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.refreshShipmentInventoryAccountingSummaries(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to refresh shipment inventory accounting summaries.'
          handleApiFailure(result, this.error)
          return result
        }

        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInventoryNotes(payload: InventoryListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await inventoryService.listInventoryNotes(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory notes.'
          handleApiFailure(result, this.error)
          return result
        }

        this.notes = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createInventoryNote(payload: CreateInventoryNoteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.createInventoryNote(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create inventory note.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.notes.unshift(result.data)
        }

        showSuccessNotification('Inventory note created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInventoryNote(payload: UpdateInventoryNoteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.updateInventoryNote(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update inventory note.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.notes.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.notes.splice(index, 1, result.data)
          }

          if (this.selectedNote?.id === result.data.id) {
            this.selectedNote = result.data
          }
        }

        showSuccessNotification('Inventory note updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInventoryNote(payload: DeleteInventoryNoteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await inventoryService.deleteInventoryNote(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete inventory note.'
          handleApiFailure(result, this.error)
          return result
        }

        this.notes = this.notes.filter((row) => row.id !== payload.id)
        if (this.selectedNote?.id === payload.id) {
          this.selectedNote = null
        }

        showSuccessNotification('Inventory note deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async adjustInventoryStockPool(payload: {
      inventoryItemId: number
      stockId: number
      fromPool: 'available' | 'reserved' | 'damaged' | 'stolen' | 'expired' | 'open_box'
      toPool: 'available' | 'reserved' | 'damaged' | 'stolen' | 'expired' | 'open_box'
      quantity: number
      note: string
      currentStock: InventoryStock
    }) {
      this.saving = true
      this.error = null

      try {
        const poolToField = {
          available: 'available_quantity',
          reserved: 'reserved_quantity',
          damaged: 'damaged_quantity',
          stolen: 'stolen_quantity',
          expired: 'expired_quantity',
          open_box: 'open_box_quantity',
        } as const

        const fromField = poolToField[payload.fromPool]
        const toField = poolToField[payload.toPool]

        const currentFromVal = payload.currentStock[fromField] || 0
        const currentToVal = payload.currentStock[toField] || 0

        if (currentFromVal < payload.quantity) {
          const errorMsg = `Insufficient stock in ${payload.fromPool} pool.`
          this.error = errorMsg
          return { success: false, error: errorMsg }
        }

        const patch = {
          [fromField]: currentFromVal - payload.quantity,
          [toField]: currentToVal + payload.quantity,
        }

        const updateResult = await inventoryService.updateInventoryStock({
          id: payload.stockId,
          patch,
        })

        if (!updateResult.success) {
          this.error = updateResult.error ?? 'Failed to update stock quantities.'
          handleApiFailure(updateResult, this.error)
          return updateResult
        }

        // Insert audit movement log
        await inventoryService.createInventoryMovement({
          inventory_item_id: payload.inventoryItemId,
          type: 'adjustment',
          quantity: payload.quantity,
          previous_quantity: currentFromVal,
          new_quantity: currentFromVal - payload.quantity,
          note: `Manual pool transfer from ${payload.fromPool} to ${payload.toPool}. Note: ${payload.note}`,
          created_by: null,
        })

        // Insert note if provided
        const authStore = useAuthStore()
        if (authStore.tenantId && payload.note.trim()) {
          let category: 'product_defect' | 'packaging_defect' | 'general' = 'general'
          if (payload.toPool === 'damaged') category = 'product_defect'
          if (payload.toPool === 'open_box') category = 'packaging_defect'

          await inventoryService.createInventoryNote({
            tenant_id: authStore.tenantId,
            product_id: null,
            inventory_item_id: payload.inventoryItemId,
            movement_id: null,
            category,
            content: payload.note.trim(),
            created_by: null,
          })
        }

        showSuccessNotification('Stock pool adjusted successfully.')
        return { success: true }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : 'Stock pool adjustment failed.'
        this.error = errorMsg
        return { success: false, error: errorMsg }
      } finally {
        this.saving = false
      }
    },

    async splitInventoryBatch(payload: {
      sourceItem: InventoryItemWithStock
      quantity: number
      condition: 'standard' | 'box_damage' | 'expired' | 'boxless' | 'stolen'
      nameSuffix: string
      note: string
    }) {
      this.saving = true
      this.error = null

      try {
        const sourceItem = payload.sourceItem
        const currentAvailable = sourceItem.stock?.available_quantity || 0

        if (currentAvailable < payload.quantity) {
          const errorMsg = `Insufficient available stock in batch #${sourceItem.id} to split.`
          this.error = errorMsg
          return { success: false, error: errorMsg }
        }

        // 1. Create the new inventory item batch
        const cleanName = sourceItem.name.replace(/ \((Box Damage|Expired|Boxless|Stolen\/Missing|Split)\)$/, '')
        const splitItemResult = await inventoryService.createInventoryItem({
          tenant_id: sourceItem.tenant_id,
          source_type: sourceItem.source_type,
          source_id: sourceItem.source_id,
          product_id: sourceItem.product_id,
          name: `${cleanName}${payload.nameSuffix}`,
          image_url: sourceItem.image_url,
          cost: payload.condition === 'expired' || payload.condition === 'stolen' ? 0 : (sourceItem.cost ?? 0),
          barcode: sourceItem.barcode,
          product_code: sourceItem.product_code,
          manufacturing_date: sourceItem.manufacturing_date,
          expire_date: sourceItem.expire_date,
          status: 'active',
        })

        if (!splitItemResult.success || !splitItemResult.data) {
          this.error = splitItemResult.error ?? 'Failed to create new split batch item.'
          handleApiFailure(splitItemResult, this.error)
          return splitItemResult
        }

        const targetItemId = splitItemResult.data.id

        // 2. Create the target stock record
        const targetStockResult = await inventoryService.createInventoryStock({
          inventory_item_id: targetItemId,
          available_quantity: payload.quantity,
          reserved_quantity: 0,
          damaged_quantity: 0,
          stolen_quantity: payload.condition === 'stolen' ? payload.quantity : 0,
          expired_quantity: payload.condition === 'expired' ? payload.quantity : 0,
          open_box_quantity: (payload.condition === 'box_damage' || payload.condition === 'boxless') ? payload.quantity : 0,
        })

        if (!targetStockResult.success) {
          this.error = targetStockResult.error ?? 'Failed to create stock record for split batch.'
          handleApiFailure(targetStockResult, this.error)
          return targetStockResult
        }

        // 3. Decrement quantity from the source stock record
        const updateSourceStockResult = await inventoryService.updateInventoryStock({
          id: sourceItem.stock!.id,
          patch: {
            available_quantity: currentAvailable - payload.quantity,
          },
        })

        if (!updateSourceStockResult.success) {
          this.error = updateSourceStockResult.error ?? 'Failed to update source stock quantity.'
          handleApiFailure(updateSourceStockResult, this.error)
          return updateSourceStockResult
        }

        // 4. Create movements
        await inventoryService.createInventoryMovement({
          inventory_item_id: sourceItem.id,
          type: 'adjustment',
          quantity: payload.quantity,
          previous_quantity: currentAvailable,
          new_quantity: currentAvailable - payload.quantity,
          note: `Split to new batch: ${splitItemResult.data.name}. Note: ${payload.note}`,
          created_by: null,
        })

        await inventoryService.createInventoryMovement({
          inventory_item_id: targetItemId,
          type: 'received',
          quantity: payload.quantity,
          previous_quantity: 0,
          new_quantity: payload.quantity,
          note: `Split from batch #${sourceItem.id}. Note: ${payload.note}`,
          created_by: null,
        })

        // 5. Create note for new batch
        if (payload.note.trim()) {
          let category: 'product_defect' | 'packaging_defect' | 'transit_loss' | 'general' = 'general'
          if (payload.condition === 'expired') category = 'product_defect'
          else if (payload.condition === 'stolen') category = 'transit_loss'
          else if (payload.condition === 'box_damage' || payload.condition === 'boxless') category = 'packaging_defect'

          await inventoryService.createInventoryNote({
            tenant_id: sourceItem.tenant_id,
            product_id: sourceItem.product_id,
            inventory_item_id: targetItemId,
            category,
            content: payload.note.trim(),
            created_by: null,
            movement_id: null,
          })
        }

        showSuccessNotification('Batch split successfully.')
        return { success: true }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : 'Batch split failed.'
        this.error = errorMsg
        return { success: false, error: errorMsg }
      } finally {
        this.saving = false
      }
    },

    async transferInventoryStock(payload: {
      sourceItem: InventoryItemWithStock
      targetItem: InventoryItemWithStock
      quantity: number
      note: string
    }) {
      this.saving = true
      this.error = null

      try {
        const sourceItem = payload.sourceItem
        const targetItem = payload.targetItem
        const currentSourceAvailable = sourceItem.stock?.available_quantity || 0
        const currentTargetAvailable = targetItem.stock?.available_quantity || 0

        if (currentSourceAvailable < payload.quantity) {
          const errorMsg = `Insufficient available stock in source batch #${sourceItem.id} to transfer.`
          this.error = errorMsg
          return { success: false, error: errorMsg }
        }

        // 1. Decrement source stock
        const updateSourceResult = await inventoryService.updateInventoryStock({
          id: sourceItem.stock!.id,
          patch: {
            available_quantity: currentSourceAvailable - payload.quantity,
          },
        })

        if (!updateSourceResult.success) {
          this.error = updateSourceResult.error ?? 'Failed to update source stock.'
          handleApiFailure(updateSourceResult, this.error)
          return updateSourceResult
        }

        // 2. Increment target stock
        const updateTargetResult = await inventoryService.updateInventoryStock({
          id: targetItem.stock!.id,
          patch: {
            available_quantity: currentTargetAvailable + payload.quantity,
          },
        })

        if (!updateTargetResult.success) {
          this.error = updateTargetResult.error ?? 'Failed to update target stock.'
          handleApiFailure(updateTargetResult, this.error)
          return updateTargetResult
        }

        // 3. Create movements
        await inventoryService.createInventoryMovement({
          inventory_item_id: sourceItem.id,
          type: 'adjustment',
          quantity: payload.quantity,
          previous_quantity: currentSourceAvailable,
          new_quantity: currentSourceAvailable - payload.quantity,
          note: `Transferred ${payload.quantity} units to batch #${targetItem.id}. Note: ${payload.note}`,
          created_by: null,
        })

        await inventoryService.createInventoryMovement({
          inventory_item_id: targetItem.id,
          type: 'adjustment',
          quantity: payload.quantity,
          previous_quantity: currentTargetAvailable,
          new_quantity: currentTargetAvailable + payload.quantity,
          note: `Transferred ${payload.quantity} units from batch #${sourceItem.id}. Note: ${payload.note}`,
          created_by: null,
        })

        // 4. Create note for target batch
        if (payload.note.trim()) {
          await inventoryService.createInventoryNote({
            tenant_id: sourceItem.tenant_id,
            product_id: sourceItem.product_id,
            inventory_item_id: targetItem.id,
            category: 'general',
            content: `Transferred ${payload.quantity} units from batch #${sourceItem.id}. Note: ${payload.note}`,
            created_by: null,
            movement_id: null,
          })
        }

        // 5. Auto delete source batch if all quantities are zero
        const remainingAvailable = currentSourceAvailable - payload.quantity
        const remainingReserved = sourceItem.stock?.reserved_quantity || 0
        const remainingDamaged = sourceItem.stock?.damaged_quantity || 0
        const remainingStolen = sourceItem.stock?.stolen_quantity || 0
        const remainingExpired = sourceItem.stock?.expired_quantity || 0
        const remainingOpenBox = sourceItem.stock?.open_box_quantity || 0

        const totalRemaining =
          remainingAvailable +
          remainingReserved +
          remainingDamaged +
          remainingStolen +
          remainingExpired +
          remainingOpenBox

        if (totalRemaining === 0) {
          const deleteResult = await inventoryService.deleteInventoryItem({ id: sourceItem.id })
          if (deleteResult.success) {
            this.items = this.items.filter((row) => row.id !== sourceItem.id)
          }
        }

        showSuccessNotification('Stock transferred successfully.')
        return { success: true }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : 'Stock transfer failed.'
        this.error = errorMsg
        return { success: false, error: errorMsg }
      } finally {
        this.saving = false
      }
    },
  },
})
