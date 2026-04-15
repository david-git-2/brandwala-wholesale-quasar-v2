export type OrderStatus =
  | 'customer_submit'
  | 'priced'
  | 'negotiate'
  | 'ordered'
  | 'placed'

export type Order = {
  id: number
  name: string
  customer_group_id: number
  can_see_price: boolean
  accent_color: string | null
  cargo_rate: number | null
  conversion_rate: number | null
  profit_rate: number | null
  negotiate: boolean
  status: OrderStatus
  store_id: number | null
  created_at: string
  updated_at: string
}

export type OrderItem = {
  id: number
  order_id: number
  name: string
  image_url: string | null
  price_gbp: number | null
  cost_gbp: number | null
  cost_bdt: number | null
  first_offer_bdt: number | null
  customer_offer_bdt: number | null
  final_offer_bdt: number | null
  product_weight: number | null
  package_weight: number | null
  minimum_quantity: number
  product_id: number | null
  ordered_quantity: number
  delivered_quantity: number
  returned_quantity: number
  created_at: string
  updated_at: string
}

export type OrderWithItems = Order & {
  order_items: OrderItem[]
}

export type OrderListInput = {
  fields?: string[]
  customer_group_id?: number | null
  store_id?: number | null
  status?: OrderStatus | null
  page?: number
  page_size?: number
  limit?: number
  offset?: number
}

export type OrderListPage = {
  data: Order[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

export type OrderGetByIdInput = {
  id: number
  order_fields?: string[]
  item_fields?: string[]
}

export type OrderUpdateInput = {
  id: number
  patch: Partial<Omit<Order, 'id' | 'created_at' | 'updated_at'>>
}

export type OrderCreateInput = Omit<Order, 'id' | 'created_at' | 'updated_at'>

export type OrderItemUpdateInput = {
  id: number
  patch: Partial<Omit<OrderItem, 'id' | 'order_id' | 'created_at' | 'updated_at'>>
}

export type OrderDeleteInput = {
  id: number
}

export type OrderItemDeleteInput = {
  id: number
}

export type OrderItemCreateInput = Omit<OrderItem, 'id' | 'created_at' | 'updated_at'>

export type OrderItemBulkUpdateInput = Array<
  {
    id: number
  } & Partial<Omit<OrderItem, 'id' | 'created_at' | 'updated_at'>>
>

export type OrderServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type OrderStoreState = {
  items: Order[]
  selected: OrderWithItems | null
  total: number
  page: number
  page_size: number
  total_pages: number
  loading: boolean
  saving: boolean
  error: string | null
}
