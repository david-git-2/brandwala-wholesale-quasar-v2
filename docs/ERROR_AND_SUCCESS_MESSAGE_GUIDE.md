---
name: ERROR_AND_SUCCESS_MESSAGE_GUIDE
description: AI Instructions for refactoring a module's success and error message handling.
---

# AI INSTRUCTION: Message Refactoring Guide

**Context for the AI:** The user has provided you with a specific module directory (e.g., `web/src/modules/access_control`) and this document. Your objective is to refactor all API calls, queries, and mutations within that module to adhere to the project's strict error and success messaging standards. 

Read these instructions carefully and execute them step-by-step. Do not ask for permission to proceed unless you encounter an ambiguous edge case.

## Core Rules to Enforce
1. **Mutations (`useMutation`)**: Must trigger a frontend-driven success toast on success, and a parsed error toast on failure.
2. **Queries (`useQuery`)**: Must NEVER trigger a success toast. They should only handle errors (either inline or via toast).
3. **No Raw Errors**: Users must never see raw PostgreSQL errors (e.g., `relation does not exist`, `duplicate key value`).

---

## EXECUTION STEPS (Perform these sequentially)

### Step 1: Scan the Target Module
Use your `grep_search` or directory listing tools to scan all `.vue` and `.ts` files inside the provided target module directory. Look specifically for:
- `@tanstack/vue-query` usage (`useMutation`, `useQuery`).
- Supabase client calls.
- Usage of `showSuccessNotification` or `showErrorNotification`.

### Step 2: Import the Central Error Parser
Ensure that any file you modify imports the `parseSupabaseError` utility.
- Import path: `import { parseSupabaseError } from 'src/utils/appFeedback'` (Adjust relative path if necessary, or use alias if configured).
- Also ensure `showSuccessNotification` and `showErrorNotification` are imported from `src/utils/appFeedback` where needed.

### Step 3: Refactor Mutations (`useMutation`)
For every mutation found in the module, modify its `onSuccess` and `onError` callbacks:

**If it lacks a success message:** Add one.
```typescript
onSuccess: () => {
  showSuccessNotification('Successfully saved changes.'); // Use context-appropriate text
  // ... existing invalidation logic
}
```

**Refactor error handling:** Wrap the error payload in `parseSupabaseError` before passing it to the notification.
```typescript
// BEFORE:
onError: (error: any) => {
  showErrorNotification(error.message || 'Failed to save');
}

// AFTER:
onError: (error: any) => {
  showErrorNotification(parseSupabaseError(error, 'Failed to save changes.'));
}
```

### Step 4: Refactor Queries (`useQuery`)
For every data-fetching query found in the module:
1. Scan the `onSuccess` or `onSettled` hooks. 
2. If you find `showSuccessNotification` (e.g., "Data loaded successfully"), **DELETE IT**. We do not show toasts for successful page loads or data fetches.
3. If there is an `onError` hook showing a toast, ensure it uses `parseSupabaseError(error, 'Failed to load data.')`.

### Step 5: Verify and Finalize
1. Ensure all modified files have correct imports and no syntax errors.
2. Provide a summary of the files you changed and what modifications were made.
3. *If you notice any backend RPCs (Postgres functions) that enforce business logic but return technical errors, note them in your response so the user can address them in a future migration using `RAISE EXCEPTION`.*
