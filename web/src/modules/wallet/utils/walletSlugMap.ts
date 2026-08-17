import type { UniversalWalletEntityType } from '../types';

export type WalletSlug =
  | 'company'
  | 'customers'
  | 'suppliers'
  | 'cargo'
  | 'couriers'
  | 'investors';

export const SLUG_TO_ENTITY_TYPE: Record<WalletSlug, UniversalWalletEntityType> = {
  company: 'tenant',
  customers: 'customer',
  suppliers: 'vendor',
  cargo: 'cargo_company',
  couriers: 'courier',
  investors: 'investor',
};

export const ENTITY_TYPE_TO_SLUG: Partial<Record<UniversalWalletEntityType, WalletSlug>> = {
  tenant: 'company',
  customer: 'customers',
  vendor: 'suppliers',
  cargo_company: 'cargo',
  courier: 'couriers',
  investor: 'investors',
};

export const SLUG_TO_LABEL: Record<WalletSlug, string> = {
  company: 'Our company',
  customers: 'Customers',
  suppliers: 'Suppliers',
  cargo: 'Cargo',
  couriers: 'Couriers',
  investors: 'Investors',
};

export function getEntityTypeFromSlug(slug: string): UniversalWalletEntityType | null {
  return SLUG_TO_ENTITY_TYPE[slug as WalletSlug] || null;
}

export function getSlugFromEntityType(entityType: UniversalWalletEntityType): WalletSlug | null {
  return ENTITY_TYPE_TO_SLUG[entityType] || null;
}
