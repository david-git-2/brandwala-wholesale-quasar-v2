# Vue-TSC & ESLint Zero-Drift Error Resolution Protocol

> **Skill Quick Command**: You can trigger automated typecheck and lint auto-fixes anytime by typing `/fix-ui-errors` or asking to "fix UI errors".

## 1. Fast Diagnostic Commands
Execute strictly in `web/`:
```bash
# Vue-TSC check
npx vue-tsc --noEmit

# ESLint auto-fix
npx eslint . --ext .ts,.vue --fix
```

## 2. Common Patterns & Direct Fix Rules

### `vue-tsc` Errors
- **`Property 'X' does not exist on type '...'`**:
  - Add missing field to TS interface/type in `src/types/` or module-specific `types.ts`.
  - Check if ref is unwrapped properly (`myRef.value.X` vs `myRef.X`).
- **`Type 'null' is not assignable to type 'X'`**:
  - Add null check / optional chaining: `item?.X`.
  - Explicit typing for ref: `ref<Type | null>(null)`.
- **Template type errors (`vue-tsc`)**:
  - Ensure component props use proper Vue `PropType<T>` or generic `defineProps<{ item: T }>()`.
  - Cast standard Quasar event payloads if un-typed.

### `ESLint` Errors
- **`vue/multi-word-component-names`**:
  - Rename component or set multi-word name.
- **`@typescript-eslint/no-explicit-any`**:
  - Replace `any` with `unknown` or specific type.
- **Unused imports/variables (`@typescript-eslint/no-unused-vars`)**:
  - Remove unused import or prefix variable with `_`.
- **Formatting/Quote/Semi errors**:
  - Run `npx eslint . --ext .ts,.vue --fix` automatically.

## 3. Minimal-Token Resolution Strategy
1. Run `npx vue-tsc --noEmit` and `npx eslint . --ext .ts,.vue --fix` in `web/`.
2. Inspect exact line numbers from error output.
3. Edit only targeted lines using exact replacement tools (`replace_file_content`).
4. Re-run verification to confirm 0 errors.
