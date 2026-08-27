export interface InvoiceLineDraftItem {
  id?: number;
  global_stock_id: number;
  shipment_item_id: number;
  product_id: number | null;
  name: string;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  quantity: number;
  available_atp: number;
  unit_cost_price: number;
  sell_price_amount: number;
  return_quantity: number;
  line_discount_amount: number;
  shipment_id: number;
  shipment_name: string;
  holding_tenant_id: number;
  holding_tenant_name: string;
  is_allocated_to_tenant: boolean;
}
