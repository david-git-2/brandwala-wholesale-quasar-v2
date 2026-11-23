import type { Database } from 'src/types/supabase';

export type ProductBasedCostingFile =
  Database['public']['Tables']['product_based_costing_files']['Row'] & {
    profile_id?: number | null;
    customer_group_id?: number | null;
    customer_group_name?: string | null;
    default_shipment_id?: number | null;
  };
export type ProductBasedCostingFileCreateInput =
  Database['public']['Tables']['product_based_costing_files']['Insert'] & {
    customer_group_id?: number | null;
    default_shipment_id?: number | null;
  };
export type ProductBasedCostingFileUpdateInput =
  Database['public']['Tables']['product_based_costing_files']['Update'] & {
    id: number;
    customer_group_id?: number | null;
    default_shipment_id?: number | null;
  };
export type ProductBasedCostingFileDeleteInput = {
  id: number;
};

export type ProductBasedCostingServiceResult<T> = {
  success: boolean;
  data?: T;
  error?: string;
};

export type ProductBasedCostingFilesListCursor = {
  created_at: string;
  id: number;
} | null;

export type ProductBasedCostingFileListInput = {
  limit?: number;
  search?: string;
  status?: string | null;
  cursor?: ProductBasedCostingFilesListCursor;
};

/** Slim rows from `list_product_based_costing_files` (list + edit dialog). */
export type ProductBasedCostingFileListRow = Pick<
  ProductBasedCostingFile,
  | 'id'
  | 'name'
  | 'order_for'
  | 'status'
  | 'created_at'
  | 'customer_group_id'
  | 'note'
  | 'vendor_code'
  | 'market_code'
  | 'buy_currency_id'
  | 'sell_currency_id'
>;

export type ProductBasedCostingFileListPage = {
  data: ProductBasedCostingFileListRow[];
  meta: {
    has_more: boolean;
    next_cursor: ProductBasedCostingFilesListCursor;
    limit: number;
  };
};

export type ProductBasedCostingItemsListCursor = {
  sort_order: number;
  id: number;
} | null;

export type ProductBasedCostingItemListInput = {
  limit?: number;
  cursor?: ProductBasedCostingItemsListCursor;
};

export type ProductBasedCostingItemListPage = {
  data: ProductBasedCostingItem[];
  meta: {
    has_more: boolean;
    next_cursor: ProductBasedCostingItemsListCursor;
    limit: number;
  };
};

export interface ProductBasedCostingItem {
  id: number;
  product_based_costing_file_id: number | null;
  product_id?: number | null;
  name: string | null;
  image_url: string | null;
  note: string | null;
  quantity: number | null;
  confirmed_quantity?: number | null;
  barcode: string | null;
  product_code: string | null;
  brand?: string | null;
  vendor_code?: string | null;
  market_code?: string | null;
  web_link: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  offer_price: number | null;
  profit_rate?: number | null;
  website?: string | null;
  /** Alias used in shared preview UI. */
  confirmed_qty?: number | null;
  is_offer_price_manual?: boolean | null;
  status: string | null;
  input_type?: 'manual' | 'product_list' | null;
  assigned_shipment_id?: number | null;
  sort_order?: number;
  created_at: string;
  updated_at: string;
}

export interface ProductBasedCostingItemCreateInput {
  product_based_costing_file_id?: number | null;
  name?: string | null;
  image_url?: string | null;
  note?: string | null;
  quantity?: number | null;
  confirmed_quantity?: number | null;
  barcode?: string | null;
  product_code?: string | null;
  brand?: string | null;
  vendor_code?: string | null;
  market_code?: string | null;
  web_link?: string | null;
  price_gbp?: number | null;
  product_weight?: number | null;
  package_weight?: number | null;
  offer_price?: number | null;
  is_offer_price_manual?: boolean | null;
  product_id?: number | null;
  input_type?: 'manual' | 'product_list' | null;
  assigned_shipment_id?: number | null;
}

export interface ProductBasedCostingItemUpdateInput extends ProductBasedCostingItemCreateInput {
  id: number;
}

/** Live catalog fields for PBC line cards (from `products`). */
export type PbcItemProductCatalog = {
  languages: string | null;
  country_of_origin: string | null;
  available_units: number | null;
  batch_code_manufacture_date: string | null;
  expire_date: string | null;
};

export type PbcFileDetailsBundleCustomer = {
  customer_group_id: number;
  group_name: string;
};

export type PbcFileDetailsBundleProductCatalogRow = PbcItemProductCatalog & {
  product_id: number;
};

export type PbcFileDetailsBundlePage = {
  file: ProductBasedCostingFile | null;
  summary: Record<string, unknown> | null;
  items: ProductBasedCostingItemListPage;
  product_catalog: PbcFileDetailsBundleProductCatalogRow[];
};

export interface ProductBasedCostingStoreState {
  items: ProductBasedCostingFile[];
  item: ProductBasedCostingFile | null;
  costingItems: ProductBasedCostingItem[];
  costingItem: ProductBasedCostingItem | null;
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
  loading: boolean;
  saving: boolean;
  error: string | null;
}
