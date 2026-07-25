# TanStack Query Guide

This guide explains how to build a new page or feature using TanStack Query for server state management in this project. It adheres to the conventions defined in [`STATE_MANAGEMENT.md`](STATE_MANAGEMENT.md).

## Core Principles

1. **TanStack Query owns server state:** Data fetched from the backend, loading states, error states, and cache lifecycle.
2. **Pinia owns client state:** UI state, auth, local filters, wizard flows, and form state.
3. **Do not duplicate state:** Never store data fetched by TanStack Query into a Pinia store.
4. **Repository pattern:** All API/Supabase calls must be made through a repository class, not directly in the composables.

---

## Step-by-Step Implementation

### 1. Define Query Keys

Query keys should be centralized in a key factory for the module. This ensures consistency and prevents cache collisions.

**File:** `src/modules/[module]/shared/queryKeys/[module]QueryKeys.ts`

```typescript
export const myModuleQueryKeys = {
  // Simple list or entity
  categories: (tenantId: number) => ['myModule', 'categories', { tenantId }] as const,
  
  // Detail query with ID
  detail: (id: string) => ['myModule', 'detail', { id }] as const,
  
  // Paginated/filtered list
  list: (params: object) => ['myModule', 'list', params] as const,
};
```

**Rules:**
- Always include `tenantId` (or `tenantSlug`) for tenant-scoped data.
- Use an object for parameters `{ tenantId, status, page }` to ensure stable ordering.

### 2. Create Query Composables (Read)

Wrap `useQuery` in a dedicated composable file. This abstracts the data fetching logic away from the Vue component.

**File:** `src/modules/[module]/composables/useMyEntityQuery.ts`

```typescript
import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { myModuleQueryKeys } from '../shared/queryKeys/myModuleQueryKeys';
import { myEntityRepository } from '../repositories/myEntityRepository';

export interface MyEntityQueryParams {
  tenantId: number;
  page?: number;
  search?: string;
}

export function useMyEntityListQuery(params: Ref<MyEntityQueryParams>) {
  return useQuery({
    // Make queryKey reactive based on params
    queryKey: computed(() => myModuleQueryKeys.list(params.value)),
    queryFn: () => myEntityRepository.fetchList(params.value),
    // Define stale time based on data volatility (e.g., 2 mins)
    staleTime: 2 * 60 * 1000,
    // Keep previous data when paginating to avoid UI flickering
    placeholderData: keepPreviousData,
    // Only run the query if required params are present
    enabled: computed(() => !!params.value.tenantId),
  });
}
```

### 3. Create Mutation Composables (Write/Update/Delete)

Group related mutations in a separate composable file. Use the `queryClient` to invalidate relevant queries on success.

**File:** `src/modules/[module]/composables/useMyEntityMutations.ts`

```typescript
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { myEntityRepository } from '../repositories/myEntityRepository';
import type { CreateMyEntityInput } from '../types';

export function useCreateMyEntityMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateMyEntityInput) => myEntityRepository.create(input),
    onSuccess: () => {
      // Invalidate the list query to trigger a refetch
      queryClient.invalidateQueries({ queryKey: ['myModule', 'list'] });
    },
  });
}
```

### 4. Consume in Vue Components

Use the composables directly in your `.vue` pages or components. **Do not use `onMounted` to trigger fetching.** TanStack Query handles the lifecycle automatically based on the component mounting and dependency changes.

**File:** `src/modules/[module]/pages/MyEntityPage.vue`

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { useMyEntityListQuery } from '../composables/useMyEntityQuery';
import { useCreateMyEntityMutation } from '../composables/useMyEntityMutations';

// 1. Define reactive parameters (often linked to Pinia or local refs)
const queryParams = ref({
  tenantId: 123, // usually fetched from auth store
  page: 1,
  search: ''
});

// 2. Consume the query
const { 
  data: entities, 
  isLoading, 
  isError, 
  error 
} = useMyEntityListQuery(queryParams);

// 3. Consume the mutation
const { 
  mutate: createEntity, 
  isPending: isCreating 
} = useCreateMyEntityMutation();

const handleCreate = () => {
  createEntity({ name: 'New Item' }, {
    onSuccess: () => {
      // Show success notification here if needed
      console.log('Created successfully!');
    }
  });
};
</script>

<template>
  <q-page class="q-pa-md">
    <!-- Loading State -->
    <div v-if="isLoading">Loading items...</div>
    
    <!-- Error State -->
    <div v-else-if="isError">Error: {{ error?.message }}</div>
    
    <!-- Data State -->
    <div v-else>
      <ul>
        <li v-for="item in entities" :key="item.id">{{ item.name }}</li>
      </ul>
      
      <q-btn 
        label="Add Item" 
        color="primary" 
        :loading="isCreating" 
        @click="handleCreate" 
      />
    </div>
  </q-page>
</template>
```

---

## Anti-Patterns to Avoid 🚫

- **Calling APIs directly in `.vue` files:** Always route through a Repository class, wrapped by a Query Composable.
- **Using `onMounted` for queries:** Let TanStack Query's `enabled` property and reactive keys manage fetching.
- **Storing query results in Pinia:** If you need the data, call the `useQuery` composable again in the other component. TanStack Query will return the cached data instantly.
- **Using non-reactive params for queries:** If your query depends on `params`, pass them as a `Ref` or `ComputedRef` and use `computed(() => keys(params.value))` for the `queryKey`. Otherwise, the query won't update when params change.
