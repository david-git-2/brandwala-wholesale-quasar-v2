# Customer Module Blueprint & Architecture Plan

## Executive Summary
This document establishes the architectural blueprint, entity relationships, directory layout, route definitions, and migration path for the dedicated **`customer`** module.

Currently:
- **`Customer Group`** logic lives in `shop_order` and `tenant`.
- **`Billing Profile`** logic lives in `sales_invoice`.
- Both domains are intertwined via `CustomerBillingHubPage.vue`, creating unnecessary coupling where `shop_order`, `sales_invoice`, and `wallet` pull cross-domain dependencies.

The **`customer`** module consolidates all customer counterparty definitions, access control tiers, billing profiles, recipient delivery profiles, and wallet ledger connections into a single clean domain.

---

## 1. Domain Entities & Responsibilities

```
+-----------------------------------------------------------------------------------+
|                                 CUSTOMER DOMAIN                                   |
|                                                                                   |
|  +------------------------+      1:1 / 1:N      +-------------------------------+ |
|  |     Customer Group     | <-----------------> |        Billing Profile        | |
|  | (Tier, Access, Pricing)|                     | (Identity, Terms, AR Account) | |
|  +------------------------+                     +-------------------------------+ |
|              ^                                                  |                 |
|              | 1:N                                              | 1:1             |
|              v                                                  v                 |
|  +------------------------+                     +-------------------------------+ |
|  |    Customer Member     |                     |        Universal Wallet       | |
|  |  (Storefront Auth User)|                     |    (Ledger, Balance, Payout)  | |
|  +------------------------+                     +-------------------------------+ |
|                                                                 |                 |
|                                                                 v                 |
|                                                 +-------------------------------+ |
|                                                 |       Recipient Profile       | |
|                                                 |   (Drop-Ship Delivery Targets)| |
|                                                 +-------------------------------+ |
+-----------------------------------------------------------------------------------+
```

### Entity Matrix

| Entity | Primary Purpose | Table | Consumed By |
|---|---|---|---|
| **Customer Group** | Storefront access tiers, wholesale/retail pricing rules, bulk discount percentages. | `customer_groups` | `shop_order`, `customer` |
| **Billing Profile** | Financial identity for B2B buyers, distributors, resellers, and credit accounts. | `billing_profiles` | `sales_invoice`, `wallet`, `customer` |
| **Customer Member** | Authenticated user credentials linked to a customer group for storefront login. | `customer_group_members` | `shop_order` (Storefront Auth), `customer` |
| **Recipient Profile** | Saved delivery endpoints (recipient name, phone, district, thana, full address). | `recipient_profiles` | `sales_invoice` (Retail/Dropship), `shop_order` |

---

## 2. Directory Structure (`web/src/modules/customer`)

```
web/src/modules/customer/
├── components/
│   ├── CustomerGroupFormDialog.vue        # Create/edit customer group modal
│   ├── BillingProfileFormDialog.vue      # Create/edit billing profile modal
│   ├── BillingProfileDetailsDrawer.vue   # Real-time ledger & balance drawer
│   ├── RecipientProfileFormDialog.vue    # Create/edit recipient address modal
│   └── CustomerGroupMembersTable.vue     # Storefront members attached to a group
├── composables/
│   ├── useCustomerGroupsQuery.ts         # TanStack Query for groups
│   ├── useCustomerGroupMutations.ts      # TanStack Mutations for groups
│   ├── useBillingProfilesQuery.ts        # TanStack Query for billing profiles
│   ├── useBillingProfileMutations.ts     # TanStack Mutations for billing profiles
│   ├── useRecipientProfilesQuery.ts      # TanStack Query for delivery endpoints
│   └── useRecipientProfileMutations.ts   # TanStack Mutations for delivery endpoints
├── pages/
│   ├── CustomerHubPage.vue               # Canonical Unified Hub (Tabs: Groups, Profiles, Recipients)
│   ├── CustomerGroupsListPage.vue        # Dedicated Customer Groups list page
│   ├── BillingProfilesListPage.vue       # Dedicated Billing Profiles list page
│   └── RecipientProfilesListPage.vue     # Dedicated Recipient Profiles list page
├── repositories/
│   ├── customerGroupRepository.ts        # Supabase API for customer groups & members
│   ├── billingProfileRepository.ts       # Supabase API for billing profiles
│   └── recipientProfileRepository.ts     # Supabase API for recipient profiles
├── routes/
│   └── index.ts                          # Customer module route definitions
├── services/
│   └── customerQueryKeys.ts              # Canonical TanStack Query Key Factory
└── types/
    ├── customerGroup.ts                  # Customer group, member & access types
    ├── billingProfile.ts                 # Billing profile & terms types
    └── recipientProfile.ts               # Recipient delivery address types
```

---

## 3. Query Key Architecture (`customerQueryKeys.ts`)

```typescript
export const customerQueryKeys = {
  root: ['customer'] as const,
  groups: (tenantId: number | null) =>
    [...customerQueryKeys.root, 'groups', tenantId ?? 0] as const,
  groupDetail: (tenantId: number | null, groupId: number) =>
    [...customerQueryKeys.root, 'group', tenantId ?? 0, groupId] as const,
  billingProfiles: (tenantId: number | null, params?: Record<string, any>) =>
    [...customerQueryKeys.root, 'billing_profiles', tenantId ?? 0, params ?? {}] as const,
  billingProfileDetail: (tenantId: number | null, profileId: number) =>
    [...customerQueryKeys.root, 'billing_profile', tenantId ?? 0, profileId] as const,
  recipients: (tenantId: number | null, params?: Record<string, any>) =>
    [...customerQueryKeys.root, 'recipients', tenantId ?? 0, params ?? {}] as const,
};
```

---

## 4. UI & Layout Design Guidelines

Following `.agents/rules/table_list_design_system.md`:
1. **Zero In-Page Headers**:
   - `CustomerHubPage.vue` eliminates header banners. Page hierarchy and titles are supplied via top breadcrumbs (`usePageBreadcrumbs`).
2. **Compact Navigation Toolbar**:
   - Outlined rounded search input (`q-input outlined rounded dense placeholder="Search customers, profiles..."`).
   - Action buttons use **square styling** (`border-radius: 8px`), e.g., "Add Customer Group", "Create Billing Profile".
3. **Fixed Outer Layout & Internal Scroll**:
   - Page container locked to `calc(100vh - 55px)` with `overflow: hidden`.
   - Internal table scrolling (`.q-table__middle { overflow-y: auto }`) with sticky table headers.
4. **State High-Visibility**:
   - Soft accent left borders on rows (`boxShadow: inset 3px 0 0 <color>`).
   - Avatars use neutral grey tones (`q-avatar color="grey-3" text-color="grey-9"`).

---

## 5. Navigation & Module Registry Integration

Update `web/src/modules/navigation/moduleRegistry.ts`:

```typescript
// Top-level customer module definition
{
  key: 'customer',
  name: 'Customers',
  description: 'Manage customer groups, billing profiles, and delivery recipients.',
  navIcon: 'ph ph-users',
  routes: [
    {
      scope: 'app',
      title: 'Customer Hub',
      caption: 'Groups, Billing & Delivery Profiles',
      icon: 'ph ph-users-three',
      routeSegment: 'customers',
    },
    {
      scope: 'app',
      title: 'Customer Groups',
      caption: 'Access tiers & pricing discounts',
      icon: 'ph ph-user-list',
      routeSegment: 'customers/groups',
    },
    {
      scope: 'app',
      title: 'Billing Profiles',
      caption: 'B2B & wholesale invoicing accounts',
      icon: 'ph ph-address-book',
      routeSegment: 'customers/billing-profiles',
    },
    {
      scope: 'app',
      title: 'Recipient Profiles',
      caption: 'Drop-ship delivery addresses',
      icon: 'ph ph-identification-badge',
      routeSegment: 'customers/recipient-profiles',
    },
  ],
}
```

---

## 6. Phased Implementation Plan

### Phase 1: Create Core Types, Repositories & TanStack Queries
- [ ] Create `web/src/modules/customer/types/`.
- [ ] Implement `customerGroupRepository.ts`, `billingProfileRepository.ts`, and `recipientProfileRepository.ts`.
- [ ] Set up `customerQueryKeys.ts` and composables (`useCustomerGroupsQuery`, `useBillingProfilesQuery`, `useRecipientProfilesQuery`).

### Phase 2: Create UI Components & Modals
- [ ] Migrate and refactor `CustomerGroupFormDialog.vue` and `BillingProfileFormDialog.vue` to use TanStack mutations with cache-first optimistic updates.
- [ ] Port `BillingProfileDetailsDrawer.vue` to view universal wallet ledgers.
- [ ] Implement `RecipientProfileFormDialog.vue`.

### Phase 3: Build Canonical Pages & Route Assembly
- [ ] Build `CustomerHubPage.vue` featuring compact tab navigation (*Customer Groups*, *Billing Profiles*, *Recipient Profiles*).
- [ ] Implement `CustomerGroupsListPage.vue`, `BillingProfilesListPage.vue`, and `RecipientProfilesListPage.vue`.
- [ ] Register routes in `web/src/modules/customer/routes/index.ts` and mount in the main router.

### Phase 4: Refactor Consumer Modules & Cleanup
- [ ] Update `sales_invoice` (`InvoiceOverviewPage.vue`, `InvoicesListPage.vue`, dialogs) to import from `@modules/customer`.
- [ ] Update `shop_order` (Storefront checkout, access control) to import from `@modules/customer`.
- [ ] Update `wallet` to reference customer entities.
- [ ] Deprecate legacy mixed files and verify full TypeScript compilation (`vue-tsc --noEmit`).

---

## 7. Definition of Done
- [ ] All customer party entities (`customer_groups`, `billing_profiles`, `recipient_profiles`) operate under `web/src/modules/customer`.
- [ ] Full TanStack Query / Mutation integration with zero Pinia store baggage.
- [ ] All table and list views adhere strictly to the headerless fixed-height design system rule (`.agents/rules/table_list_design_system.md`).
- [ ] `vue-tsc` type checks pass cleanly across all modules without any circular dependency errors.
