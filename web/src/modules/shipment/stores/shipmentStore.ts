import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { shipmentService } from '../services/shipmentService'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import type {
  CreateInventoryItemInput,
  CreateInventoryStockInput,
  CreateInventoryNoteInput,
} from 'src/modules/inventory/types'
import { calculateCostBdt } from '../utils/costing'
import type {
  AddShipmentItemFromProductInput,
  AddShipmentItemManualInput,
  BulkAddShipmentItemsFromProductInput,
  BulkCreateBatchCodePcInput,
  BulkDeleteShipmentItemsByProductInput,
  CreateBatchCodePcInput,
  CopyShipmentInput,
  CreateShipmentInput,
  DeleteBatchCodePcInput,
  DeleteAllBatchCodePcByShipmentInput,
  DeleteShipmentInput,
  DeleteShipmentItemInput,
  DeleteShipmentItemQuantityInput,
  ShipmentStoreState,
  UpdateShipmentItemInput,
  UpdateShipmentInput,
  UpdateShipmentFieldInput,
  ShipmentReceiveItemInput,
  ShipmentItem,
  ShipmentReceiveItemSplit,
} from '../types'

export const useShipmentStore = defineStore('shipment', {
  state: (): ShipmentStoreState => ({
    shipments: [],
    selectedShipment: null,
    shipmentItems: [],
    batchCodePcRows: [],
    loading: false,
    saving: false,
    error: null,
    totalShipments: 0,
    currentPage: 1,
    pageSize: 20,
    totalPages: 1,
  }),

  actions: {
    upsertShipmentItem(item: NonNullable<ShipmentStoreState['shipmentItems']>[number]) {
      const index = this.shipmentItems.findIndex((entry) => entry.id === item.id)
      if (index >= 0) {
        this.shipmentItems.splice(index, 1, item)
      } else {
        this.shipmentItems.push(item)
      }
    },

    clearError() {
      this.error = null
    },

    async fetchShipments(
      tenantId: number,
      page: number = 1,
      pageSize: number = 20,
      search?: string,
      status?: string,
    ) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listShipments(tenantId, page, pageSize, search, status)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipments.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipments = result.data?.data ?? []
        this.totalShipments = result.data?.meta.total ?? 0
        this.currentPage = result.data?.meta.page ?? 1
        this.pageSize = result.data?.meta.pageSize ?? 20
        this.totalPages = result.data?.meta.totalPages ?? 1
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchShipmentById(id: number) {
      this.loading = true
      this.error = null

      try {
        const [shipmentResult, itemsResult] = await Promise.all([
          shipmentService.getShipmentById(id),
          shipmentService.listShipmentItems(id),
        ])

        if (!shipmentResult.success) {
          this.error = shipmentResult.error ?? 'Failed to load shipment.'
          handleApiFailure(shipmentResult, this.error)
          return shipmentResult
        }

        if (!itemsResult.success) {
          this.error = itemsResult.error ?? 'Failed to load shipment items.'
          handleApiFailure(itemsResult, this.error)
          return itemsResult
        }

        this.selectedShipment = shipmentResult.data ?? null
        this.shipmentItems = itemsResult.data ?? []
        return shipmentResult
      } finally {
        this.loading = false
      }
    },

    async createShipment(payload: CreateShipmentInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.createShipment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create shipment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.shipments.unshift(result.data)
        }

        showSuccessNotification('Shipment created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateShipment(payload: UpdateShipmentInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.updateShipment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update shipment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.shipments.findIndex((shipment) => shipment.id === result.data?.id)
          if (index >= 0) {
            this.shipments.splice(index, 1, result.data)
          }

          if (this.selectedShipment?.id === result.data.id) {
            this.selectedShipment = result.data
          }
        }

        showSuccessNotification('Shipment updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateShipmentField(payload: UpdateShipmentFieldInput) {
      return this.updateShipment({
        id: payload.id,
        patch: {
          [payload.field]: payload.value,
        },
      })
    },

    async deleteShipment(payload: DeleteShipmentInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.deleteShipment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete shipment.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipments = this.shipments.filter((shipment) => shipment.id !== payload.id)

        if (this.selectedShipment?.id === payload.id) {
          this.selectedShipment = null
          this.shipmentItems = []
        }

        showSuccessNotification('Shipment deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async copyShipment(payload: CopyShipmentInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.copyShipment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to copy shipment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.shipments.unshift(result.data)
        }

        showSuccessNotification('Shipment copied successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchShipmentItems(shipmentId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listShipmentItems(shipmentId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentItems = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchShipmentItemsByTenant(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listShipmentItemsByTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentItems = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchBatchCodePcByShipment(shipmentId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listBatchCodePcByShipment(shipmentId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load batch rows.'
          handleApiFailure(result, this.error)
          return result
        }

        this.batchCodePcRows = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createBatchCodePc(payload: CreateBatchCodePcInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.createBatchCodePc(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create batch row.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.batchCodePcRows.push(result.data)
        }

        showSuccessNotification('Batch row created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async bulkCreateBatchCodePc(payload: BulkCreateBatchCodePcInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.bulkCreateBatchCodePc(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to bulk create batch rows.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data?.length) {
          this.batchCodePcRows = [...this.batchCodePcRows, ...result.data]
        }

        showSuccessNotification('Batch rows created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteBatchCodePc(payload: DeleteBatchCodePcInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.deleteBatchCodePc(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete batch row.'
          handleApiFailure(result, this.error)
          return result
        }

        this.batchCodePcRows = this.batchCodePcRows.filter((row) => row.id !== payload.id)
        showSuccessNotification('Batch row deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteAllBatchCodePcByShipment(payload: DeleteAllBatchCodePcByShipmentInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.deleteAllBatchCodePcByShipment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete all batch rows.'
          handleApiFailure(result, this.error)
          return result
        }

        this.batchCodePcRows = this.batchCodePcRows.filter(
          (row) => row.shipment_id !== payload.shipment_id,
        )
        showSuccessNotification('All batch rows deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async addShipmentItemFromProduct(payload: AddShipmentItemFromProductInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.addShipmentItemFromProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to add shipment item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.upsertShipmentItem(result.data)
        }
        showSuccessNotification('Shipment item added successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async addShipmentItemManual(payload: AddShipmentItemManualInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.addShipmentItemManual(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to add shipment item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.upsertShipmentItem(result.data)
        }
        showSuccessNotification('Shipment item added successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async bulkAddShipmentItemsFromProduct(payload: BulkAddShipmentItemsFromProductInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.bulkAddShipmentItemsFromProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to bulk add shipment items.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentItems(payload.shipment_id)
        showSuccessNotification('Shipment items updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteShipmentItemQuantity(payload: DeleteShipmentItemQuantityInput, shipmentId: number) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.deleteShipmentItemQuantity(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete shipment item quantity.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentItems(shipmentId)
        showSuccessNotification('Shipment item quantity updated.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateShipmentItem(payload: UpdateShipmentItemInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.updateShipmentItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update shipment item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.upsertShipmentItem(result.data)
        }
        showSuccessNotification('Shipment item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteShipmentItem(payload: DeleteShipmentItemInput) {
      this.saving = true
      this.error = null

      try {
        const deletedShipmentItem =
          this.shipmentItems.find((item) => item.id === payload.id) ?? null

        const result = await shipmentService.deleteShipmentItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete shipment item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (deletedShipmentItem) {
          const clearLinkResult =
            await shipmentService.clearOrderItemShipmentLinkByShipmentItem(deletedShipmentItem)

          if (!clearLinkResult.success) {
            this.error = clearLinkResult.error ?? 'Failed to clear order item shipment link.'
            handleApiFailure(clearLinkResult, this.error)
            return clearLinkResult
          }
        }

        this.shipmentItems = this.shipmentItems.filter((item) => item.id !== payload.id)
        showSuccessNotification('Shipment item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async addShipmentToInventory(receipts: ShipmentReceiveItemInput[]) {
      this.saving = true
      this.error = null

      try {
        const shipment = this.selectedShipment
        if (!shipment?.id) {
          const result = { success: false as const, error: 'Shipment not found.' }
          this.error = result.error
          return result
        }

        const itemsToCreate: Array<{
          receipt: ShipmentReceiveItemInput
          item: ShipmentItem
          split: ShipmentReceiveItemSplit
          expectedName: string
          itemCost: number
        }> = []

        const itemsPayload: CreateInventoryItemInput[] = []

        // Gather all items/splits to create in a single collection
        for (const receipt of receipts) {
          const item = this.shipmentItems.find((x) => x.id === receipt.shipmentItemId)
          if (!item) continue

          const itemCost = shipment.is_gbp
            ? calculateCostBdt({
                productWeight: item.product_weight,
                packageWeight: item.package_weight,
                cargoRate: shipment.cargo_rate,
                priceGbp: item.price_gbp,
                transactionRate: shipment.transaction_rate,
                productConversionRate: shipment.product_conversion_rate,
                cargoConversionRate: shipment.cargo_conversion_rate,
              })
            : Number(item.cost_bdt || 0)

          for (const split of receipt.splits) {
            if (split.qty <= 0) continue

            // Determine suffix name based on condition type
            let conditionSuffix = ''
            if (split.type === 'box_damage') conditionSuffix = ' (Box Damage)'
            else if (split.type === 'expired') conditionSuffix = ' (Expired)'
            else if (split.type === 'boxless') conditionSuffix = ' (Boxless)'
            else if (split.type === 'stolen') conditionSuffix = ' (Stolen/Missing)'

            const expectedName = `${item.name ?? 'Shipment Item'}${conditionSuffix}`

            itemsToCreate.push({
              receipt,
              item,
              split,
              expectedName,
              itemCost,
            })

            itemsPayload.push({
              tenant_id: shipment.tenant_id,
              source_type: 'shipment',
              source_id: item.id,
              product_id: item.product_id ?? null,
              name: expectedName,
              image_url: item.image_url ?? null,
              cost: split.type === 'expired' || split.type === 'stolen' ? 0 : itemCost,
              barcode: item.barcode ?? null,
              product_code: item.product_code ?? null,
              manufacturing_date: null,
              expire_date: null,
              status: 'active',
            })
          }
        }

        if (itemsPayload.length > 0) {
          // 1. Bulk create inventory items
          const itemsResult = await inventoryService.createInventoryItemsBulk(itemsPayload)
          if (!itemsResult.success || !itemsResult.data) {
            throw new Error(itemsResult.error ?? 'Failed to create inventory items.')
          }

          const createdItems = itemsResult.data
          const stocksPayload: CreateInventoryStockInput[] = []
          const notesPayload: CreateInventoryNoteInput[] = []

          // 2. Map created items back to their corresponding splits to build stocks/notes payloads
          for (const pending of itemsToCreate) {
            const createdItem = createdItems.find(
              (ci) => ci.source_id === pending.item.id && ci.name === pending.expectedName
            )
            if (!createdItem) {
              throw new Error(`Failed to find created inventory item for "${pending.expectedName}"`)
            }

            stocksPayload.push({
              inventory_item_id: createdItem.id,
              available_quantity: pending.split.qty,
              reserved_quantity: 0,
              damaged_quantity: 0,
              stolen_quantity: pending.split.type === 'stolen' ? pending.split.qty : 0,
              expired_quantity: pending.split.type === 'expired' ? pending.split.qty : 0,
              open_box_quantity: (pending.split.type === 'box_damage' || pending.split.type === 'boxless') ? pending.split.qty : 0,
            })

            if (pending.split.note && pending.split.note.trim()) {
              let noteCategory: 'packaging_defect' | 'product_defect' | 'transit_loss' = 'packaging_defect'
              if (pending.split.type === 'expired') noteCategory = 'product_defect'
              else if (pending.split.type === 'stolen') noteCategory = 'transit_loss'

              notesPayload.push({
                tenant_id: shipment.tenant_id,
                product_id: pending.item.product_id ?? null,
                inventory_item_id: createdItem.id,
                movement_id: null,
                category: noteCategory,
                content: pending.split.note.trim(),
                created_by: null,
              })
            }
          }

          // 3. Bulk create inventory stocks
          if (stocksPayload.length > 0) {
            const stocksResult = await inventoryService.createInventoryStocksBulk(stocksPayload)
            if (!stocksResult.success) {
              throw new Error(stocksResult.error ?? 'Failed to create inventory stocks.')
            }
          }

          // 4. Bulk create inventory notes
          if (notesPayload.length > 0) {
            const notesResult = await inventoryService.createInventoryNotesBulk(notesPayload)
            if (!notesResult.success) {
              throw new Error(notesResult.error ?? 'Failed to create inventory notes.')
            }
          }
        }

        // Update shipment status as completed adding to inventory
        const updateShipmentResult = await this.updateShipment({
          id: shipment.id,
          patch: { inventory_added: true, status: 'Added to Inventory' },
        })

        if (!updateShipmentResult.success) {
          return updateShipmentResult
        }

        await inventoryService.refreshShipmentInventoryAccountingSummaries({
          tenant_id: shipment.tenant_id,
          shipment_id: shipment.id,
        })

        showSuccessNotification('Shipment split items added to inventory successfully.')
        return { success: true as const }
      } catch (err) {
        const msg = err instanceof Error ? err.message : 'Failed to add shipment to inventory.'
        this.error = msg
        handleApiFailure({ success: false, error: msg }, msg)
        return { success: false as const, error: msg }
      } finally {
        this.saving = false
      }
    },


    async bulkDeleteShipmentItemsByProduct(payload: BulkDeleteShipmentItemsByProductInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.bulkDeleteShipmentItemsByProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to bulk delete shipment item quantities.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentItems(payload.shipment_id)
        showSuccessNotification('Shipment items updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

  },
})
