# [Feature Name] — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/<domain>/`  

---

## 1. Component Hierarchy

```text
web/src/modules/<domain>/
├── pages/
│   ├── FeatureListPage.vue           # Main table view with toolbar
│   └── FeatureDetailPage.vue         # Entity details & timeline
├── components/
│   ├── FeatureActionDialog.vue       # Create/Edit modal dialog
│   └── FeatureStatusChip.vue         # Status visual indicator
├── services/
│   ├── featureRepository.ts          # Supabase RPC invocation layer
│   └── featureQueryKeys.ts           # TanStack query key factory
└── stores/
    └── useFeatureStore.ts            # Ephemeral UI selection & filter state
```

---

## 2. Vue Query Keys & Mutation Flow

```typescript
export const featureKeys = {
  all: ['feature_entities'] as const,
  lists: () => [...featureKeys.all, 'list'] as const,
  list: (params: Record<string, unknown>) => [...featureKeys.lists(), params] as const,
  details: () => [...featureKeys.all, 'detail'] as const,
  detail: (id: string) => [...featureKeys.details(), id] as const,
};
```

---

## 3. Implementation Steps & Checklist

- [ ] 1. Define schema & RPCs in `supabase/schemas/<domain>/`.
- [ ] 2. Create mock stubs in `stubs.ts` and test UI with mock data.
- [ ] 3. Implement Vue Query hooks in `services/`.
- [ ] 4. Build Quasar UI following `.agents/rules/table_list_design_system.md`.
- [ ] 5. Run typecheck & lint validations.
