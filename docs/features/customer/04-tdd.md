# Customer Hub — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/customer/`  
> **Repository Target**: `web/src/modules/customer/repositories/customerRepository.ts`  
> **Query Keys**: `web/src/modules/customer/services/customerQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/customer/
├── pages/
│   ├── CustomerHubPage.vue               # Searchable directory with create modal
│   └── RecipientProfilesPage.vue         # Recipient address book manager
├── components/
│   ├── CustomerCreateDialog.vue          # Atomic 2-field create popup (name + phone)
│   ├── CustomerDetailDrawer.vue          # 4-tab right inspection & edit drawer
│   ├── CustomerGeneralTab.vue            # Group info & billing profile contact details
│   ├── CustomerMembersTab.vue            # Storefront login users table & invitation modal
│   ├── CustomerAccountTab.vue            # Dual pot comparison (Invoice Due vs Store Credit)
│   └── CustomerWalletTab.vue             # Universal wallet transaction history
└── services/
    ├── customerRepository.ts             # Supabase RPC invocation layer
    └── customerQueryKeys.ts              # TanStack query keys
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const customerQueryKeys = {
  all: ['customers'] as const,
  lists: () => [...customerQueryKeys.all, 'list'] as const,
  list: (tenantId: string, search?: string) =>
    [...customerQueryKeys.lists(), { tenantId, search }] as const,
  detail: (groupId: string) =>
    [...customerQueryKeys.all, 'detail', groupId] as const,
  members: (groupId: string) =>
    [...customerQueryKeys.all, 'members', groupId] as const,
  account: (tenantId: string, groupId: string) =>
    [...customerQueryKeys.all, 'account', { tenantId, groupId }] as const,
};
```

---

## 3. UI Implementation Patterns & Layout Compliance

1. **Lightweight Create Dialog**: Customer creation requires only Name and Phone. Do not overload creation forms with email, addresses, or member fields.
2. **Right-Side Drawer Inspection**: Clicking any row opens `CustomerDetailDrawer.vue` directly without full-page navigation, preserving filter and scroll positions.
3. **Dual Pot Financial Transparency**: Always display Invoice AR Due and Customer Store Credit in distinct, clearly labeled cards to prevent operator confusion.
