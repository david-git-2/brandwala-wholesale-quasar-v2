import { defineStore } from 'pinia'
import { globalShipmentRepository, type GlobalShipment, type GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import { globalShipmentBoxRepository } from '../repositories/globalShipmentBoxRepository'
import { type GlobalShipmentBox } from '../repositories/globalShipmentBoxRepository'
import { applyShipmentWeightBalance } from '../utils/applyShipmentWeightBalance'
import { supabase } from 'src/boot/supabase'

export const useGlobalShipmentStore = defineStore('global_shipment', {
  state: () => ({
    rows: [] as GlobalShipment[],
    loading: false,
    saving: false,
    error: null as string | null,
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 0,
    search: '',
    statusFilter: null as string | null,

    // Single shipment states
    currentShipment: null as GlobalShipment | null,
    currentShipmentItems: [] as GlobalShipmentItem[],
    currentShipmentBoxes: [] as GlobalShipmentBox[],
    currentShipmentStocks: [] as any[],
  }),

  actions: {
    async fetchShipments(
      tenantId: number,
      options?: {
        page?: number
        pageSize?: number
        search?: string | null
        status?: string | null
      },
    ) {
      this.loading = true
      this.error = null
      try {
        const page = options?.page ?? this.page
        const pageSize = options?.pageSize ?? this.pageSize
        const search = options?.search !== undefined ? options.search : this.search
        const status = options?.status !== undefined ? options.status : this.statusFilter

        const result = await globalShipmentRepository.listPaginated(
          tenantId,
          page,
          pageSize,
          search || undefined,
          status || undefined,
        )

        this.rows = result.data
        this.page = result.meta.page
        this.pageSize = result.meta.pageSize
        this.total = result.meta.total
        this.totalPages = result.meta.totalPages
        this.search = search || ''
        this.statusFilter = status
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load shipments'
      } finally {
        this.loading = false
      }
    },

    async fetchShipmentBoxes(shipmentId: number) {
      try {
        const boxes = await globalShipmentBoxRepository.listByShipmentId(shipmentId)
        this.currentShipmentBoxes = boxes
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load boxes'
      }
    },

    async fetchShipmentDetails(shipmentId: number) {
      this.loading = true
      this.error = null
      try {
        const [shipment, items, boxes] = await Promise.all([
          globalShipmentRepository.getById(shipmentId),
          globalShipmentRepository.listShipmentItems(shipmentId),
          globalShipmentBoxRepository.listByShipmentId(shipmentId),
        ])
        this.currentShipment = shipment
        this.currentShipmentItems = items
        this.currentShipmentBoxes = boxes

        let stocks: any[] = []
        if (items.length > 0) {
          const itemIds = items.map((i) => i.id)
          const { data, error } = await supabase
            .from('global_stocks')
            .select('*')
            .in('shipment_item_id', itemIds)
          if (!error && data) {
            stocks = data
          }
        }
        this.currentShipmentStocks = stocks
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load shipment details'
      } finally {
        this.loading = false
      }
    },

    async applyWeightBalance(shipmentId: number) {
      this.loading = true
      this.error = null
      try {
        const preload =
          this.currentShipment && this.currentShipment.id === shipmentId
            ? { shipment: this.currentShipment, items: this.currentShipmentItems }
            : undefined
        const result = await applyShipmentWeightBalance(shipmentId, preload)
        await this.fetchShipmentDetails(shipmentId)
        return result
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to apply weight balance'
        throw err
      } finally {
        this.loading = false
      }
    },

    async createShipment(
      tenantId: number,
      payload: {
        name: string
        type: 'domestic' | 'international'
        shipment_purchase_currency_id: number | null
        shipment_cost_currency_id: number | null
      },
    ) {
      this.loading = true
      this.error = null
      try {
        const newShipment = await globalShipmentRepository.createShipment(tenantId, payload)
        this.rows.unshift(newShipment)
        return newShipment
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create shipment'
        throw err
      } finally {
        this.loading = false
      }
    },

    async updateShipment(
      id: number,
      payload: Partial<Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>>,
    ) {
      this.loading = true
      this.error = null
      try {
        const updated = await globalShipmentRepository.updateShipment(id, payload)
        if (this.currentShipment?.id === id) {
          this.currentShipment = updated
        }
        const index = this.rows.findIndex((r) => r.id === id)
        if (index !== -1) {
          this.rows[index] = updated
        }
        return updated
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update shipment'
        throw err
      } finally {
        this.loading = false
      }
    },

    async deleteShipment(id: number) {
      this.loading = true
      this.error = null
      try {
        // Block delete if referenced in global_stocks
        const isReferenced = await globalShipmentRepository.checkShipmentStockReferences(id)
        if (isReferenced) {
          throw new Error('Cannot delete shipment. One or more shipment items are currently referenced in Warehouse Stock.')
        }

        await globalShipmentRepository.deleteShipment(id)
        this.rows = this.rows.filter((r) => r.id !== id)
        if (this.currentShipment?.id === id) {
          this.currentShipment = null
          this.currentShipmentItems = []
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete shipment'
        throw err
      } finally {
        this.loading = false
      }
    },

    async addShipmentItem(payload: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'sort_order'>) {
      this.saving = true
      this.error = null
      try {
        const maxSortOrder = this.currentShipmentItems.length > 0
          ? Math.max(...this.currentShipmentItems.map((item) => item.sort_order ?? 0))
          : 0
        const sort_order = maxSortOrder + 10

        const newItem = await globalShipmentRepository.createShipmentItem({
          ...payload,
          sort_order,
        })
        if (this.currentShipment?.id === payload.shipment_id) {
          this.currentShipmentItems.push(newItem)
        }
        return newItem
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to add shipment item'
        throw err
      } finally {
        this.saving = false
      }
    },

    async updateShipmentItem(
      id: number,
      payload: Partial<Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>>,
    ) {
      this.loading = true
      this.error = null
      try {
        const updated = await globalShipmentRepository.updateShipmentItem(id, payload)
        const index = this.currentShipmentItems.findIndex((item) => item.id === id)
        if (index !== -1) {
          this.currentShipmentItems[index] = updated
        }
        return updated
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update shipment item'
        throw err
      } finally {
        this.loading = false
      }
    },

    async deleteShipmentItem(id: number) {
      this.saving = true
      this.error = null
      try {
        const isReferenced = await globalShipmentRepository.checkShipmentItemStockReferences(id)
        if (isReferenced) {
          throw new Error('Cannot delete item. This shipment item is referenced in Warehouse Stock.')
        }

        await globalShipmentRepository.deleteShipmentItem(id)
        this.currentShipmentItems = this.currentShipmentItems.filter((item) => item.id !== id)
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete shipment item'
        throw err
      } finally {
        this.saving = false
      }
    },

    async reorderShipmentItems(shipmentId: number, itemsOrder: { id: number; sort_order: number }[]) {
      this.loading = true
      this.error = null
      try {
        await globalShipmentRepository.updateShipmentItemsOrder(itemsOrder)
        await this.fetchShipmentDetails(shipmentId)
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to reorder shipment items'
        throw err
      } finally {
        this.loading = false
      }
    },
  },
})
