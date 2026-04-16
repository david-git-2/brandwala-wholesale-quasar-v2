import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { shipmentService } from '../services/shipmentService'
import type {
  AddShipmentItemFromProductInput,
  AddShipmentItemManualInput,
  BulkAddShipmentItemsFromProductInput,
  BulkDeleteShipmentItemsByProductInput,
  CreateShipmentInput,
  CreateShipmentOrderInput,
  DeleteShipmentInput,
  DeleteShipmentItemQuantityInput,
  DeleteShipmentOrderInput,
  ShipmentStoreState,
  UpdateShipmentFieldInput,
  UpdateShipmentOrderInput,
} from '../types'

export const useShipmentStore = defineStore('shipment', {
  state: (): ShipmentStoreState => ({
    shipments: [],
    selectedShipment: null,
    shipmentItems: [],
    shipmentOrders: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
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
        const result = await shipmentService.getShipmentById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selectedShipment = result.data ?? null
        return result
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

    async updateShipmentField(payload: UpdateShipmentFieldInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.updateShipmentField(payload)

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
          this.shipmentOrders = []
        }

        showSuccessNotification('Shipment deleted successfully.')
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

        await this.fetchShipmentItems(payload.shipment_id)
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

        await this.fetchShipmentItems(payload.shipment_id)
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

    async fetchShipmentOrders(shipmentId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await shipmentService.listShipmentOrders(shipmentId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment orders.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentOrders = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createShipmentOrder(payload: CreateShipmentOrderInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.createShipmentOrder(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create shipment order.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentOrders(payload.shipment_id)
        showSuccessNotification('Shipment order created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateShipmentOrder(payload: UpdateShipmentOrderInput) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.updateShipmentOrder(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update shipment order.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentOrders(payload.shipment_id)
        showSuccessNotification('Shipment order updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteShipmentOrder(payload: DeleteShipmentOrderInput, shipmentId: number) {
      this.saving = true
      this.error = null

      try {
        const result = await shipmentService.deleteShipmentOrder(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete shipment order.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchShipmentOrders(shipmentId)
        showSuccessNotification('Shipment order deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
