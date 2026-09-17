# Shop Order & Dropship — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/shop_order/`  
> **Repository Target**: `web/src/modules/shop_order/repositories/`  
> **Query Keys**: `web/src/modules/shop_order/config/`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/shop_order/
├── pages/
│   ├── ShopSetupHubPage.vue              # Admin hub: Shops, Categories, Customer Groups
│   ├── ShopsPage.vue                     # Storefront list with status chips
│   ├── ShopSettingsPage.vue              # Setup, Access & Listings tabs
│   ├── DropshipOrdersPage.vue            # Multi-stage fulfillment desk
│   ├── DropshipOrderDetailV2ProcessingPage.vue # Picking stock & charges desk
│   ├── DropshipOrderDetailV2ReadyForPickupPage.vue # Courier & B2B invoice preview
│   └── DropshipFinanceHubPage.vue        # Courier reconciliation & margin payouts
├── components/
│   ├── ShopFormDialog.vue                # Create/edit shop modal
│   ├── ShopOrdersTable.vue               # Ops data table with fulfillment chips
│   ├── CustomerGroupWalletDialog.vue     # Merchant statement dialog
│   └── DropshipCourierSelectDialog.vue   # Courier assignment popup
└── repositories/
    ├── shopOrderRepository.ts            # Supabase RPC & query client
    └── dropshipFulfillmentRepository.ts  # Fulfillment & settlement methods
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const shopOrderQueryKeys = {
  all: ['shopOrder'] as const,
  orders: (tenantId: string, params?: Record<string, unknown>) =>
    [...shopOrderQueryKeys.all, 'orders', { tenantId, ...params }] as const,
  orderDetail: (orderId: string) =>
    [...shopOrderQueryKeys.all, 'orderDetail', orderId] as const,
  shops: (tenantId: string) =>
    [...shopOrderQueryKeys.all, 'shops', tenantId] as const,
  merchantWallet: (tenantId: string) =>
    [...shopOrderQueryKeys.all, 'merchant_wallet', tenantId] as const,
  dropshipSettlements: (tenantId: string) =>
    [...shopOrderQueryKeys.all, 'dropship_settlements', tenantId] as const,
};
```

---

## 3. UI Implementation Patterns & Layout Compliance

1. **Multi-Stage Desk**: Use status tabs (`placed`, `processing`, `ready_for_pickup`, `in_transit`, `delivered`) rather than dropdown menus.
2. **Stock Picking Isolation**: Never link physical stock at order creation; bind stock exclusively inside `DropshipOrderDetailV2ProcessingPage.vue`.
3. **Dual Invoice Delivery**: Customer-facing packing slip is rendered without wholesale costs; B2B merchant invoice includes landed cost and margin breakdown.
