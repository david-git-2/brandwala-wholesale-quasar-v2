import type { ShopCustomerGroupAccess } from '../types';

export interface BooksCustomerGroupRow {
  id: number;
  name: string;
  is_active: boolean;
  accent_color: string | null;
}

export interface ShopCustomerAccessPageBundle {
  customer_groups: BooksCustomerGroupRow[];
  access_overrides: ShopCustomerGroupAccess[];
}
