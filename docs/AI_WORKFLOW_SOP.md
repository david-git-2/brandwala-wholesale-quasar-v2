# Deterministic AI-Assisted Development Protocol (SOP)

## Core Axioms
1. **Execution Engines Do Not Think:** Code generation is a compilation step. If the agent drifts, abort and restart with tighter context.
2. **Strict Context Isolation:** Expose only the files listed in the active phase. Never give the execution agent the full codebase.
3. **The Unbroken Data Contract:** Database schema → UI data shapes → API contracts. The backend fulfills the UI; it never drives it.

## Model Tier Routing
| Tier | Use For |
|------|---------|
| High-Reasoning | Generating feature.md, generating task.md, zero-shot architecture |
| Fast Generation | Executing a single phase from task.md |
| Isolated | Mock data, pure utilities, validation schemas (fresh session, no project context) |
| Ask / QA | Syntax questions, quick debugging, file reading |

## Lifecycle
- **Macro Phase (once per feature):** Define schemas, types, enums, auth contracts.
- **Micro Phase (per page/module):**
  - Step A: Build UI with static mock data. No API calls.
  - Step B: Build API to fulfill the UI's exact data contract.
  - Step C: Wire live calls. Delete mock data.

## Review Gates
Review and confirm after each phase before proceeding to the next.

## Abort Protocol
1. Stop the agent immediately.
2. Undo all changes from the current run (git checkout).
3. Open a new chat session.
4. Document what drifted in task.md.
5. Tighten the file list and re-run.
