import { supabase } from 'src/boot/supabase'
import type { CommerceInvoice, CommerceInvoiceDetails } from '../types'

type CommerceOrderRow = {
  id: number
  tenant_id: number
  customer_group_id: number | null
  delivery_charge: number
  wrapping_charge: number
  cod: number
  is_delivery_charge_inclusive: boolean
  invoice_ids: number[] | null
}

type CommerceOrderItemRow = {
  id: number
  order_id: number
  product_id: number
  quantity: number
  cost_bdt: number
  sell_price_bdt: number
  recipient_price_bdt: number
  invoice_id: number | null
  image_url: string | null
  inventory_item_id: number | null
  shipment_item_id: number | null
}

type InventoryItemRow = {
  id: number
  tenant_id: number
  cost: number | null
  source_type: 'manual' | 'shipment'
  source_id: number | null
}

type InventoryStockRow = {
  id: number
  available_quantity: number
  reserved_quantity: number
  damaged_quantity: number
  stolen_quantity: number
  expired_quantity: number
  open_box_quantity: number
}

const round2 = (value: number) => Number(value.toFixed(2))

const getUsableQuantity = (stock: InventoryStockRow) =>
  Math.max(
    0,
    Number(stock.available_quantity || 0)
      - Number(stock.reserved_quantity || 0)
      - Number(stock.damaged_quantity || 0)
      - Number(stock.stolen_quantity || 0),
  )

const getCommerceOrderContext = async (orderId: number): Promise<CommerceOrderRow> => {
  const { data, error } = await supabase
    .from('commerce_orders')
    .select('id, tenant_id, customer_group_id, delivery_charge, wrapping_charge, cod, is_delivery_charge_inclusive, invoice_ids')
    .eq('id', orderId)
    .single()

  if (error || !data) {
    throw error || new Error('Order not found.')
  }

  return data as CommerceOrderRow
}

const adjustInventoryStock = async (payload: {
  inventoryItemId: number
  delta: number
  note: string
}) => {
  const { data: inventoryItem, error: itemError } = await supabase
    .from('inventory_items')
    .select('id, tenant_id, cost, source_type, source_id')
    .eq('id', payload.inventoryItemId)
    .single()

  if (itemError || !inventoryItem) {
    throw itemError || new Error('Inventory item not found.')
  }

  const { data: stock, error: stockError } = await supabase
    .from('inventory_stocks')
    .select('id, available_quantity, reserved_quantity, damaged_quantity, stolen_quantity, expired_quantity, open_box_quantity')
    .eq('inventory_item_id', payload.inventoryItemId)
    .maybeSingle()

  if (stockError || !stock) {
    throw stockError || new Error('Inventory stock not found for selected item.')
  }

  const currentAvailable = Number(stock.available_quantity || 0)
  const usable = getUsableQuantity(stock as InventoryStockRow)

  if (payload.delta < 0) {
    const required = Math.abs(payload.delta)
    if (required > usable || required > currentAvailable) {
      throw new Error('Not enough usable stock for selected inventory item.')
    }
  }

  const nextAvailable = currentAvailable + payload.delta
  if (nextAvailable < 0) {
    throw new Error('Not enough stock for selected inventory item.')
  }

  const { error: updateError } = await supabase
    .from('inventory_stocks')
    .update({ available_quantity: nextAvailable })
    .eq('id', stock.id)

  if (updateError) {
    throw updateError
  }

  const { error: movementError } = await supabase
    .from('inventory_movements')
    .insert([
      {
        inventory_item_id: payload.inventoryItemId,
        type: payload.delta < 0 ? 'sold' : 'adjustment',
        quantity: Math.abs(payload.delta),
        previous_quantity: currentAvailable,
        new_quantity: nextAvailable,
        note: payload.note,
        created_by: null,
      },
    ])

  if (movementError) {
    throw movementError
  }

  return {
    inventoryItem: inventoryItem as InventoryItemRow,
  }
}

const syncInvoiceTotals = async (invoiceId: number) => {
  const { data: invoice, error: invoiceErr } = await supabase
    .from('commerce_invoices')
    .select('*')
    .eq('id', invoiceId)
    .single()
  if (invoiceErr || !invoice) return

  const { data: items } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('invoice_id', invoiceId)

  const subtotal = (items || []).reduce(
    (sum, item) => sum + Number(item.quantity) * Number(item.recipient_price_bdt),
    0,
  )

  const deliveryCharge = Number(invoice.delivery_charge) || 0
  const wrappingCharge = Number(invoice.wrapping_charge) || 0
  const cod = Number(invoice.cod) || 0
  const { data: orderRow } = await supabase
    .from('commerce_orders')
    .select('is_delivery_charge_inclusive')
    .eq('id', invoice.order_id)
    .maybeSingle()
  const isDeliveryInclusive = Boolean(orderRow?.is_delivery_charge_inclusive)
  const deliveryChargeForTotal = isDeliveryInclusive ? 0 : deliveryCharge

  const discountAmount = Number(invoice.discount_amount) || 0
  const totalAmount = Math.max(0, round2(subtotal + deliveryChargeForTotal - discountAmount))
  const amountDue = Math.max(0, round2(totalAmount - Number(invoice.amount_paid || 0)))
  const isPaid = Number(invoice.amount_paid || 0) >= totalAmount

  await supabase
    .from('commerce_invoices')
    .update({
      total_amount: totalAmount,
      amount_due: amountDue,
      is_customer_group_paid: isPaid,
    })
    .eq('id', invoiceId)

  await supabase
    .from('commerce_orders')
    .update({
      delivery_charge: deliveryCharge,
      wrapping_charge: wrappingCharge,
      cod,
      shipment_payment: totalAmount,
    })
    .eq('id', invoice.order_id)
}

const maintainAccountingEntry = async (
  item: CommerceOrderItemRow,
  customerGroupId: number,
  tenantId: number,
  isPaid: boolean,
) => {
  const payload = {
    order_item_id: item.id,
    cost_bdt: Number(item.cost_bdt || 0),
    inventory_item_id: item.inventory_item_id,
    shipment_item_id: item.shipment_item_id,
    sell_price_bdt: Number(item.sell_price_bdt || 0),
    recipient_sell_price_bdt: Number(item.recipient_price_bdt || 0),
    customer_group_id: customerGroupId,
    is_customer_group_paid: isPaid,
    tenant_id: tenantId,
  }

  const { error } = await supabase
    .from('commerce_accounting')
    .upsert(payload, { onConflict: 'order_item_id' })

  if (error) {
    throw error
  }
}

const deleteAccountingEntry = async (orderItemId: number) => {
  await supabase.from('commerce_accounting').delete().eq('order_item_id', orderItemId)
}

const listCommerceInvoices = async (tenantId: number): Promise<CommerceInvoice[]> => {
  const { data, error } = await supabase
    .from('commerce_invoices')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: false })

  if (error) throw error
  return data || []
}

const updateInvoicePayment = async (
  invoiceId: number,
  amountPaid: number,
): Promise<CommerceInvoice> => {
  const { data: invoice, error: getError } = await supabase
    .from('commerce_invoices')
    .select('*')
    .eq('id', invoiceId)
    .single()

  if (getError) throw getError

  const newAmountPaid = Number(invoice.amount_paid) + amountPaid
  const newAmountDue = Math.max(0, Number(invoice.total_amount) - newAmountPaid)
  const isPaid = newAmountPaid >= Number(invoice.total_amount)

  const { data, error } = await supabase
    .from('commerce_invoices')
    .update({
      amount_paid: newAmountPaid,
      amount_due: newAmountDue,
      is_customer_group_paid: isPaid,
    })
    .eq('id', invoiceId)
    .select('*')
    .single()

  if (error) throw error

  const { data: orderItems } = await supabase
    .from('commerce_order_items')
    .select('id')
    .eq('invoice_id', invoiceId)

  const ids = (orderItems || []).map((item) => item.id)
  if (ids.length > 0) {
    await supabase
      .from('commerce_accounting')
      .update({ is_customer_group_paid: isPaid })
      .in('order_item_id', ids)
  }

  return data
}

const getCommerceInvoiceDetails = async (invoiceId: number) => {
  const { data: invoice, error: invoiceError } = await supabase
    .from('commerce_invoices')
    .select('*, commerce_orders(*)')
    .eq('id', invoiceId)
    .maybeSingle()

  if (invoiceError) throw invoiceError
  if (!invoice) throw new Error('Commerce Invoice not found.')

  const { data: items, error: itemsError } = await supabase
    .from('commerce_order_items')
    .select('*, products(*)')
    .eq('invoice_id', invoiceId)

  if (itemsError) throw itemsError

  const itemRows = (items || []) as Array<CommerceInvoiceDetails['items'][number]>
  const inventoryItemIds = Array.from(
    new Set(
      itemRows
        .map((item) => Number(item.inventory_item_id || 0))
        .filter((id) => id > 0),
    ),
  )

  const inventoryItemsById = new Map<
    number,
    { name?: string | null; cost?: number | null; product_code?: string | null; barcode?: string | null; source_type?: string | null; source_id?: number | null }
  >()

  if (inventoryItemIds.length > 0) {
    const { data: inventoryItems, error: inventoryItemsError } = await supabase
      .from('inventory_items')
      .select('id, name, cost, product_code, barcode, source_type, source_id')
      .in('id', inventoryItemIds)

    if (inventoryItemsError) throw inventoryItemsError

    for (const inventoryItem of inventoryItems || []) {
      inventoryItemsById.set(inventoryItem.id, {
        name: inventoryItem.name,
        cost: inventoryItem.cost,
        product_code: inventoryItem.product_code,
        barcode: inventoryItem.barcode,
        source_type: inventoryItem.source_type,
        source_id: inventoryItem.source_id,
      })
    }
  }

  return {
    invoice,
    order: invoice.commerce_orders,
    items: itemRows.map((item) => ({
      ...item,
      inventory_items: item.inventory_item_id ? inventoryItemsById.get(item.inventory_item_id) ?? null : null,
    })),
  }
}

const createManualInvoice = async (payload: {
  tenant_id: number
  customer_group_id: number
  recipient_name: string
  recipient_phone: string
  shipping_address: string
  delivery_charge: number
  wrapping_charge: number
  cod: number
}) => {
  const { data: order, error: orderErr } = await supabase
    .from('commerce_orders')
    .insert([
      {
        tenant_id: payload.tenant_id,
        customer_group_id: payload.customer_group_id,
        recipient_name: payload.recipient_name,
        recipient_phone: payload.recipient_phone,
        shipping_address: payload.shipping_address,
        delivery_charge: payload.delivery_charge,
        wrapping_charge: payload.wrapping_charge,
        cod: payload.cod,
        shipment_payment: payload.delivery_charge,
        is_delivery_charge_inclusive: false,
        status: 'reviewing',
      },
    ])
    .select()
    .single()

  if (orderErr || !order) throw orderErr || new Error('Failed to create commerce order.')

  const { data: invoice, error: invoiceErr } = await supabase
    .from('commerce_invoices')
    .insert([
      {
        order_id: order.id,
        tenant_id: payload.tenant_id,
        delivery_charge: payload.delivery_charge,
        wrapping_charge: payload.wrapping_charge,
        cod: payload.cod,
        total_amount: order.shipment_payment,
        amount_paid: 0,
        amount_due: order.shipment_payment,
        is_customer_group_paid: false,
      },
    ])
    .select()
    .single()

  if (invoiceErr || !invoice) throw invoiceErr || new Error('Failed to create commerce invoice.')

  await supabase
    .from('commerce_orders')
    .update({
      invoice_ids: [invoice.id],
    })
    .eq('id', order.id)

  return invoice
}

const addCommerceInvoiceItem = async (
  invoiceId: number,
  orderId: number,
  item: {
    product_id: number
    quantity: number
    cost_bdt: number
    sell_price_bdt: number
    recipient_price_bdt: number
    image_url?: string | null
    inventory_item_id?: number | null
  },
) => {
  const order = await getCommerceOrderContext(orderId)

  const quantity = Math.max(1, Math.floor(Number(item.quantity || 1)))

  let resolvedCost = Number(item.cost_bdt || 0)
  const resolvedInventoryItemId: number | null = item.inventory_item_id ?? null
  let resolvedShipmentItemId: number | null = null
  let resolvedTenantId = Number(order.tenant_id)

  if (resolvedInventoryItemId) {
    const { inventoryItem } = await adjustInventoryStock({
      inventoryItemId: resolvedInventoryItemId,
      delta: -quantity,
      note: `Assigned to commerce invoice #${invoiceId}`,
    })
    resolvedCost = Number(inventoryItem.cost || 0)
    resolvedShipmentItemId =
      inventoryItem.source_type === 'shipment' ? Number(inventoryItem.source_id || 0) || null : null
    resolvedTenantId = inventoryItem.tenant_id
  }

  let existingQuery = supabase
    .from('commerce_order_items')
    .select('*')
    .eq('order_id', orderId)
    .eq('product_id', item.product_id)
    .eq('invoice_id', invoiceId)

  if (resolvedInventoryItemId) {
    existingQuery = existingQuery.eq('inventory_item_id', resolvedInventoryItemId)
  } else {
    existingQuery = existingQuery.is('inventory_item_id', null)
  }

  const { data: existingItem } = await existingQuery.maybeSingle()

  let orderItem: CommerceOrderItemRow
  if (existingItem) {
    const { data: updated, error: updateError } = await supabase
      .from('commerce_order_items')
      .update({
        quantity: Number(existingItem.quantity) + quantity,
        cost_bdt: resolvedCost,
        sell_price_bdt: item.sell_price_bdt,
        recipient_price_bdt: item.recipient_price_bdt,
        inventory_item_id: resolvedInventoryItemId,
        shipment_item_id: resolvedShipmentItemId,
      })
      .eq('id', existingItem.id)
      .select('*')
      .single()

    if (updateError || !updated) {
      throw updateError || new Error('Failed to update order item.')
    }
    orderItem = updated as CommerceOrderItemRow
  } else {
    const { data: inserted, error: insertError } = await supabase
      .from('commerce_order_items')
      .insert([
        {
          order_id: orderId,
          invoice_id: invoiceId,
          product_id: item.product_id,
          quantity,
          cost_bdt: resolvedCost,
          sell_price_bdt: item.sell_price_bdt,
          recipient_price_bdt: item.recipient_price_bdt,
          image_url: item.image_url || null,
          inventory_item_id: resolvedInventoryItemId,
          shipment_item_id: resolvedShipmentItemId,
        },
      ])
      .select('*')
      .single()

    if (insertError || !inserted) {
      throw insertError || new Error('Failed to create order item.')
    }
    orderItem = inserted as CommerceOrderItemRow
  }

  const { data: invoice } = await supabase
    .from('commerce_invoices')
    .select('is_customer_group_paid')
    .eq('id', invoiceId)
    .single()

  await maintainAccountingEntry(
    orderItem,
    Number(order.customer_group_id || 0),
    resolvedTenantId,
    Boolean(invoice?.is_customer_group_paid),
  )

  await syncInvoiceTotals(invoiceId)
}

const updateOrderItemInventoryAssignment = async (
  invoiceId: number,
  orderItemId: number,
  inventoryItemId: number,
) => {
  const { data: invoice, error: invoiceError } = await supabase
    .from('commerce_invoices')
    .select('id, order_id, tenant_id, is_customer_group_paid')
    .eq('id', invoiceId)
    .single()

  if (invoiceError || !invoice) {
    throw invoiceError || new Error('Invoice not found.')
  }

  const order = await getCommerceOrderContext(Number(invoice.order_id))

  const { data: rawOrderItem, error: orderItemError } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)
    .eq('order_id', invoice.order_id)
    .single()

  if (orderItemError || !rawOrderItem) {
    throw orderItemError || new Error('Order item not found.')
  }

  const orderItem = rawOrderItem as CommerceOrderItemRow
  const quantity = Math.max(0, Number(orderItem.quantity || 0))
  const previousInventoryItemId = orderItem.inventory_item_id

  let resolvedTenantId = Number(order.tenant_id)

  if (previousInventoryItemId && previousInventoryItemId !== inventoryItemId && quantity > 0) {
    await adjustInventoryStock({
      inventoryItemId: previousInventoryItemId,
      delta: quantity,
      note: `Reassigned from commerce invoice #${invoiceId} order item #${orderItemId}`,
    })
  }

  let nextCostBdt = Number(orderItem.cost_bdt || 0)
  let nextShipmentItemId: number | null = null

  if (!previousInventoryItemId || previousInventoryItemId !== inventoryItemId || nextCostBdt <= 0) {
    const { inventoryItem } = await adjustInventoryStock({
      inventoryItemId,
      delta: previousInventoryItemId === inventoryItemId ? 0 : -quantity,
      note: `Assigned to commerce invoice #${invoiceId} order item #${orderItemId}`,
    })

    nextCostBdt = Number(inventoryItem.cost || 0)
    nextShipmentItemId =
      inventoryItem.source_type === 'shipment' ? Number(inventoryItem.source_id || 0) || null : null
    resolvedTenantId = inventoryItem.tenant_id
  } else {
    // If inventory item hasn't changed, retrieve its tenant_id from inventory_items
    const { data: inventoryItem } = await supabase
      .from('inventory_items')
      .select('tenant_id')
      .eq('id', inventoryItemId)
      .single()
    if (inventoryItem) {
      resolvedTenantId = inventoryItem.tenant_id
    }
  }

  const { data: updatedOrderItem, error: updateError } = await supabase
    .from('commerce_order_items')
    .update({
      inventory_item_id: inventoryItemId,
      shipment_item_id: nextShipmentItemId,
      cost_bdt: nextCostBdt,
    })
    .eq('id', orderItemId)
    .select('*')
    .single()

  if (updateError || !updatedOrderItem) {
    throw updateError || new Error('Failed to update order item inventory assignment.')
  }

  await maintainAccountingEntry(
    updatedOrderItem as CommerceOrderItemRow,
    Number(order.customer_group_id || 0),
    resolvedTenantId,
    Boolean(invoice.is_customer_group_paid),
  )

  await syncInvoiceTotals(invoiceId)

  return updatedOrderItem
}

const unassignOrderItemInventory = async (
  invoiceId: number,
  orderItemId: number,
) => {
  const { data: invoice, error: invoiceError } = await supabase
    .from('commerce_invoices')
    .select('id, order_id, tenant_id, is_customer_group_paid')
    .eq('id', invoiceId)
    .single()

  if (invoiceError || !invoice) {
    throw invoiceError || new Error('Invoice not found.')
  }

  const order = await getCommerceOrderContext(Number(invoice.order_id))

  const { data: rawOrderItem, error: orderItemError } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)
    .eq('order_id', invoice.order_id)
    .single()

  if (orderItemError || !rawOrderItem) {
    throw orderItemError || new Error('Order item not found.')
  }

  const orderItem = rawOrderItem as CommerceOrderItemRow
  const quantity = Math.max(0, Number(orderItem.quantity || 0))
  const previousInventoryItemId = orderItem.inventory_item_id

  if (previousInventoryItemId && quantity > 0) {
    await adjustInventoryStock({
      inventoryItemId: previousInventoryItemId,
      delta: quantity,
      note: `Unassigned from commerce invoice #${invoiceId} order item #${orderItemId}`,
    })
  }

  const { data: updatedOrderItem, error: updateError } = await supabase
    .from('commerce_order_items')
    .update({
      inventory_item_id: null,
      shipment_item_id: null,
      cost_bdt: orderItem.cost_bdt,
    })
    .eq('id', orderItemId)
    .select('*')
    .single()

  if (updateError || !updatedOrderItem) {
    throw updateError || new Error('Failed to unassign order item inventory.')
  }

  await maintainAccountingEntry(
    updatedOrderItem as CommerceOrderItemRow,
    Number(order.customer_group_id || 0),
    Number(order.tenant_id),
    Boolean(invoice.is_customer_group_paid),
  )

  await syncInvoiceTotals(invoiceId)

  return updatedOrderItem
}

const removeCommerceInvoiceItem = async (orderItemId: number, invoiceId: number) => {
  const { data: row, error: rowError } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)
    .single()

  if (rowError || !row) {
    throw rowError || new Error('Order item not found.')
  }

  const quantity = Math.max(0, Number(row.quantity || 0))
  if (row.inventory_item_id && quantity > 0) {
    await adjustInventoryStock({
      inventoryItemId: Number(row.inventory_item_id),
      delta: quantity,
      note: `Unassigned from commerce invoice #${invoiceId}`,
    })
  }

  await supabase
    .from('commerce_order_items')
    .update({
      invoice_id: null,
      inventory_item_id: null,
      shipment_item_id: null,
    })
    .eq('id', orderItemId)

  await deleteAccountingEntry(orderItemId)
  await syncInvoiceTotals(invoiceId)
}

const updateCommerceInvoiceCharges = async (
  invoiceId: number,
  charges: {
    delivery_charge: number
    wrapping_charge: number
    cod: number
    delivered_by?: string
    amount_paid?: number
    discount_amount?: number
  },
) => {
  await supabase.from('commerce_invoices').update(charges).eq('id', invoiceId)

  await syncInvoiceTotals(invoiceId)
}

const deleteCommerceInvoice = async (invoiceId: number) => {
  const { data: invoice, error: invoiceError } = await supabase
    .from('commerce_invoices')
    .select('id, order_id, tenant_id')
    .eq('id', invoiceId)
    .single()

  if (invoiceError || !invoice) {
    throw invoiceError || new Error('Invoice not found.')
  }

  const order = await getCommerceOrderContext(Number(invoice.order_id))

  const { data: orderItems, error: orderItemsError } = await supabase
    .from('commerce_order_items')
    .select('id, quantity, inventory_item_id')
    .eq('invoice_id', invoiceId)

  if (orderItemsError) throw orderItemsError

  for (const orderItem of orderItems || []) {
    if (orderItem.inventory_item_id) {
      await adjustInventoryStock({
        inventoryItemId: Number(orderItem.inventory_item_id),
        delta: Number(orderItem.quantity || 0),
        note: `Restocked after deleting commerce invoice #${invoiceId}`,
      })
    }
  }

  const orderItemIds = (orderItems || []).map((item) => item.id)
  if (orderItemIds.length > 0) {
    await supabase.from('commerce_accounting').delete().in('order_item_id', orderItemIds)
  }

  await supabase
    .from('commerce_order_items')
    .update({
      invoice_id: null,
    })
    .eq('invoice_id', invoiceId)

  await supabase.from('commerce_invoices').delete().eq('id', invoiceId)

  const nextInvoiceIds = (order.invoice_ids || []).filter(
    (linkedInvoiceId) => Number(linkedInvoiceId) !== Number(invoiceId),
  )

  await supabase
    .from('commerce_orders')
    .update({
      invoice_ids: nextInvoiceIds,
    })
    .eq('id', order.id)
}

const updateCommerceInvoiceStatus = async (
  invoiceId: number,
  status: 'draft' | 'ready' | 'handed_to_customer',
): Promise<CommerceInvoice> => {
  const { data, error } = await supabase
    .from('commerce_invoices')
    .update({ status })
    .eq('id', invoiceId)
    .select('*')
    .single()

  if (error) throw error
  return data
}

export const commerceInvoiceRepository = {
  listCommerceInvoices,
  updateInvoicePayment,
  getCommerceInvoiceDetails,
  createManualInvoice,
  addCommerceInvoiceItem,
  updateOrderItemInventoryAssignment,
  unassignOrderItemInventory,
  removeCommerceInvoiceItem,
  updateCommerceInvoiceCharges,
  deleteCommerceInvoice,
  updateCommerceInvoiceStatus,
}
