import { moduleRepository } from '../repositories/moduleRepository'
import type {
  Module,
  ModuleCreateInput,
  ModuleDeleteInput,
  ModuleServiceResult,
  ModuleUpdateInput,
} from '../types'

const listModules = async (): Promise<ModuleServiceResult<Module[]>> => {
  try {
    const data = await moduleRepository.listModules()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load modules.',
    }
  }
}

const createModule = async (
  module: ModuleCreateInput
): Promise<ModuleServiceResult<Module>> => {
  try {
    const data = await moduleRepository.createModule(module)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create module.',
    }
  }
}

const updateModule = async (
  module: ModuleUpdateInput
): Promise<ModuleServiceResult<Module>> => {
  try {
    const data = await moduleRepository.updateModule(module)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update module.',
    }
  }
}

const deleteModule = async (
  module: ModuleDeleteInput
): Promise<ModuleServiceResult<Module>> => {
  try {
    const data = await moduleRepository.deleteModule(module)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete module.',
    }
  }
}

export const moduleService = {
  listModules,
  createModule,
  updateModule,
  deleteModule,
}
