export interface StaffOrderCurrency {
  id: number;
  code: string;
  symbol: string;
}

export interface StaffOrderMoney {
  amount: number | null;
  currency: StaffOrderCurrency | null;
}

export interface StaffOrderOffer extends StaffOrderMoney {
  at?: string | null;
  is_manual?: boolean | null;
}

export interface StaffShopOrderDetailOrder {
  id: number;
  tenant_id: number;
  order_no: string;
  name: string;
  cart_id: number | null;
  created_by_email: string;
  created_at: string;
  updated_at: string;
  placed_at: string | null;
  fulfilled_at: string | null;
  global_invoice_id: number | null;
  collection_source: string | null;
  shop: {
    id: number;
    name: string | null;
    type: string;
    order_mode: string;
    is_negotiable: boolean;
    sell_currency: StaffOrderCurrency | null;
    buy_currency: StaffOrderCurrency | null;
  };
  customer: {
    group_id: number;
    group_name: string | null;
  };
  status: {
    value: string;
    negotiate_round: number;
  };
  rates: {
    cargo: number | null;
    conversion: number | null;
    profit: number | null;
    first_offer: number | null;
    final_offer: number | null;
    profit_basis: string | null;
    package_weight_kg: number | null;
  };
  recipient: {
    name: string | null;
    phone: string | null;
    phone_secondary: string | null;
    address: string | null;
    district: string | null;
    thana: string | null;
    profile_id: number | null;
    billing_profile_id: number | null;
    delivery_instructions: string | null;
    is_prepaid: boolean;
  };
  charges: {
    cod: number;
    delivery: number;
    print: number;
    packing: number;
    discount: number;
    deduct_from_margin: {
      charges: boolean;
      cod: boolean;
      delivery: boolean;
      print: boolean;
      packing: boolean;
    };
  };
  totals: {
    item_count: number;
    amount: number;
    currency: StaffOrderCurrency | null;
  };
  courier: Record<string, unknown>;
  pickup: Record<string, unknown>;
  payout: Record<string, unknown>;
  parcel: Record<string, unknown>;
  return_info: Record<string, unknown>;
  links: {
    invoices: Array<{ id: number }>;
    shipments: Array<{ id: number }>;
  };
}

export interface StaffShopOrderDetailItem {
  id: number;
  order_id: number;
  name: string;
  image_url: string | null;
  quantity: number;
  created_at: string;
  updated_at: string;
  product: {
    id: number;
    sku: string | null;
    brand: string | null;
    barcode: string | null;
    weight_gm: number | null;
    package_weight_gm: number | null;
    minimum_order_quantity: number;
  };
  pricing: {
    cost: StaffOrderMoney;
    list: StaffOrderMoney;
    sell: StaffOrderMoney;
    minimum_sell: StaffOrderMoney;
  };
  negotiation: {
    status: string | null;
    customer_decision: string | null;
    staff_offer: StaffOrderOffer | null;
    customer_offer: StaffOrderOffer | null;
    final_offer: StaffOrderOffer | null;
    weight_kg: number | null;
    confirmed_quantity: number | null;
  };
  fulfillment: {
    ordered: number;
    delivered: number;
    returned: number;
    procurement_pulled: boolean;
  };
  stock: {
    global_stock_id: number;
    global_stock_allocation_id: number | null;
    shipment_item_id: number | null;
    shipment_id: number | null;
  } | null;
}

export interface StaffShopOrderDetailResponse {
  order: StaffShopOrderDetailOrder;
  items: StaffShopOrderDetailItem[];
}
