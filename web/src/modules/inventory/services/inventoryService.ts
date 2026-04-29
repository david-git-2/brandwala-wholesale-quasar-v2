import { inventoryRepository } from '../repositories/inventoryRepository'

import type {
  CreateInventoryItemInput,
  CreateInventoryMovementInput,
  CreateInventoryStockInput,
  DeleteInventoryItemInput,
  DeleteInventoryMovementInput,
  DeleteInventoryStockInput,
  InventoryItem,
  InventoryItemWithStock,
  InventoryListPage,
  InventoryListQuery,
  InventoryMovement,
  InventoryServiceResult,
  InventoryStock,
  UpdateInventoryItemInput,
  UpdateInventoryMovementInput,
  UpdateInventoryStockInput,
} from '../types'

const listInventoryItems = async (
  payload: InventoryListQuery = {},
): Promise<InventoryServiceResult<InventoryListPage<InventoryItemWithStock>>> => {
  try {
    const data = await inventoryRepository.listInventoryItems(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory items.',
    }
  }
}

const getInventoryItemById = async (id: number): Promise<InventoryServiceResult<InventoryItem>> => {
  try {
    const data = await inventoryRepository.getInventoryItemById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory item.',
    }
  }
}

const createInventoryItem = async (
  payload: CreateInventoryItemInput,
): Promise<InventoryServiceResult<InventoryItem>> => {
  try {
    const data = await inventoryRepository.createInventoryItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create inventory item.',
    }
  }
}

const createInventoryItemsBulk = async (
  payload: CreateInventoryItemInput[],
): Promise<InventoryServiceResult<InventoryItem[]>> => {
  try {
    const data = await inventoryRepository.createInventoryItemsBulk(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create inventory items.',
    }
  }
}

const updateInventoryItem = async (
  payload: UpdateInventoryItemInput,
): Promise<InventoryServiceResult<InventoryItem>> => {
  try {
    const data = await inventoryRepository.updateInventoryItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update inventory item.',
    }
  }
}

const deleteInventoryItem = async (
  payload: DeleteInventoryItemInput,
): Promise<InventoryServiceResult<void>> => {
  try {
    await inventoryRepository.deleteInventoryItem(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete inventory item.',
    }
  }
}

const listInventoryStocks = async (
  payload: InventoryListQuery = {},
): Promise<InventoryServiceResult<InventoryListPage<InventoryStock>>> => {
  try {
    const data = await inventoryRepository.listInventoryStocks(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory stocks.',
    }
  }
}

const getInventoryStockById = async (
  id: number,
): Promise<InventoryServiceResult<InventoryStock>> => {
  try {
    const data = await inventoryRepository.getInventoryStockById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory stock.',
    }
  }
}

const createInventoryStock = async (
  payload: CreateInventoryStockInput,
): Promise<InventoryServiceResult<InventoryStock>> => {
  try {
    const data = await inventoryRepository.createInventoryStock(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create inventory stock.',
    }
  }
}

const createInventoryStocksBulk = async (
  payload: CreateInventoryStockInput[],
): Promise<InventoryServiceResult<InventoryStock[]>> => {
  try {
    const data = await inventoryRepository.createInventoryStocksBulk(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create inventory stocks.',
    }
  }
}

const updateInventoryStock = async (
  payload: UpdateInventoryStockInput,
): Promise<InventoryServiceResult<InventoryStock>> => {
  try {
    const data = await inventoryRepository.updateInventoryStock(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update inventory stock.',
    }
  }
}

const deleteInventoryStock = async (
  payload: DeleteInventoryStockInput,
): Promise<InventoryServiceResult<void>> => {
  try {
    await inventoryRepository.deleteInventoryStock(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete inventory stock.',
    }
  }
}

const listInventoryMovements = async (
  payload: InventoryListQuery = {},
): Promise<InventoryServiceResult<InventoryListPage<InventoryMovement>>> => {
  try {
    const data = await inventoryRepository.listInventoryMovements(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory movements.',
    }
  }
}

const getInventoryMovementById = async (
  id: number,
): Promise<InventoryServiceResult<InventoryMovement>> => {
  try {
    const data = await inventoryRepository.getInventoryMovementById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load inventory movement.',
    }
  }
}

const createInventoryMovement = async (
  payload: CreateInventoryMovementInput,
): Promise<InventoryServiceResult<InventoryMovement>> => {
  try {
    const data = await inventoryRepository.createInventoryMovement(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create inventory movement.',
    }
  }
}

const updateInventoryMovement = async (
  payload: UpdateInventoryMovementInput,
): Promise<InventoryServiceResult<InventoryMovement>> => {
  try {
    const data = await inventoryRepository.updateInventoryMovement(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update inventory movement.',
    }
  }
}

const deleteInventoryMovement = async (
  payload: DeleteInventoryMovementInput,
): Promise<InventoryServiceResult<void>> => {
  try {
    await inventoryRepository.deleteInventoryMovement(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete inventory movement.',
    }
  }
}

export const inventoryService = {
  listInventoryItems,
  getInventoryItemById,
  createInventoryItem,
  createInventoryItemsBulk,
  updateInventoryItem,
  deleteInventoryItem,
  listInventoryStocks,
  getInventoryStockById,
  createInventoryStock,
  createInventoryStocksBulk,
  updateInventoryStock,
  deleteInventoryStock,
  listInventoryMovements,
  getInventoryMovementById,
  createInventoryMovement,
  updateInventoryMovement,
  deleteInventoryMovement,
}
