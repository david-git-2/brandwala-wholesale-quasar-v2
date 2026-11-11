# Money spine v2

Canonical money kernel for TradeFlow.

| Meta | Value |
| :--- | :--- |
| **Stage** | Draft → Under Review (target contract) |
| **Audience** | Kernel implementers + feature RPC callers |
| **Out of folder** | Cutover adapters, dual-write, desk UI, ops audit SQL |

**Read in order:**

| # | File | Use |
| :---: | :--- | :--- |
| 0 | [00-overview.md](00-overview.md) | Problem, decisions, alternatives, NFRs/open questions, invariants |
| 1 | [01-schema.md](01-schema.md) | Tables + triggers (DDL) |
| 2 | [02-actions.md](02-actions.md) | Write + read RPCs + views |
| 3 | [03-tests.md](03-tests.md) | Test cases (Given / Action / Expect) |
| 4 | [04-module-rpcs.md](04-module-rpcs.md) | RPCs other modules must call |
| 5 | [05-security.md](05-security.md) | Privileges, assert, RLS, DEFINER rules |

`[ASSUMPTION]` Live SQL may lag this contract (`supabase/schemas/bills_pays/`). `[TODO-ARCH: publish live-vs-v2 gap list — owner, date]`. Cutover adapters remain **out** of this folder.
