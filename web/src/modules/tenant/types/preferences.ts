export interface ThriftTenantPreference {
  default_purchase_currency?: number;
  default_cost_currency?: number;
}

export interface TenantPreferenceSchema {
  thrift?: ThriftTenantPreference;
}

export type TenantPreference = TenantPreferenceSchema;
