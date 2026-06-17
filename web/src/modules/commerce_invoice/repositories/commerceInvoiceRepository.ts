import { supabase } from 'src/boot/supabase'
import type { CommerceInvoice, CommerceInvoiceDetails, CommerceInvoiceBox, CreateCommerceInvoiceBoxInput, InvoiceBrand } from '../types'





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
      .from('inventory_accounting_entries')
      .update({ status: isPaid ? 'paid' : 'due' })
      .in('commerce_order_item_id', ids)
      .eq('type', 'commerce')
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
  const { error } = await supabase.rpc('update_commerce_invoice_item_transactional', {
    p_invoice_id: invoiceId,
    p_order_item_id: orderItemId,
    p_quantity: payload.quantity,
    p_sell_price_bdt: payload.sell_price_bdt,
    p_recipient_price_bdt: payload.recipient_price_bdt,
    p_unit: payload.unit || 'pcs',
  })

  if (error) {
    throw error
  }
}

const updateOrderItemInventoryAssignment = async (
  invoiceId: number,
  orderItemId: number,
  inventoryItemId: number,
) => {
  const { error } = await supabase.rpc('assign_commerce_order_item_inventory_transactional', {
    p_invoice_id: invoiceId,
    p_order_item_id: orderItemId,
    p_inventory_item_id: inventoryItemId,
  })

  if (error) {
    throw error
  }

  return {}
}

const unassignOrderItemInventory = async (
  invoiceId: number,
  orderItemId: number,
) => {
  const { error } = await supabase.rpc('unassign_commerce_order_item_inventory_transactional', {
    p_invoice_id: invoiceId,
    p_order_item_id: orderItemId,
  })

  if (error) {
    throw error
  }

  return {}
}

const removeCommerceInvoiceItem = async (orderItemId: number, invoiceId: number) => {
  const { error } = await supabase.rpc('remove_commerce_invoice_item_transactional', {
    p_invoice_id: invoiceId,
    p_order_item_id: orderItemId,
  })

  if (error) {
    throw error
  }
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
    note?: string | null
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
    p_note: charges.note,
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
  const { error } = await supabase.rpc('delete_commerce_invoice_transactional', {
    p_invoice_id: invoiceId,
  })

  if (error) {
    throw error
  }
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
