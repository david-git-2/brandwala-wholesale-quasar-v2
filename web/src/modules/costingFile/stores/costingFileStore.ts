import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { costingFileItemService } from '../services/costingFileItemService'
import { costingFileService } from '../services/costingFileService'
import type {
  CostingFileCreateInput,
  CostingFileDetails,
  CostingFileItem,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemRequestCreateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileListEntry,
  CostingFilePricingUpdateInput,
  CostingFileStatusUpdateInput,
} from '../types'

type CostingFileStoreState = {
  items: CostingFileListEntry[]
  selectedItem: CostingFileDetails | null
  costingFileItems: CostingFileItem[]
  loading: boolean
  listLoading: boolean
  detailsLoading: boolean
  itemLoading: boolean
  mutationLoading: boolean
  error: string | null
}

export const useCostingFileStore = defineStore('costingFile', {
  state: (): CostingFileStoreState => ({
    items: [],
    selectedItem: null,
    costingFileItems: [],
    loading: false,
    listLoading: false,
    detailsLoading: false,
    itemLoading: false,
    mutationLoading: false,
    error: null,
  }),

  getters: {
    selectedCostingFile(state): CostingFileDetails | null {
      return state.selectedItem
    },
  },

  actions: {
    clearError() {
      this.error = null
    },

    clearSelectedItem() {
      this.selectedItem = null
      this.costingFileItems = []
    },

    async fetchCostingFilesByTenant(tenantId: number) {
      this.loading = true
      this.listLoading = true
      this.error = null

      try {
        const result = await costingFileService.listCostingFilesForTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
        this.listLoading = false
      }
    },

    async fetchCostingFilesByCustomerGroup(customerGroupId: number) {
      this.loading = true
      this.listLoading = true
      this.error = null

      try {
        const result = await costingFileService.listCostingFilesForCustomerGroup(customerGroupId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
        this.listLoading = false
      }
    },

    async fetchCostingFileById(id: number) {
      this.loading = true
      this.detailsLoading = true
      this.error = null

      try {
        const result = await costingFileService.getCostingFileById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing file details.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selectedItem = result.data ?? null
        return result
      } finally {
        this.loading = false
        this.detailsLoading = false
      }
    },

    async fetchCostingFileItems(costingFileId: number) {
      this.loading = true
      this.itemLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.listCostingFileItems(costingFileId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing file items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingFileItems = result.data ?? []
        return result
      } finally {
        this.loading = false
        this.itemLoading = false
      }
    },

    async fetchCostingFileWithItems(id: number) {
      const fileResult = await this.fetchCostingFileById(id)

      if (!fileResult.success || !fileResult.data) {
        return fileResult
      }

      await this.fetchCostingFileItems(id)
      return fileResult
    },

    async createCostingFile(payload: CostingFileCreateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileService.createCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.unshift(result.data)
          this.selectedItem = result.data
        }

        showSuccessNotification('Costing file created successfully.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileStatus(payload: CostingFileStatusUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileService.updateCostingFileStatus(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update costing file status.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)
          if (index >= 0) {
            this.items.splice(index, 1, { ...this.items[index]!, ...result.data })
          }

          if (this.selectedItem?.id === result.data.id) {
            this.selectedItem = { ...this.selectedItem, ...result.data }
          }
        }

        showSuccessNotification('Costing file status updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFilePricing(payload: CostingFilePricingUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileService.updateCostingFilePricing(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update costing file pricing.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data && this.selectedItem?.id === result.data.id) {
          this.selectedItem = { ...this.selectedItem, ...result.data }
        }

        showSuccessNotification('Costing file pricing updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async createCostingFileItemRequest(payload: CostingFileItemRequestCreateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.createCostingFileItemRequest(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create costing file item.'
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchCostingFileItems(payload.costingFileId)
        showSuccessNotification('Costing file item created.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileItemEnrichment(payload: CostingFileItemEnrichmentUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItemEnrichment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update costing file item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.costingFileItems.findIndex((item) => item.id === result.data?.id)
          if (index >= 0) {
            this.costingFileItems.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Costing file item updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileItemCustomerProfit(payload: CostingFileItemCustomerProfitUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItemCustomerProfit(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update customer profit.'
          handleApiFailure(result, this.error)
          return result
        }

        const index = this.costingFileItems.findIndex((item) => item.id === payload.id)
        if (index >= 0) {
          this.costingFileItems.splice(index, 1, {
            ...this.costingFileItems[index]!,
            customer_profit_rate: payload.customerProfitRate,
            updated_at: result.data?.updated_at ?? this.costingFileItems[index]!.updated_at,
          })
        }

        showSuccessNotification('Customer profit updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileItemStatus(payload: CostingFileItemStatusUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItemStatus(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update item status.'
          handleApiFailure(result, this.error)
          return result
        }

        const index = this.costingFileItems.findIndex((item) => item.id === payload.id)
        if (index >= 0) {
          this.costingFileItems.splice(index, 1, {
            ...this.costingFileItems[index]!,
            status: payload.status,
            updated_at: result.data?.updated_at ?? this.costingFileItems[index]!.updated_at,
          })
        }

        showSuccessNotification('Item status updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileItemOffer(payload: CostingFileItemOfferUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItemOffer(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update offer price.'
          handleApiFailure(result, this.error)
          return result
        }

        const index = this.costingFileItems.findIndex((item) => item.id === payload.id)
        if (index >= 0) {
          this.costingFileItems.splice(index, 1, {
            ...this.costingFileItems[index]!,
            offer_price_override_bdt:
              result.data?.offer_price_override_bdt ?? this.costingFileItems[index]!.offer_price_override_bdt,
            offer_price_bdt: result.data?.offer_price_bdt ?? this.costingFileItems[index]!.offer_price_bdt,
            updated_at: result.data?.updated_at ?? this.costingFileItems[index]!.updated_at,
          })
        }

        showSuccessNotification('Offer price updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },
  },
})
