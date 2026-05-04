import { shipmentRepository } from '../repositories/shipmentRepository'
import type {
  AddShipmentItemFromProductInput,
  AddShipmentItemManualInput,
  BatchCodePc,
  BulkAddShipmentItemsFromProductInput,
  BulkCreateBatchCodePcInput,
  BulkDeleteShipmentItemsByProductInput,
  CreateBatchCodePcInput,
  CopyShipmentInput,
  CreateShipmentInput,
  DeleteShipmentInput,
  DeleteBatchCodePcInput,
  DeleteAllBatchCodePcByShipmentInput,
  DeleteShipmentItemInput,
  DeleteShipmentItemQuantityInput,
  Shipment,
  ShipmentItem,
  ShipmentServiceResult,
  UpdateShipmentItemInput,
  UpdateShipmentInput,
  UpdateShipmentFieldInput,
} from '../types'

const listShipments = async (
  tenantId: number,
): Promise<ShipmentServiceResult<Shipment[]>> => {
  try {
    const data = await shipmentRepository.listShipments(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipments.',
    }
  }
}

const getShipmentById = async (id: number): Promise<ShipmentServiceResult<Shipment>> => {
  try {
    const data = await shipmentRepository.getShipmentById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipment.',
    }
  }
}

const createShipment = async (
  payload: CreateShipmentInput,
): Promise<ShipmentServiceResult<Shipment>> => {
  try {
    const data = await shipmentRepository.createShipment(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create shipment.',
    }
  }
}

const updateShipment = async (
  payload: UpdateShipmentInput,
): Promise<ShipmentServiceResult<Shipment>> => {
  try {
    const data = await shipmentRepository.updateShipment(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update shipment.',
    }
  }
}

const updateShipmentField = async (
  payload: UpdateShipmentFieldInput,
): Promise<ShipmentServiceResult<Shipment>> => {
  return updateShipment({
    id: payload.id,
    patch: {
      [payload.field]: payload.value,
    },
  })
}

const deleteShipment = async (
  payload: DeleteShipmentInput,
): Promise<ShipmentServiceResult<void>> => {
  try {
    await shipmentRepository.deleteShipment(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete shipment.',
    }
  }
}

const copyShipment = async (
  payload: CopyShipmentInput,
): Promise<ShipmentServiceResult<Shipment>> => {
  try {
    const data = await shipmentRepository.copyShipment(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to copy shipment.',
    }
  }
}

const listShipmentItems = async (
  shipmentId: number,
): Promise<ShipmentServiceResult<ShipmentItem[]>> => {
  try {
    const data = await shipmentRepository.listShipmentItems(shipmentId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipment items.',
    }
  }
}

const listShipmentItemsByTenant = async (
  tenantId: number,
): Promise<ShipmentServiceResult<ShipmentItem[]>> => {
  try {
    const data = await shipmentRepository.listShipmentItemsByTenant(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipment items.',
    }
  }
}

const addShipmentItemFromProduct = async (
  payload: AddShipmentItemFromProductInput,
): Promise<ShipmentServiceResult<ShipmentItem>> => {
  try {
    const data = await shipmentRepository.addShipmentItemFromProduct(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add shipment item.',
    }
  }
}

const addShipmentItemManual = async (
  payload: AddShipmentItemManualInput,
): Promise<ShipmentServiceResult<ShipmentItem>> => {
  try {
    const data = await shipmentRepository.addShipmentItemManual(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add shipment item.',
    }
  }
}

const bulkAddShipmentItemsFromProduct = async (
  payload: BulkAddShipmentItemsFromProductInput,
): Promise<ShipmentServiceResult<ShipmentItem[]>> => {
  try {
    const data = await shipmentRepository.bulkAddShipmentItemsFromProduct(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to bulk add shipment items.',
    }
  }
}

const deleteShipmentItemQuantity = async (
  payload: DeleteShipmentItemQuantityInput,
): Promise<ShipmentServiceResult<boolean>> => {
  try {
    const data = await shipmentRepository.deleteShipmentItemQuantity(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error ? error.message : 'Failed to delete shipment item quantity.',
    }
  }
}

const updateShipmentItem = async (
  payload: UpdateShipmentItemInput,
): Promise<ShipmentServiceResult<ShipmentItem>> => {
  try {
    const data = await shipmentRepository.updateShipmentItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update shipment item.',
    }
  }
}

const deleteShipmentItem = async (
  payload: DeleteShipmentItemInput,
): Promise<ShipmentServiceResult<void>> => {
  try {
    await shipmentRepository.deleteShipmentItem(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete shipment item.',
    }
  }
}

const clearOrderItemShipmentLinkByShipmentItem = async (
  shipmentItem: ShipmentItem,
): Promise<ShipmentServiceResult<number>> => {
  try {
    const data = await shipmentRepository.clearOrderItemShipmentLinkByShipmentItem(shipmentItem)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to clear order item shipment link.',
    }
  }
}

const bulkDeleteShipmentItemsByProduct = async (
  payload: BulkDeleteShipmentItemsByProductInput,
): Promise<ShipmentServiceResult<number>> => {
  try {
    const data = await shipmentRepository.bulkDeleteShipmentItemsByProduct(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to bulk delete shipment item quantities.',
    }
  }
}

const listBatchCodePcByShipment = async (
  shipmentId: number,
): Promise<ShipmentServiceResult<BatchCodePc[]>> => {
  try {
    const data = await shipmentRepository.listBatchCodePcByShipment(shipmentId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load batch rows.',
    }
  }
}

const createBatchCodePc = async (
  payload: CreateBatchCodePcInput,
): Promise<ShipmentServiceResult<BatchCodePc>> => {
  try {
    const data = await shipmentRepository.createBatchCodePc(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create batch row.',
    }
  }
}

const bulkCreateBatchCodePc = async (
  payload: BulkCreateBatchCodePcInput,
): Promise<ShipmentServiceResult<BatchCodePc[]>> => {
  try {
    const data = await shipmentRepository.bulkCreateBatchCodePc(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to bulk create batch rows.',
    }
  }
}

const deleteBatchCodePc = async (
  payload: DeleteBatchCodePcInput,
): Promise<ShipmentServiceResult<void>> => {
  try {
    await shipmentRepository.deleteBatchCodePc(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete batch row.',
    }
  }
}

const deleteAllBatchCodePcByShipment = async (
  payload: DeleteAllBatchCodePcByShipmentInput,
): Promise<ShipmentServiceResult<void>> => {
  try {
    await shipmentRepository.deleteAllBatchCodePcByShipment(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete all batch rows.',
    }
  }
}

export const shipmentService = {
  listShipments,
  getShipmentById,
  createShipment,
  updateShipment,
  updateShipmentField,
  deleteShipment,
  copyShipment,
  listShipmentItems,
  listShipmentItemsByTenant,
  addShipmentItemFromProduct,
  addShipmentItemManual,
  bulkAddShipmentItemsFromProduct,
  deleteShipmentItemQuantity,
  updateShipmentItem,
  deleteShipmentItem,
  clearOrderItemShipmentLinkByShipmentItem,
  bulkDeleteShipmentItemsByProduct,
  listBatchCodePcByShipment,
  createBatchCodePc,
  bulkCreateBatchCodePc,
  deleteBatchCodePc,
  deleteAllBatchCodePcByShipment,
}
