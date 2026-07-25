---
name: fix-ui-errors
description: Automatically detect, analyze, and fix vue-tsc type errors and ESLint linting errors in the web app. Trigger when user asks to fix UI errors, run typecheck, clean lint errors, or type /fix-ui-errors.
---

# Fix UI Errors (Vue-TSC & ESLint)

This skill guides the automated detection and resolution of TypeScript (`vue-tsc`) and ESLint errors in `web/`.

## Reference Protocol
Refer to [OPTIMIZE_ERRORS.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/docs/OPTIMIZE_ERRORS.md) for full error resolution strategies and common patterns.

## Execution Workflow

1. **Run Diagnostics**:
   Run the following commands inside `web/`:
   ```bash
   npx vue-tsc --noEmit
   npx eslint . --ext .ts,.vue --fix
   ```

2. **Analyze Output**:
   - Filter auto-fixable ESLint errors (already resolved by `--fix`).
   - Group remaining `vue-tsc` or complex ESLint errors by file and line number.

3. **Apply Targeted Fixes**:
   - Inspect target file sections around error lines.
   - Use non-destructive, precise edits (`replace_file_content`).
   - Common fixes:
     - Missing interface/type properties -> Update `types/` or component interface.
     - Ref unwrapping -> Add `.value` where required.
     - Nullability -> Add optional chaining `?.` or explicit union types (`Type | null`).
     - Prop types -> Define explicit generic `defineProps<{ ... }>()`.
     - Explicit `any` -> Replace with strict types or `unknown`.

4. **Verify**:
   Re-run `npx vue-tsc --noEmit` to confirm 0 remaining errors.
