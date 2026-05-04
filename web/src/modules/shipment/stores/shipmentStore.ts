import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { shipmentService } from '../services/shipmentService'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
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

    async fetchShipments(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listShipments(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipments.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipments = result.data ?? []
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

    async addShipmentToInventory() {
      this.saving = true
      this.error = null

      try {
        const shipment = this.selectedShipment
        if (!shipment?.id) {
          const result = { success: false as const, error: 'Shipment not found.' }
          this.error = result.error
          return result
        }

        const validItems = this.shipmentItems.filter((item) => (item.received_quantity ?? 0) > 0)
        if (!validItems.length) {
          const result = { success: false as const, error: 'No received quantity found to add.' }
          this.error = result.error
          handleApiFailure(result, result.error)
          return result
        }

        const itemPayload = validItems.map((item) => ({
          tenant_id: shipment.tenant_id,
          source_type: 'shipment' as const,
          source_id: item.id,
          product_id: item.product_id ?? null,
          name: item.name ?? 'Shipment Item',
          image_url: item.image_url ?? null,
          cost: calculateCostBdt({
            productWeight: item.product_weight,
            packageWeight: item.package_weight,
            cargoRate: shipment.cargo_rate,
            priceGbp: item.price_gbp,
            productConversionRate: shipment.product_conversion_rate,
            cargoConversionRate: shipment.cargo_conversion_rate,
          }),
          barcode: item.barcode ?? null,
          product_code: item.product_code ?? null,
          manufacturing_date: null,
          expire_date: null,
          status: 'active' as const,
        }))

        const createItemsResult = await inventoryService.createInventoryItemsBulk(itemPayload)
        if (!createItemsResult.success || !createItemsResult.data?.length) {
          this.error = createItemsResult.error ?? 'Failed to create inventory entries.'
          handleApiFailure(createItemsResult, this.error)
          return createItemsResult
        }

        const stocksPayload = createItemsResult.data.map((row, index) => ({
          inventory_item_id: row.id,
          available_quantity: Number(validItems[index]?.received_quantity ?? 0),
          reserved_quantity: 0,
          damaged_quantity: 0,
          stolen_quantity: 0,
          expired_quantity: 0,
        }))

        const createStocksResult = await inventoryService.createInventoryStocksBulk(stocksPayload)
        if (!createStocksResult.success) {
          this.error = createStocksResult.error ?? 'Failed to create inventory stocks.'
          handleApiFailure(createStocksResult, this.error)
          return createStocksResult
        }

        const updateShipmentResult = await this.updateShipment({
          id: shipment.id,
          patch: { inventory_added: true },
        })
        if (!updateShipmentResult.success) {
          return updateShipmentResult
        }

        showSuccessNotification('Shipment items added to inventory successfully.')
        return { success: true as const }
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
