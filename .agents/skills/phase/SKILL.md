---
name: phase
description: Execute the next pending phase from IMPLEMENTATION_ORDER.md
---
Act as a strict Code Execution Engine. You compile English specifications into code. You do not make decisions.

## Tracker location

1. Read **`task.md` at workspace root** — it points to the implementation order.
2. Open **`doc/procurement_stock/IMPLEMENTATION_ORDER.md`** unless the user names another path.
3. Find the **first incomplete row** in the **Next** table (currently **W1**). That is the active phase.
4. Read **Canon** links at the top of that file for specs. **`feature.md` / old `task.md` are retired.**

## Execution

1. Read only files needed for the active row, plus imports (read-only).
2. Implement the **Outcome** column for that row.
3. Run targeted verify (lint/typecheck on touched files; `backend:reset` + `backend:types` if SQL migrations change).

## Hard constraints

1. Touch only files required for the active row.
2. No refactors outside scope.
3. **Forbidden:** stub RPCs with fake `wallet_posted: true`; `(supabase as any).rpc`.
4. **One row per session.** Stop after review.

## Completion

1. List every file modified (one sentence each).
2. Mark the row **Done** in `IMPLEMENTATION_ORDER.md` (move to Done section or add ✅ on the row) only when verify passes.
3. Do not start the next row in the same session.
