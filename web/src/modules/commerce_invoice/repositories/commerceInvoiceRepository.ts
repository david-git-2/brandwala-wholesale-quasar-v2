import { supabase } from 'src/boot/supabase'
import type { CommerceInvoice, CommerceInvoiceDetails, CommerceInvoiceBox, CreateCommerceInvoiceBoxInput, InvoiceBrand } from '../types'

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
  unit: string
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
  const printCharge = Number(invoice.print_charge) || 0
  
  let isDeliveryInclusive = false
  if (invoice.order_id) {
    const { data: orderRow } = await supabase
      .from('commerce_orders')
      .select('is_delivery_charge_inclusive')
      .eq('id', invoice.order_id)
      .maybeSingle()
    isDeliveryInclusive = Boolean(orderRow?.is_delivery_charge_inclusive)
  }
  const deliveryChargeForTotal = isDeliveryInclusive ? 0 : deliveryCharge

  const discountAmount = Number(invoice.discount_amount) || 0
  const totalAmount = Math.max(0, round2(subtotal + deliveryChargeForTotal + wrappingCharge + cod + printCharge - discountAmount))
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

  if (invoice.order_id) {
    await supabase
      .from('commerce_orders')
      .update({
        delivery_charge: deliveryCharge,
        wrapping_charge: wrappingCharge,
        cod,
        invoice_print_charge: printCharge,
        shipment_payment: totalAmount,
      })
      .eq('id', invoice.order_id)
  }
}

const maintainAccountingEntry = async (
  item: CommerceOrderItemRow,
  customerGroupId: number,
  tenantId: number,
  isPaid: boolean,
  billingProfileId?: number | null,
) => {
  const payload = {
    order_item_id: item.id,
    cost_bdt: Number(item.cost_bdt || 0),
    inventory_item_id: item.inventory_item_id,
    shipment_item_id: item.shipment_item_id,
    sell_price_bdt: Number(item.sell_price_bdt || 0),
    recipient_sell_price_bdt: Number(item.recipient_price_bdt || 0),
    customer_group_id: customerGroupId,
    billing_profile_id: billingProfileId || null,
    is_customer_group_paid: isPaid,
    tenant_id: tenantId,
  }

  // Check if entry already exists to avoid ON CONFLICT on the view
  const { data: existing, error: findError } = await supabase
    .from('commerce_accounting')
    .select('id')
    .eq('order_item_id', item.id)
    .maybeSingle()

  if (findError) {
    throw findError
  }

  if (existing) {
    const { error } = await supabase
      .from('commerce_accounting')
      .update(payload)
      .eq('id', existing.id)
    if (error) throw error
  } else {
    const { error } = await supabase
      .from('commerce_accounting')
      .insert(payload)
    if (error) throw error
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
    .select('*, commerce_orders(*), billing_profiles(*)')
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
    {
      name?: string | null
      cost?: number | null
      product_code?: string | null
      barcode?: string | null
      source_type?: string | null
      source_id?: number | null
      shipment_name?: string | null
      tenant_shipment_id?: number | null
      tenant_name?: string | null
    }
  >()

  if (inventoryItemIds.length > 0) {
    const { data: inventoryItems, error: inventoryItemsError } = await supabase
      .from('inventory_items')
      .select('id, name, cost, product_code, barcode, source_type, source_id')
      .in('id', inventoryItemIds)

    if (inventoryItemsError) throw inventoryItemsError

    const shipmentItemIds = Array.from(
      new Set(
        (inventoryItems || [])
          .filter((item) => item.source_type === 'shipment' && item.source_id)
          .map((item) => Number(item.source_id)),
      ),
    )

    const shipmentItemToShipmentId = new Map<number, number>()
    const shipmentIds: number[] = []

    if (shipmentItemIds.length > 0) {
      const { data: shipmentItemsData, error: shipmentItemsError } = await supabase
        .from('shipment_items')
        .select('id, shipment_id')
        .in('id', shipmentItemIds)
      if (!shipmentItemsError && shipmentItemsData) {
        for (const si of shipmentItemsData) {
          if (si.shipment_id) {
            shipmentItemToShipmentId.set(si.id, si.shipment_id)
            shipmentIds.push(si.shipment_id)
          }
        }
      }
    }

    const shipmentsById = new Map<number, { name: string; tenant_shipment_id: number | null; tenant_name?: string | null }>()
    if (shipmentIds.length > 0) {
      const { data: shipmentsData, error: shipmentsError } = await supabase
        .from('shipments')
        .select('id, name, tenant_shipment_id, tenants(name)')
        .in('id', Array.from(new Set(shipmentIds)))
      if (!shipmentsError && shipmentsData) {
        for (const sh of shipmentsData) {
          const tenantObj = sh.tenants as unknown as { name: string } | null
          shipmentsById.set(sh.id, {
            name: sh.name,
            tenant_shipment_id: sh.tenant_shipment_id,
            tenant_name: tenantObj?.name ?? null,
          })
        }
      }
    }

    for (const inventoryItem of inventoryItems || []) {
      const shipmentId = inventoryItem.source_type === 'shipment' && inventoryItem.source_id
        ? shipmentItemToShipmentId.get(Number(inventoryItem.source_id)) ?? null
        : null
      const shipmentInfo = shipmentId
        ? shipmentsById.get(shipmentId) ?? null
        : null

      inventoryItemsById.set(inventoryItem.id, {
        name: inventoryItem.name,
        cost: inventoryItem.cost,
        product_code: inventoryItem.product_code,
        barcode: inventoryItem.barcode,
        source_type: inventoryItem.source_type,
        source_id: inventoryItem.source_id,
        shipment_name: shipmentInfo?.name ?? null,
        tenant_shipment_id: shipmentInfo?.tenant_shipment_id ?? null,
        tenant_name: shipmentInfo?.tenant_name ?? null,
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
  billing_profile_id: number
  invoice_type?: 'retail' | 'wholesale'
  recipient_name: string
  recipient_phone: string | null
  shipping_address: string | null
  delivery_charge: number
  wrapping_charge: number
  cod: number
  print_charge?: number
  invoice_date?: string
}) => {
  const printCharge = payload.print_charge || 0
  const baseTotal = payload.delivery_charge + payload.wrapping_charge + payload.cod + printCharge

  const { data: invoice, error: invoiceErr } = await supabase
    .from('commerce_invoices')
    .insert([
      {
        order_id: null,
        tenant_id: payload.tenant_id,
        delivery_charge: payload.delivery_charge,
        wrapping_charge: payload.wrapping_charge,
        cod: payload.cod,
        print_charge: printCharge,
        total_amount: baseTotal,
        amount_paid: 0,
        amount_due: baseTotal,
        is_customer_group_paid: false,
        billing_profile_id: payload.billing_profile_id,
        invoice_type: payload.invoice_type || 'retail',
        invoice_date: payload.invoice_date,
        recipient_name: payload.recipient_name,
        recipient_phone: payload.recipient_phone,
        shipping_address: payload.shipping_address,
      },
    ])
    .select()
    .single()

  if (invoiceErr || !invoice) throw invoiceErr || new Error('Failed to create commerce invoice.')

  return invoice
}

const addCommerceInvoiceItem = async (
  invoiceId: number,
  orderId: number | null,
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
  const { error } = await supabase.rpc('add_commerce_invoice_item', {
    p_invoice_id: invoiceId,
    p_order_id: orderId,
    p_product_id: item.product_id,
    p_quantity: Math.max(1, Math.floor(Number(item.quantity || 1))),
    p_cost_bdt: Number(item.cost_bdt || 0),
    p_sell_price_bdt: item.sell_price_bdt,
    p_recipient_price_bdt: item.recipient_price_bdt,
    p_image_url: item.image_url || null,
    p_inventory_item_id: item.inventory_item_id ?? null,
  })

  if (error) {
    throw error
  }
}


const updateCommerceInvoiceItem = async (
  invoiceId: number,
  orderItemId: number,
  payload: {
    quantity: number
    sell_price_bdt: number
    recipient_price_bdt: number
    unit?: string
  },
) => {
  const { data: item, error: itemError } = await supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)
    .single()

  if (itemError || !item) {
    throw itemError || new Error('Order item not found.')
  }

  const orderItem = item as CommerceOrderItemRow
  const quantity = Math.max(1, Math.floor(Number(payload.quantity || 1)))
  const qtyDelta = quantity - Number(orderItem.quantity)

  let resolvedTenantId = 0

  if (qtyDelta !== 0 && orderItem.inventory_item_id) {
    const { inventoryItem } = await adjustInventoryStock({
      inventoryItemId: Number(orderItem.inventory_item_id),
      delta: -qtyDelta,
      note: `Adjusted quantity from ${orderItem.quantity} to ${quantity} on commerce invoice #${invoiceId}`,
    })
    resolvedTenantId = inventoryItem.tenant_id
  } else if (orderItem.inventory_item_id) {
    const { data: inventoryItem } = await supabase
      .from('inventory_items')
      .select('tenant_id')
      .eq('id', orderItem.inventory_item_id)
      .single()
    if (inventoryItem) {
      resolvedTenantId = inventoryItem.tenant_id
    }
  }

  const { data: updated, error: updateError } = await supabase
    .from('commerce_order_items')
    .update({
      quantity,
      sell_price_bdt: payload.sell_price_bdt,
      recipient_price_bdt: payload.recipient_price_bdt,
      unit: payload.unit || orderItem.unit || 'pcs',
    })
    .eq('id', orderItemId)
    .select('*')
    .single()

  if (updateError || !updated) {
    throw updateError || new Error('Failed to update order item.')
  }

  const { data: invoice } = await supabase
    .from('commerce_invoices')
    .select('is_customer_group_paid, billing_profile_id, order_id, tenant_id')
    .eq('id', invoiceId)
    .single()

  let customerGroupId = 0
  let tenantId = resolvedTenantId || Number(invoice?.tenant_id || 0)

  if (invoice?.order_id) {
    const order = await getCommerceOrderContext(Number(invoice.order_id))
    customerGroupId = Number(order.customer_group_id || 0)
    if (!resolvedTenantId) {
      tenantId = Number(order.tenant_id)
    }
  } else if (invoice?.billing_profile_id) {
    const { data: bp } = await supabase
      .from('billing_profiles')
      .select('customer_group_id')
      .eq('id', invoice.billing_profile_id)
      .single()
    customerGroupId = Number(bp?.customer_group_id || 0)
  }

  await maintainAccountingEntry(
    updated as CommerceOrderItemRow,
    customerGroupId,
    tenantId,
    Boolean(invoice?.is_customer_group_paid),
    invoice?.billing_profile_id,
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
    .select('id, order_id, tenant_id, is_customer_group_paid, billing_profile_id')
    .eq('id', invoiceId)
    .single()

  if (invoiceError || !invoice) {
    throw invoiceError || new Error('Invoice not found.')
  }

  let customerGroupId = 0
  let tenantId = Number(invoice.tenant_id || 0)

  if (invoice.order_id) {
    const order = await getCommerceOrderContext(Number(invoice.order_id))
    customerGroupId = Number(order.customer_group_id || 0)
    tenantId = Number(order.tenant_id || tenantId)
  } else if (invoice.billing_profile_id) {
    const { data: bp } = await supabase
      .from('billing_profiles')
      .select('customer_group_id')
      .eq('id', invoice.billing_profile_id)
      .single()
    customerGroupId = Number(bp?.customer_group_id || 0)
  }

  const query = supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)

  if (invoice.order_id) {
    void query.eq('order_id', invoice.order_id)
  } else {
    void query.eq('invoice_id', invoiceId)
  }

  const { data: rawOrderItem, error: orderItemError } = await query.single()

  if (orderItemError || !rawOrderItem) {
    throw orderItemError || new Error('Order item not found.')
  }

  const orderItem = rawOrderItem as CommerceOrderItemRow
  const quantity = Math.max(0, Number(orderItem.quantity || 0))
  const previousInventoryItemId = orderItem.inventory_item_id

  let resolvedTenantId = tenantId

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
    customerGroupId,
    resolvedTenantId,
    Boolean(invoice.is_customer_group_paid),
    invoice.billing_profile_id,
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
    .select('id, order_id, tenant_id, is_customer_group_paid, billing_profile_id')
    .eq('id', invoiceId)
    .single()

  if (invoiceError || !invoice) {
    throw invoiceError || new Error('Invoice not found.')
  }

  let customerGroupId = 0
  let tenantId = Number(invoice.tenant_id || 0)

  if (invoice.order_id) {
    const order = await getCommerceOrderContext(Number(invoice.order_id))
    customerGroupId = Number(order.customer_group_id || 0)
    tenantId = Number(order.tenant_id || tenantId)
  } else if (invoice.billing_profile_id) {
    const { data: bp } = await supabase
      .from('billing_profiles')
      .select('customer_group_id')
      .eq('id', invoice.billing_profile_id)
      .single()
    customerGroupId = Number(bp?.customer_group_id || 0)
  }

  const query = supabase
    .from('commerce_order_items')
    .select('*')
    .eq('id', orderItemId)

  if (invoice.order_id) {
    void query.eq('order_id', invoice.order_id)
  } else {
    void query.eq('invoice_id', invoiceId)
  }

  const { data: rawOrderItem, error: orderItemError } = await query.single()

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
    customerGroupId,
    tenantId,
    Boolean(invoice.is_customer_group_paid),
    invoice.billing_profile_id,
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
    delivery_charge?: number
    wrapping_charge?: number
    cod?: number
    print_charge?: number
    delivered_by?: string | null
    amount_paid?: number
    discount_amount?: number
    invoice_date?: string
    brand_name?: string | null
    brand_address?: string | null
    total_boxes?: number | null
    advance_amount?: number
    previous_due?: number
    thank_you_message?: string | null
    client_name?: string | null
    client_tr?: string | null
    status?: string
  },
): Promise<{ invoice: CommerceInvoice; order: CommerceInvoiceDetails['order'] }> => {
  const { data, error } = await supabase.rpc('update_commerce_invoice_charges', {
    p_invoice_id: invoiceId,
    p_delivery_charge: charges.delivery_charge,
    p_wrapping_charge: charges.wrapping_charge,
    p_cod: charges.cod,
    p_print_charge: charges.print_charge,
    p_amount_paid: charges.amount_paid,
    p_discount_amount: charges.discount_amount,
    p_invoice_date: charges.invoice_date || null,
    p_delivered_by: charges.delivered_by,
    p_brand_name: charges.brand_name,
    p_brand_address: charges.brand_address,
    p_total_boxes: charges.total_boxes,
    p_advance_amount: charges.advance_amount,
    p_previous_due: charges.previous_due,
    p_thank_you_message: charges.thank_you_message,
    p_client_name: charges.client_name,
    p_client_tr: charges.client_tr,
    p_status: charges.status,
  })

  if (error) {
    throw error
  }

  const result = data as { invoice: CommerceInvoice; order: CommerceInvoiceDetails['order'] }
  return {
    invoice: result.invoice,
    order: result.order,
  }
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
  status: string,
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

const listCommerceInvoiceBrands = async (payload: { tenant_id?: number } = {}): Promise<(InvoiceBrand & { tenants?: { name: string } })[]> => {
  let query = supabase.from('invoice_brands').select('*, tenants(name)')
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  const { data, error } = await query.order('name', { ascending: true })
  if (error) throw error
  return (data as unknown as (InvoiceBrand & { tenants?: { name: string } })[]) || []
}

const listCommerceInvoiceBoxes = async (payload: { invoice_id: number; tenant_id?: number }): Promise<CommerceInvoiceBox[]> => {
  let query = supabase.from('commerce_invoice_boxes').select('*').eq('invoice_id', payload.invoice_id)
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }
  const { data, error } = await query.order('box_number', { ascending: true })
  if (error) throw error
  return (data as CommerceInvoiceBox[]) || []
}

const createCommerceInvoiceBox = async (payload: CreateCommerceInvoiceBoxInput): Promise<CommerceInvoiceBox> => {
  const { data, error } = await supabase.from('commerce_invoice_boxes').insert([payload]).select('*').single()
  if (error) throw error
  return data as CommerceInvoiceBox
}

const deleteCommerceInvoiceBox = async (payload: { id: number }): Promise<void> => {
  const { error } = await supabase.from('commerce_invoice_boxes').delete().eq('id', payload.id)
  if (error) throw error
}

export const commerceInvoiceRepository = {
  listCommerceInvoices,
  updateInvoicePayment,
  getCommerceInvoiceDetails,
  createManualInvoice,
  addCommerceInvoiceItem,
  updateCommerceInvoiceItem,
  updateOrderItemInventoryAssignment,
  unassignOrderItemInventory,
  removeCommerceInvoiceItem,
  updateCommerceInvoiceCharges,
  deleteCommerceInvoice,
  updateCommerceInvoiceStatus,
  listCommerceInvoiceBrands,
  listCommerceInvoiceBoxes,
  createCommerceInvoiceBox,
  deleteCommerceInvoiceBox,
}
