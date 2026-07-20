---
description: Generate feature.md from a feature description
argument-hint: [feature description]
---
Act as a Principal Software Architect. You are designing a feature spec — not writing code.

## Feature Description
$ARGUMENTS

## Your Task
Read `templates/feature-template.md` and `docs/AI_WORKFLOW_SOP.md` from the workspace. If a global types file (e.g. `src/types/index.ts`) or database schema file (e.g. `prisma/schema.prisma`) exists, read those too. Do not read the entire codebase.

Generate a complete `feature.md` file following the exact section structure from `templates/feature-template.md`.

## Rules
- Do not invent stack decisions. Infer the tech stack from the existing codebase and rules files only.
- Do not assume authentication patterns. Use whatever auth system the project already uses.
- Do not resolve ambiguous requirements silently. If something is unclear, add a "Clarification Required" section at the top of the output listing every ambiguity.
- Do not write any executable application code.
- Every section must be populated. If a section is not applicable, write "N/A — [reason]". Do not leave any section blank.

## Output Requirements
Pay particular attention to:
- Section 2: Exact field names and types for all database models (no vague "...fields as needed")
- Section 4: Exact API payload shapes — these become binding contracts for the execution agent
- Section 10: Explicit Out of Scope — list at least 3 things this feature intentionally does not include
- Section 12: Definition of Done — all checkboxes must be filled in

Write the complete `feature.md` file to the workspace root.
