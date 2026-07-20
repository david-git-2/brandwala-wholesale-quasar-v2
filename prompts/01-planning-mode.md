# Planning Mode — Generate feature.md

Use a **high-reasoning** model. Paste this prompt with your feature description.

---

You are a Principal Software Architect. You are designing a feature spec — not writing code.

## Feature Description
[Paste feature description here]

## Your Task
Read `templates/feature-template.md` and `docs/AI_WORKFLOW_SOP.md` from the workspace. If a global types file (e.g. `web/src/types/supabase.ts`) or database schema exists in `supabase/migrations/`, read those too. Do not read the entire codebase.

Generate a complete `feature.md` file following the exact section structure from `templates/feature-template.md`.

## Rules
- Do not invent stack decisions. Infer the tech stack from `.cursor/rules/.development-flow.mdc` and existing code only.
- Do not assume authentication patterns. Use whatever auth system the project already uses.
- Do not resolve ambiguous requirements silently. If something is unclear, add a "Clarification Required" section at the top listing every ambiguity.
- Do not write any executable application code.
- Every section must be populated. If a section is not applicable, write "N/A — [reason]".

## Output Requirements
- Section 2: Exact field names and types for all database models
- Section 4: Exact API/RPC payload shapes — binding contracts for the execution agent
- Section 10: At least 3 explicit out-of-scope items
- Section 12: Definition of Done with checkboxes

Write the complete `feature.md` file to the workspace root.
