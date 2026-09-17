# Global Reference, Koba Vertical & Central Trash — API Contract

## 1. Global Reference Remote Procedure Calls & Endpoints

### 1.1 `list_global_currencies`
Fetches all active global currencies with their latest exchange rates relative to BDT.

- **Type**: Database RPC / Read
- **Parameters**: None
- **Return Type**: `Array<GlobalCurrency>`
- **Response Shape**:
```json
[
  {
    "code": "GBP",
    "name": "British Pound",
    "symbol": "£",
    "exchange_rate_bdt": 162.50,
    "is_default": false,
    "is_active": true,
    "updated_at": "2026-09-17T12:00:00Z"
  },
  {
    "code": "BDT",
    "name": "Bangladeshi Taka",
    "symbol": "৳",
    "exchange_rate_bdt": 1.00,
    "is_default": true,
    "is_active": true,
    "updated_at": "2026-09-17T12:00:00Z"
  }
]
```

### 1.2 `upsert_global_currency`
Superadmin endpoint to create or update global currency details and exchange rates.

- **Type**: Database Mutation / RPC
- **Parameters**:
```typescript
interface UpsertGlobalCurrencyParams {
  p_code: string;
  p_name: string;
  p_symbol: string;
  p_exchange_rate_bdt: number;
  p_is_default?: boolean;
  p_is_active?: boolean;
}
```
- **Return Type**: `GlobalCurrency`

---

## 2. Koba Sourcing & Order Endpoints

### 2.1 `get_koba_customer_profile`
Queries repeat buyer purchase history, address records, and delivery success metrics based on phone number.

- **Type**: Database RPC
- **Parameters**:
```typescript
interface GetKobaCustomerProfileParams {
  p_phone: string;
  p_tenant_id: number;
}
```
- **Return Type**:
```typescript
interface KobaCustomerProfileResult {
  phone: string;
  customer_name: string;
  total_orders: number;
  completed_deliveries: number;
  returned_orders: number;
  total_spend_bdt: number;
  default_shipping_address: string;
  default_shipping_district: string;
  default_shipping_thana: string;
  delivery_success_rate_pct: number;
}
```

### 2.2 `create_koba_order`
Creates a confirmed order with full profit share and commission computations.

- **Type**: Database Mutation / RPC
- **Parameters**:
```typescript
interface CreateKobaOrderParams {
  p_tenant_id: number;
  p_customer_name: string;
  p_customer_phone: string;
  p_shipping_address: string;
  p_shipping_district: string;
  p_shipping_thana: string;
  p_items: Array<{
    product_id: number;
    title: string;
    quantity: number;
    base_price_bdt: number;
    sell_price_bdt: number;
  }>;
  p_delivery_fee_bdt: number;
  p_payment_method: string;
}
```
- **Return Type**:
```typescript
interface CreateKobaOrderResult {
  order_id: number;
  order_number: string;
  total_amount_bdt: number;
  total_commission_bdt: number;
  company_profit_bdt: number;
  agent_profit_bdt: number;
  status: string;
}
```

---

## 3. Central Trash & Recovery Endpoints

### 3.1 `list_trash_entries`
Lists all active soft-deleted entries for the authenticated tenant with filtering.

- **Type**: Database RPC / Query
- **Parameters**:
```typescript
interface ListTrashEntriesParams {
  p_tenant_id: number;
  p_entity_type?: string;
  p_search?: string;
  p_limit?: number;
  p_offset?: number;
}
```
- **Return Type**:
```typescript
interface TrashEntryListResponse {
  entries: Array<{
    id: string;
    entity_type: string;
    entity_id: string;
    label: string;
    module_key: string;
    deleted_at: string;
    deleted_by: string;
    payload: Record<string, unknown>;
  }>;
  total_count: number;
}
```

### 3.2 `restore_from_trash`
Restores a soft-deleted record back to its active domain table and deletes the trash index entry.

- **Type**: Database Mutation / RPC
- **Parameters**:
```typescript
interface RestoreFromTrashParams {
  p_trash_id: string;
  p_tenant_id: number;
}
```
- **Return Type**:
```typescript
interface RestoreFromTrashResult {
  success: boolean;
  restored_entity_type: string;
  restored_entity_id: string;
  message: string;
}
```

### 3.3 `purge_trash_entry`
Permanently hard-deletes a record from the database and removes its entry from `trash_entries`.

- **Type**: Database Mutation / RPC
- **Parameters**:
```typescript
interface PurgeTrashEntryParams {
  p_trash_id: string;
  p_tenant_id: number;
}
```
- **Return Type**:
```typescript
interface PurgeTrashEntryResult {
  success: boolean;
  purged_entity_type: string;
  purged_entity_id: string;
}
```

---

## 4. Row Level Security & Access Policies

```sql
-- Global References: Public read, Superadmin write
ALTER TABLE public.global_currencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read for active global currencies" 
  ON public.global_currencies FOR SELECT USING (true);
CREATE POLICY "Superadmin manage currencies" 
  ON public.global_currencies FOR ALL USING (
    EXISTS (SELECT 1 FROM public.tenant_users WHERE user_id = auth.uid() AND role = 'superadmin')
  );

-- Central Trash: Tenant isolation
ALTER TABLE public.trash_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tenant isolated trash directory" 
  ON public.trash_entries FOR ALL USING (
    tenant_id IN (SELECT tenant_id FROM public.tenant_users WHERE user_id = auth.uid())
  );
```
