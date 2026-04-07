import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { costingFileAccessService } from '../services/costingFileAccessService'
import { costingFileItemService } from '../services/costingFileItemService'
import { costingFileService } from '../services/costingFileService'
import type {
  CostingFileCreateInput,
  CostingFileDeleteInput,
  CostingFileDetails,
  CostingFileItem,
  CostingFileItemsCustomerProfitBulkUpdateInput,
  CostingFileItemCreateInput,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemDeleteInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemRequestCreateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileItemUpdateInput,
  CostingFileListEntry,
  CostingFilePricingUpdateInput,
  CostingFileViewer,
  CostingFileViewerGrantInput,
  CostingFileViewerRevokeInput,
  CostingFileStatusUpdateInput,
  CostingFileUpdateInput,
  TenantViewer,
} from '../types'

type CostingFileStoreState = {
  items: CostingFileListEntry[]
  totalItems: number
  selectedItem: CostingFileDetails | null
  costingFileItems: CostingFileItem[]
  costingFileViewers: CostingFileViewer[]
  tenantViewers: TenantViewer[]
  loading: boolean
  listLoading: boolean
  detailsLoading: boolean
  itemLoading: boolean
  viewerLoading: boolean
  mutationLoading: boolean
  error: string | null
}

const normalizeRequestItemToCostingFileItem = (
  item: Pick<
    CostingFileItem,
    | 'id'
    | 'costing_file_id'
    | 'item_type'
    | 'website_url'
    | 'quantity'
    | 'status'
    | 'created_by_email'
    | 'created_at'
    | 'updated_at'
  >,
): CostingFileItem => ({
  id: item.id,
  costing_file_id: item.costing_file_id,
  name: null,
  item_type: item.item_type ?? null,
  size: null,
  color: null,
  extra_information_1: null,
  extra_information_2: null,
  image_url: null,
  website_url: item.website_url,
  quantity: item.quantity,
  product_weight: null,
  package_weight: null,
  price_in_web_gbp: null,
  delivery_price_gbp: null,
  auxiliary_price_gbp: null,
  item_price_gbp: null,
  cargo_rate: null,
  costing_price_gbp: null,
  costing_price_bdt: null,
  offer_price_override_bdt: null,
  offer_price_bdt: null,
  customer_profit_rate: null,
  status: item.status,
  created_by_email: item.created_by_email,
  created_at: item.created_at,
  updated_at: item.updated_at,
})

export const useCostingFileStore = defineStore('costingFile', {
  state: (): CostingFileStoreState => ({
    items: [],
    totalItems: 0,
    selectedItem: null,
    costingFileItems: [],
    costingFileViewers: [],
    tenantViewers: [],
    loading: false,
    listLoading: false,
    detailsLoading: false,
    itemLoading: false,
    viewerLoading: false,
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
      this.costingFileViewers = []
    },

    async fetchCostingFilesByTenant(
      tenantId: number,
      options?: {
        customerGroupId?: number | null
        page?: number
        pageSize?: number
      },
    ) {
      this.loading = true
      this.listLoading = true
      this.error = null

      try {
        if (options) {
          const result = await costingFileService.listCostingFilesForTenantPage(
            tenantId,
            options.customerGroupId ?? null,
            options.page ?? 1,
            options.pageSize ?? 20,
          )

          if (!result.success) {
            this.error = result.error ?? 'Failed to load costing files.'
            handleApiFailure(result, this.error)
            return result
          }

          this.items = result.data?.items ?? []
          this.totalItems = result.data?.total ?? 0
          return result
        }

        const result = await costingFileService.listCostingFilesForTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        this.totalItems = result.data?.length ?? 0
        return result
      } finally {
        this.loading = false
        this.listLoading = false
      }
    },

    async fetchCostingFilesByCustomerGroup(
      customerGroupId: number,
      tenantId?: number | null,
      options?: {
        page?: number
        pageSize?: number
      },
    ) {
      this.loading = true
      this.listLoading = true
      this.error = null

      try {
        if (options) {
          const result = await costingFileService.listCostingFilesForCustomerGroupPage(
            customerGroupId,
            tenantId,
            options.page ?? 1,
            options.pageSize ?? 20,
          )

          if (!result.success) {
            this.error = result.error ?? 'Failed to load costing files.'
            handleApiFailure(result, this.error)
            return result
          }

          this.items = result.data?.items ?? []
          this.totalItems = result.data?.total ?? 0
          return result
        }

        const result = await costingFileService.listCostingFilesForCustomerGroup(
          customerGroupId,
          tenantId,
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        this.totalItems = result.data?.length ?? 0
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

    async fetchCostingFileByIdForCustomer(id: number) {
      this.loading = true
      this.detailsLoading = true
      this.error = null

      try {
        const result = await costingFileService.getCostingFileByIdForCustomer(id)

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

    async fetchCostingFileItemsForCustomer(costingFileId: number) {
      this.loading = true
      this.itemLoading = true
      this.error = null

      try {
        const result = await costingFileService.listCostingFileItemsForCustomer(costingFileId)

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

    async fetchTenantViewers(tenantId: number) {
      this.loading = true
      this.viewerLoading = true
      this.error = null

      try {
        const result = await costingFileAccessService.listTenantViewers(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load tenant viewers.'
          handleApiFailure(result, this.error)
          return result
        }

        this.tenantViewers = result.data ?? []
        return result
      } finally {
        this.loading = false
        this.viewerLoading = false
      }
    },

    async fetchCostingFileViewers(costingFileId: number) {
      this.loading = true
      this.viewerLoading = true
      this.error = null

      try {
        const result = await costingFileAccessService.listCostingFileViewers(costingFileId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load costing file viewers.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingFileViewers = result.data ?? []
        return result
      } finally {
        this.loading = false
        this.viewerLoading = false
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

    async fetchCostingFileWithItemsForCustomer(id: number) {
      const fileResult = await this.fetchCostingFileByIdForCustomer(id)

      if (!fileResult.success || !fileResult.data) {
        return fileResult
      }

      await this.fetchCostingFileItemsForCustomer(id)
      return fileResult
    },

    async grantCostingFileViewer(payload: CostingFileViewerGrantInput) {
      this.loading = true
      this.viewerLoading = true
      this.error = null

      try {
        const result = await costingFileAccessService.grantCostingFileViewer(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to add viewer.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.costingFileViewers.push(result.data)
        }

        showSuccessNotification('Viewer added successfully.')
        return result
      } finally {
        this.loading = false
        this.viewerLoading = false
      }
    },

    async revokeCostingFileViewer(payload: CostingFileViewerRevokeInput) {
      this.loading = true
      this.viewerLoading = true
      this.error = null

      try {
        const result = await costingFileAccessService.revokeCostingFileViewer(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to remove viewer.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingFileViewers = this.costingFileViewers.filter(
          (item) => item.membership_id !== payload.membershipId,
        )

        showSuccessNotification('Viewer removed successfully.')
        return result
      } finally {
        this.loading = false
        this.viewerLoading = false
      }
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

    async updateCostingFile(payload: CostingFileUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileService.updateCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update costing file.'
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

        showSuccessNotification('Costing file updated successfully.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async deleteCostingFile(payload: CostingFileDeleteInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileService.deleteCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)

        if (this.selectedItem?.id === payload.id) {
          this.clearSelectedItem()
        }

        showSuccessNotification('Costing file deleted successfully.')
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

        if (result.data) {
          this.costingFileItems.push({
            ...normalizeRequestItemToCostingFileItem(result.data),
            item_type: result.data.item_type ?? payload.itemType ?? null,
          })
        }

        showSuccessNotification('Costing file item created.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async createCostingFileItem(payload: CostingFileItemCreateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.createCostingFileItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create costing file item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.costingFileItems.push({
            ...result.data,
            item_type: result.data.item_type ?? payload.itemType ?? null,
          })
        }

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
            this.costingFileItems.splice(index, 1, {
              ...result.data,
              item_type: result.data.item_type ?? payload.itemType ?? this.costingFileItems[index]!.item_type,
            })
          }
        }

        showSuccessNotification('Costing file item updated.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },

    async updateCostingFileItem(payload: CostingFileItemUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update costing file item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.costingFileItems.findIndex((item) => item.id === result.data?.id)
          if (index >= 0) {
            this.costingFileItems.splice(index, 1, {
              ...result.data,
              item_type: result.data.item_type ?? payload.itemType ?? this.costingFileItems[index]!.item_type,
            })
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

    async updateCostingFileItemsCustomerProfit(payload: CostingFileItemsCustomerProfitBulkUpdateInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.updateCostingFileItemsCustomerProfit(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update customer profit.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedById = new Map(
          (result.data ?? []).map((item) => [item.id, item]),
        )

        this.costingFileItems = this.costingFileItems.map((item) => {
          const updated = updatedById.get(item.id)
          if (!updated) return item

          return {
            ...item,
            customer_profit_rate: updated.customer_profit_rate,
            updated_at: updated.updated_at,
          }
        })

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

    async deleteCostingFileItem(payload: CostingFileItemDeleteInput) {
      this.loading = true
      this.mutationLoading = true
      this.error = null

      try {
        const result = await costingFileItemService.deleteCostingFileItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete costing file item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingFileItems = this.costingFileItems.filter((item) => item.id !== payload.id)
        showSuccessNotification('Costing file item deleted.')
        return result
      } finally {
        this.loading = false
        this.mutationLoading = false
      }
    },
  },
})
