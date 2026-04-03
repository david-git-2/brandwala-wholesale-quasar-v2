import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
import { moduleService } from '../services/moduleService'
import type {
  Module,
  ModuleCreateInput,
  ModuleDeleteInput,
  ModuleStoreState,
  ModuleUpdateInput,
} from '../types'

export const useModuleStore = defineStore('module', {
  state: (): ModuleStoreState => ({
    items: [],
    loading: true,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchModules() {
      this.loading = true
      this.error = null

      try {
        const result = await moduleService.listModules()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load modules.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createModule(module: ModuleCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await moduleService.createModule(module)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create module.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items.push(result.data!)
        showSuccessNotification('Module created successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async updateModule(module: ModuleUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await moduleService.updateModule(module)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update module.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedModule = result.data!
        const index = this.items.findIndex((item) => item.id === updatedModule.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedModule)
        }

        showSuccessNotification('Module updated successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async deleteModule(module: ModuleDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await moduleService.deleteModule(module)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete module.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item: Module) => item.id !== module.id)
        showSuccessNotification('Module deleted successfully.')
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
