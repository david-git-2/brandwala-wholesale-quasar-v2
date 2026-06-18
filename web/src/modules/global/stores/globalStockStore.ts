import { defineStore } from 'pinia'

import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import type { Shipment } from 'src/modules/shipment/types'

import { globalRepository } from '../repositories/globalRepository'
import type { GlobalStockListQuery, GlobalStockRow } from '../types'
import { mapGlobalStockToInventoryView } from '../utils/mapGlobalStockToInventoryView'

type GlobalStockStoreState = {
  rows: GlobalStockRow[]
  items: InventoryItemWithStock[]
  total: number
  page: number
  page_size: number
  total_pages: number
  loading: boolean
}

export const useGlobalStockStore = defineStore('globalStock', {
  state: (): GlobalStockStoreState => ({
    rows: [],
    items: [],
    total: 0,
    page: 1,
    page_size: 20,
    total_pages: 1,
    loading: false,
  }),

  actions: {
    async fetchGlobalStock(
      payload: GlobalStockListQuery,
      shipmentsById: Map<number, Shipment> = new Map(),
    ) {
      this.loading = true
      try {
        const result = await globalRepository.listGlobalStockPage(payload)
        this.rows = result.data
        this.items = result.data.map((row) =>
          mapGlobalStockToInventoryView(
            row,
            row.shipment_id != null ? shipmentsById.get(row.shipment_id) ?? null : null,
          ),
        )
        this.total = result.meta.total
        this.page = result.meta.page
        this.page_size = result.meta.page_size
        this.total_pages = result.meta.total_pages
        return { success: true as const }
      } catch (error) {
        return {
          success: false as const,
          error: error instanceof Error ? error.message : 'Failed to load global stock.',
        }
      } finally {
        this.loading = false
      }
    },

    async deleteGlobalStock(id: number) {
      try {
        await globalRepository.deleteGlobalStock(id)
        return { success: true as const }
      } catch (error) {
        return {
          success: false as const,
          error: error instanceof Error ? error.message : 'Failed to delete stock item.',
        }
      }
    },
  },
})
