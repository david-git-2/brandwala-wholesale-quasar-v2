import { shipmentRepository } from '../repositories/shipmentRepository'
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
  Shipment,
  ShipmentItem,
  ShipmentOrder,
  ShipmentServiceResult,
  UpdateShipmentFieldInput,
  UpdateShipmentOrderInput,
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

const updateShipmentField = async (
  payload: UpdateShipmentFieldInput,
): Promise<ShipmentServiceResult<Shipment>> => {
  try {
    const data = await shipmentRepository.updateShipmentField(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update shipment.',
    }
  }
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

const listShipmentOrders = async (
  shipmentId: number,
): Promise<ShipmentServiceResult<ShipmentOrder[]>> => {
  try {
    const data = await shipmentRepository.listShipmentOrders(shipmentId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipment orders.',
    }
  }
}

const createShipmentOrder = async (
  payload: CreateShipmentOrderInput,
): Promise<ShipmentServiceResult<ShipmentOrder>> => {
  try {
    const data = await shipmentRepository.createShipmentOrder(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create shipment order.',
    }
  }
}

const updateShipmentOrder = async (
  payload: UpdateShipmentOrderInput,
): Promise<ShipmentServiceResult<ShipmentOrder>> => {
  try {
    const data = await shipmentRepository.updateShipmentOrder(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update shipment order.',
    }
  }
}

const deleteShipmentOrder = async (
  payload: DeleteShipmentOrderInput,
): Promise<ShipmentServiceResult<void>> => {
  try {
    await shipmentRepository.deleteShipmentOrder(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete shipment order.',
    }
  }
}

export const shipmentService = {
  listShipments,
  getShipmentById,
  createShipment,
  updateShipmentField,
  deleteShipment,
  listShipmentItems,
  addShipmentItemFromProduct,
  addShipmentItemManual,
  bulkAddShipmentItemsFromProduct,
  deleteShipmentItemQuantity,
  bulkDeleteShipmentItemsByProduct,
  listShipmentOrders,
  createShipmentOrder,
  updateShipmentOrder,
  deleteShipmentOrder,
}
