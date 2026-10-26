# Legacy imperative migrations (archived)

These 1,389 SQL files were replayed on production before the **2026-10** declarative baseline squash.

- **Not applied** on fresh `supabase db reset` — only [`../00000000000000_baseline.sql`](../00000000000000_baseline.sql) runs locally.
- Kept in git for archaeology and blame. Do not delete.
- Rollback reference: git tag `pre-baseline-squash`.
